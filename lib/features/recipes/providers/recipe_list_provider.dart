import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/migration_result.dart';
import '../data/recipe_repository.dart';
import '../domain/recipe_filter.dart';
import '../domain/text_normalizer.dart';
import '../models/recipe.dart';

/// Chạy việc chuyển dữ liệu công thức cũ (GĐ US5 cung cấp bản cài đặt).
typedef MigrationRunner = Future<MigrationResult> Function();

/// Trạng thái danh sách công thức của người dùng hiện tại.
class RecipeListProvider extends ChangeNotifier {
  RecipeListProvider({required RecipeRepository repository, MigrationRunner? migrationRunner})
      : _repository = repository,
        _migrationRunner = migrationRunner {
    _userSub = _repository.watchUserId().listen(_onUserChanged);
    _recipesSub = _repository.watchMyRecipes().listen(
      _onRecipes,
      onError: _onError,
    );
  }

  final RecipeRepository _repository;
  final MigrationRunner? _migrationRunner;
  StreamSubscription<String?>? _userSub;
  StreamSubscription<List<Recipe>>? _recipesSub;

  String? _uid;
  bool _uidSeen = false;
  bool _isLoading = true;
  Object? _error;
  List<Recipe> _recipes = const [];

  // Tìm kiếm và lọc theo thẻ (chạy trên danh sách của chính người dùng, cả khi offline).
  String _query = '';
  final Set<String> _selectedTags = {};
  List<Recipe> _filtered = const [];
  List<TagCount> _tags = const [];

  bool _migrationStarted = false;
  bool _migrationRequested = false;
  MigrationResult? _lastMigration;

  List<Recipe> get recipes => _recipes;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  bool get isEmpty => _recipes.isEmpty;

  /// Từ khoá tìm kiếm hiện tại (đúng như người dùng đã gõ).
  String get query => _query;

  /// Khoá (đã chuẩn hoá) của các thẻ đang chọn để lọc.
  Set<String> get selectedTags => Set.unmodifiable(_selectedTags);

  /// Công thức sau khi áp dụng từ khoá và thẻ; không lọc thì là toàn bộ.
  List<Recipe> get filteredRecipes => _filtered;

  /// Các thẻ đang dùng kèm số công thức, để hiện thanh lọc.
  List<TagCount> get availableTags => _tags;

  bool get hasActiveFilters => _query.trim().isNotEmpty || _selectedTags.isNotEmpty;

  /// Có công thức nhưng bộ lọc loại hết (khác với chưa có công thức nào).
  bool get isFilteredEmpty => _recipes.isNotEmpty && _filtered.isEmpty;

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _applyFilters();
    notifyListeners();
  }

  /// Chọn hoặc bỏ chọn một thẻ (nhận thẻ ở dạng bất kỳ, so khớp theo dạng chuẩn hoá).
  void toggleTag(String tag) {
    final key = normalizeForSearch(tag);
    if (key.isEmpty) return;
    if (!_selectedTags.remove(key)) _selectedTags.add(key);
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    if (_query.isEmpty && _selectedTags.isEmpty) return;
    _query = '';
    _selectedTags.clear();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filtered = filterRecipes(_recipes, _query, _selectedTags);
  }

  /// Kết quả của lần chuyển dữ liệu cũ gần nhất (null nếu chưa chạy hoặc không có gì để chuyển).
  MigrationResult? get lastMigration => _lastMigration;

  /// Xoá thông báo kết quả chuyển dữ liệu sau khi đã hiển thị.
  void clearMigrationNotice() {
    if (_lastMigration == null) return;
    _lastMigration = null;
    notifyListeners();
  }

  void _onUserChanged(String? uid) {
    if (_uidSeen && uid == _uid) return;
    final firstEvent = !_uidSeen;
    _uidSeen = true;
    _uid = uid;
    if (firstEvent) {
      if (uid != null && _migrationRequested) runMigrationIfNeeded();
      return;
    }
    // Đăng xuất hoặc đổi tài khoản: bỏ ngay dữ liệu của tài khoản trước.
    _recipes = const [];
    _filtered = const [];
    _tags = const [];
    _query = '';
    _selectedTags.clear();
    _error = null;
    _isLoading = uid != null;
    _migrationStarted = false;
    _lastMigration = null;
    notifyListeners();
    // Giao diện đã yêu cầu chuyển dữ liệu từ trước khi biết tài khoản: chạy ngay bây giờ.
    if (uid != null && _migrationRequested) runMigrationIfNeeded();
  }

  void _onRecipes(List<Recipe> recipes) {
    _recipes = recipes;
    _tags = collectTags(recipes);
    // Thẻ đã chọn mà không còn công thức nào dùng thì bỏ chọn, để khỏi kẹt ở danh sách rỗng.
    final available = _tags.map((t) => t.key).toSet();
    _selectedTags.removeWhere((key) => !available.contains(key));
    _applyFilters();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  void _onError(Object error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> delete(String id) => _repository.delete(id);

  /// Chuyển dữ liệu cũ nếu cần, chỉ chạy một lần cho mỗi lần đăng nhập. Giao
  /// diện gọi hàm này thay vì gọi service trực tiếp. Lỗi (ví dụ mất mạng) được
  /// bỏ qua để lần sau thử lại, không chặn người dùng.
  Future<void> runMigrationIfNeeded() async {
    final runner = _migrationRunner;
    if (runner == null || _migrationStarted) return;
    if (_uid == null) {
      _migrationRequested = true; // chạy khi đăng nhập xong
      return;
    }
    _migrationRequested = false;
    _migrationStarted = true;
    try {
      final result = await runner();
      if (!result.isEmpty) {
        _lastMigration = result;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Chuyển dữ liệu công thức cũ thất bại, sẽ thử lại sau: $e');
      _migrationStarted = false;
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _recipesSub?.cancel();
    super.dispose();
  }
}
