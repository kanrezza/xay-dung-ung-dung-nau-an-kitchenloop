import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/recipe_repository.dart';
import '../domain/text_normalizer.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';

/// Kết quả của việc thêm một thẻ.
enum TagAddResult { added, empty, duplicate, tooLong, tooMany }

/// Giữ bản nháp của một công thức đang được tạo hoặc sửa.
class RecipeEditorProvider extends ChangeNotifier {
  RecipeEditorProvider({
    required RecipeRepository repository,
    Recipe? existing,
    String Function()? idGenerator,
  })  : _repository = repository,
        _newId = idGenerator ?? (() => const Uuid().v4()),
        _isEditing = existing != null {
    _folderId = existing?.id.isNotEmpty == true ? existing!.id : _newId();
    _draft = existing ??
        Recipe(
          id: '',
          ownerId: '',
          title: '',
          baseServings: 2,
          ingredients: [Ingredient(id: _newId(), name: '')],
          steps: [RecipeStep(id: _newId(), order: 1, text: '')],
        );
    _baseline = _signature(_draft);
  }

  final RecipeRepository _repository;
  final String Function() _newId;
  late final String _folderId;
  late Recipe _draft;
  late String _baseline;
  bool _isEditing;

  bool _isSaving = false;
  bool _isUploading = false;
  Object? _uploadError;
  List<String> _errors = const [];

  /// Các ô số người dùng nhập sai định dạng, dạng `"<id>:<trường>"`.
  final Set<String> _invalidFields = {};

  Recipe get draft => _draft;
  bool get isEditing => _isEditing;
  bool get isSaving => _isSaving;
  bool get isUploading => _isUploading;
  Object? get uploadError => _uploadError;

  /// Các mã lỗi của lần kiểm tra gần nhất (rỗng nếu chưa lưu thất bại).
  List<String> get errors => _errors;

  bool get hasUnsavedChanges => _signature(_draft) != _baseline;

  List<String> ingredientErrors(int index) => _errorsAt('ingredients[$index].');
  List<String> stepErrors(int index) => _errorsAt('steps[$index].');

  List<String> _errorsAt(String prefix) =>
      _errors.where((e) => e.startsWith(prefix)).map((e) => e.substring(prefix.length)).toList();

  // ------------------------------------------------------------- thông tin chung

  void setTitle(String value) => _update(_draft.copyWith(title: value));
  void setBaseServings(int value) => _update(_draft.copyWith(baseServings: value));
  void setNote(String value) => _update(_draft.copyWith(note: value));
  void setTags(List<String> value) => _update(_draft.copyWith(tags: value));

  /// Thêm một thẻ: cắt/gộp khoảng trắng, tối đa [Recipe.maxTagLength] ký tự và
  /// [Recipe.maxTags] thẻ, loại trùng không phân biệt hoa thường và dấu
  /// (giữ cách viết gặp đầu tiên). Thẻ không hợp lệ không làm đổi bản nháp.
  TagAddResult addTag(String raw) {
    final tag = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (tag.isEmpty) return TagAddResult.empty;
    if (tag.length > Recipe.maxTagLength) return TagAddResult.tooLong;
    final key = normalizeForSearch(tag);
    if (_draft.tags.any((t) => normalizeForSearch(t) == key)) return TagAddResult.duplicate;
    if (_draft.tags.length >= Recipe.maxTags) return TagAddResult.tooMany;
    _update(_draft.copyWith(tags: [..._draft.tags, tag]));
    return TagAddResult.added;
  }

  void removeTag(int index) {
    if (!_inRange(index, _draft.tags.length)) return;
    _update(_draft.copyWith(tags: [..._draft.tags]..removeAt(index)));
  }
  void setImageUrl(String value) => _update(_draft.copyWith(imageUrl: value));

  // ------------------------------------------------------------------ nguyên liệu

  void addIngredient() {
    _update(_draft.copyWith(ingredients: [..._draft.ingredients, Ingredient(id: _newId(), name: '')]));
  }

  void updateIngredient(int index, Ingredient value) {
    if (!_inRange(index, _draft.ingredients.length)) return;
    final list = [..._draft.ingredients]..[index] = value;
    _update(_draft.copyWith(ingredients: list));
  }

  void removeIngredient(int index) {
    if (!_inRange(index, _draft.ingredients.length)) return;
    final removed = _draft.ingredients[index];
    _invalidFields.removeWhere((k) => k.startsWith('${removed.id}:'));
    _update(_draft.copyWith(ingredients: [..._draft.ingredients]..removeAt(index)));
  }

  /// Theo quy ước của `ReorderableListView`: [newIndex] là vị trí chèn tính
  /// trước khi gỡ phần tử ra khỏi vị trí cũ.
  void moveIngredient(int oldIndex, int newIndex) {
    final list = [..._draft.ingredients];
    if (!_move(list, oldIndex, newIndex)) return;
    _update(_draft.copyWith(ingredients: list));
  }

  // ------------------------------------------------------------------- bước nấu

  void addStep() {
    final steps = [..._draft.steps, RecipeStep(id: _newId(), order: _draft.steps.length + 1, text: '')];
    _update(_draft.copyWith(steps: steps));
  }

  void updateStep(int index, RecipeStep value) {
    if (!_inRange(index, _draft.steps.length)) return;
    final list = [..._draft.steps]..[index] = value;
    _update(_draft.copyWith(steps: _renumber(list)));
  }

  void removeStep(int index) {
    if (!_inRange(index, _draft.steps.length)) return;
    final removed = _draft.steps[index];
    _invalidFields.removeWhere((k) => k.startsWith('${removed.id}:'));
    _update(_draft.copyWith(steps: _renumber([..._draft.steps]..removeAt(index))));
  }

  void moveStep(int oldIndex, int newIndex) {
    final list = [..._draft.steps];
    if (!_move(list, oldIndex, newIndex)) return;
    _update(_draft.copyWith(steps: _renumber(list)));
  }

  void setStepImage(int index, String? url) {
    if (!_inRange(index, _draft.steps.length)) return;
    updateStep(index, _draft.steps[index].copyWith(imageUrl: url));
  }

  // --------------------------------------------------------------- ô nhập sai

  /// Giao diện báo một ô số (số lượng, giá, kcal, thời gian) đang nhập sai
  /// định dạng; bản nháp vẫn giữ giá trị hợp lệ gần nhất.
  void setFieldInvalid(String itemId, String field, bool invalid) {
    final key = '$itemId:$field';
    final changed = invalid ? _invalidFields.add(key) : _invalidFields.remove(key);
    if (changed) _refreshErrorsIfShown();
  }

  // ----------------------------------------------------------------------- ảnh

  /// Tải ảnh lên và trả về URL; `null` nếu thất bại (xem [uploadError]).
  /// Không đổi bản nháp: người gọi tự gán URL bằng [setImageUrl]/[setStepImage].
  Future<String?> uploadImage(File file) async {
    _isUploading = true;
    _uploadError = null;
    notifyListeners();
    try {
      return await _repository.uploadImage(file, recipeId: _folderId);
    } catch (e) {
      _uploadError = e;
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------- lưu

  /// Kiểm tra bản nháp (không thay đổi gì); trả về danh sách mã lỗi.
  List<String> validate() => _collectErrors(_draft);

  /// Lưu công thức. Trả về `id` nếu thành công, `null` nếu dữ liệu không hợp lệ
  /// ([errors] cho biết lỗi). Chỉ bỏ các dòng nguyên liệu/bước hoàn toàn trống;
  /// mọi dữ liệu khác được giữ nguyên khi lưu lỗi.
  Future<String?> save() async {
    if (_isSaving) return null;
    _removeBlankRows();
    _errors = _collectErrors(_draft);
    if (_errors.isNotEmpty) {
      notifyListeners();
      return null;
    }

    _isSaving = true;
    notifyListeners();
    try {
      final String id;
      if (_isEditing) {
        await _repository.update(_draft);
        id = _draft.id;
      } else {
        id = await _repository.create(_draft);
      }
      _draft = _draft.copyWith(id: id);
      _isEditing = true; // lần lưu sau là cập nhật, không tạo bản sao
      _baseline = _signature(_draft);
      return id;
    } on RecipeValidationException catch (e) {
      _errors = e.errors;
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ nội bộ

  void _update(Recipe next) {
    _draft = next;
    _refreshErrorsIfShown();
  }

  void _refreshErrorsIfShown() {
    if (_errors.isNotEmpty) _errors = _collectErrors(_draft);
    notifyListeners();
  }

  List<String> _collectErrors(Recipe recipe) {
    final errors = recipe.validate();
    for (var i = 0; i < recipe.ingredients.length; i++) {
      for (final field in const ['quantity', 'price', 'kcal']) {
        if (_invalidFields.contains('${recipe.ingredients[i].id}:$field')) {
          errors.add('ingredients[$i].${field}_invalid');
        }
      }
    }
    for (var i = 0; i < recipe.steps.length; i++) {
      if (_invalidFields.contains('${recipe.steps[i].id}:duration')) {
        errors.add('steps[$i].duration_invalid');
      }
    }
    return errors;
  }

  void _removeBlankRows() {
    final ingredients = _draft.ingredients.where((e) => !_isBlankIngredient(e)).toList();
    final steps = _renumber(_draft.steps.where((s) => !_isBlankStep(s)).toList());
    if (ingredients.length != _draft.ingredients.length || steps.length != _draft.steps.length) {
      _draft = _draft.copyWith(ingredients: ingredients, steps: steps);
    }
  }

  bool _isBlankIngredient(Ingredient e) =>
      e.name.trim().isEmpty &&
      e.quantity == null &&
      (e.unit ?? '').trim().isEmpty &&
      e.price == null &&
      e.kcal == null &&
      !_hasInvalid(e.id);

  bool _isBlankStep(RecipeStep s) =>
      s.text.trim().isEmpty && s.durationSec == null && s.imageUrl == null && !_hasInvalid(s.id);

  bool _hasInvalid(String id) => _invalidFields.any((k) => k.startsWith('$id:'));

  static bool _inRange(int index, int length) => index >= 0 && index < length;

  static bool _move<T>(List<T> list, int oldIndex, int newIndex) {
    if (!_inRange(oldIndex, list.length)) return false;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, list.length - 1);
    if (target == oldIndex) return false;
    list.insert(target, list.removeAt(oldIndex));
    return true;
  }

  static List<RecipeStep> _renumber(List<RecipeStep> steps) =>
      [for (var i = 0; i < steps.length; i++) steps[i].copyWith(order: i + 1)];

  /// Chuỗi đặc trưng của nội dung bản nháp (bỏ thời gian) để so sánh thay đổi.
  static String _signature(Recipe r) => jsonEncode({
        'title': r.title,
        'baseServings': r.baseServings,
        'note': r.note,
        'imageUrl': r.imageUrl,
        'tags': r.tags,
        'ingredients': r.ingredients.map((e) => e.toMap()).toList(),
        'steps': r.steps.map((e) => e.toMap()).toList(),
      });
}
