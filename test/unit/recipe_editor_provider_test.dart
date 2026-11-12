import 'dart:io';

import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_editor_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository có Firestore giả nhưng cho phép điều khiển việc tải ảnh.
class _UploadRepo extends FirestoreRecipeRepository {
  _UploadRepo(FakeFirebaseFirestore db, MockFirebaseAuth auth) : super(firestore: db, auth: auth);

  Object? uploadError;
  String uploadUrl = 'https://example.com/photo.jpg';
  final uploaded = <String>[];

  @override
  Future<String> uploadImage(File file, {required String recipeId}) async {
    if (uploadError != null) throw uploadError!;
    uploaded.add(recipeId);
    return uploadUrl;
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late _UploadRepo repo;
  var counter = 0;

  String nextId() => 'id${++counter}';

  RecipeEditorProvider newEditor() => RecipeEditorProvider(repository: repo, idGenerator: nextId);

  /// Điền một công thức hợp lệ tối thiểu vào bản nháp.
  void fillValid(RecipeEditorProvider p) {
    p.setTitle('Trứng chiên');
    p.updateIngredient(0, p.draft.ingredients[0].copyWith(name: 'trứng', quantity: 2.0, unit: 'quả'));
    p.updateStep(0, p.draft.steps[0].copyWith(text: 'Chiên trứng'));
  }

  setUp(() {
    counter = 0;
    db = FakeFirebaseFirestore();
    repo = _UploadRepo(db, MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')));
  });

  group('bản nháp mới', () {
    test('bắt đầu với 1 nguyên liệu trống, 1 bước trống, 2 khẩu phần', () {
      final p = newEditor();
      expect(p.isEditing, isFalse);
      expect(p.draft.baseServings, 2);
      expect(p.draft.ingredients, hasLength(1));
      expect(p.draft.steps, hasLength(1));
      expect(p.draft.steps.single.order, 1);
      expect(p.hasUnsavedChanges, isFalse);
    });
  });

  group('cờ "có thay đổi chưa lưu"', () {
    test('đổi nội dung → true, trả về như cũ → false', () {
      final p = newEditor();
      p.setTitle('A');
      expect(p.hasUnsavedChanges, isTrue);
      p.setTitle('');
      expect(p.hasUnsavedChanges, isFalse);
    });

    test('thêm một nguyên liệu → true', () {
      final p = newEditor()..addIngredient();
      expect(p.hasUnsavedChanges, isTrue);
    });

    test('lưu xong → false', () async {
      final p = newEditor();
      fillValid(p);
      expect(p.hasUnsavedChanges, isTrue);
      await p.save();
      expect(p.hasUnsavedChanges, isFalse);
    });
  });

  group('nguyên liệu', () {
    test('thêm và xoá', () {
      final p = newEditor()..addIngredient()..addIngredient();
      expect(p.draft.ingredients, hasLength(3));
      p.removeIngredient(1);
      expect(p.draft.ingredients, hasLength(2));
    });

    test('mỗi dòng có id riêng', () {
      final p = newEditor()..addIngredient();
      expect(p.draft.ingredients.map((e) => e.id).toSet(), hasLength(2));
    });

    test('đổi thứ tự theo quy ước ReorderableListView', () {
      final p = newEditor()..addIngredient()..addIngredient();
      p.updateIngredient(0, p.draft.ingredients[0].copyWith(name: 'A'));
      p.updateIngredient(1, p.draft.ingredients[1].copyWith(name: 'B'));
      p.updateIngredient(2, p.draft.ingredients[2].copyWith(name: 'C'));
      p.moveIngredient(0, 3); // kéo A xuống cuối (newIndex là vị trí chèn trước khi gỡ)
      expect(p.draft.ingredients.map((e) => e.name), ['B', 'C', 'A']);
      p.moveIngredient(2, 0); // kéo A lên đầu
      expect(p.draft.ingredients.map((e) => e.name), ['A', 'B', 'C']);
    });

    test('xoá chỉ số ngoài phạm vi không gây lỗi', () {
      final p = newEditor()..removeIngredient(5);
      expect(p.draft.ingredients, hasLength(1));
    });
  });

  group('bước nấu: order luôn liên tục từ 1', () {
    List<int> orders(RecipeEditorProvider p) => p.draft.steps.map((s) => s.order).toList();

    test('thêm', () {
      final p = newEditor()..addStep()..addStep();
      expect(orders(p), [1, 2, 3]);
    });

    test('xoá bước giữa', () {
      final p = newEditor()..addStep()..addStep();
      p.removeStep(1);
      expect(orders(p), [1, 2]);
    });

    test('đổi thứ tự', () {
      final p = newEditor()..addStep()..addStep();
      for (var i = 0; i < 3; i++) {
        p.updateStep(i, p.draft.steps[i].copyWith(text: 'bước ${'ABC'[i]}'));
      }
      p.moveStep(2, 0);
      expect(p.draft.steps.map((s) => s.text), ['bước C', 'bước A', 'bước B']);
      expect(orders(p), [1, 2, 3]);
    });
  });

  group('lưu thất bại và liệt kê lỗi', () {
    test('tên trống', () async {
      final p = newEditor();
      fillValid(p);
      p.setTitle('   ');
      expect(await p.save(), isNull);
      expect(p.errors, contains('title_required'));
      expect((await db.collection('recipes').get()).docs, isEmpty);
    });

    test('0 nguyên liệu', () async {
      final p = newEditor();
      fillValid(p);
      p.removeIngredient(0);
      expect(await p.save(), isNull);
      expect(p.errors, contains('ingredients_required'));
    });

    test('0 bước', () async {
      final p = newEditor();
      fillValid(p);
      p.removeStep(0);
      expect(await p.save(), isNull);
      expect(p.errors, contains('steps_required'));
    });

    test('quantity âm được gắn đúng dòng', () async {
      final p = newEditor();
      fillValid(p);
      p.updateIngredient(0, p.draft.ingredients[0].copyWith(quantity: -1.0));
      expect(await p.save(), isNull);
      expect(p.errors, contains('ingredients[0].quantity_negative'));
      expect(p.ingredientErrors(0), contains('quantity_negative'));
    });

    test('durationSec ≤ 0 được gắn đúng bước', () async {
      final p = newEditor();
      fillValid(p);
      p.updateStep(0, p.draft.steps[0].copyWith(durationSec: 0));
      expect(await p.save(), isNull);
      expect(p.errors, contains('steps[0].duration_invalid'));
      expect(p.stepErrors(0), contains('duration_invalid'));
    });

    test('ô số nhập sai định dạng chặn lưu', () async {
      final p = newEditor();
      fillValid(p);
      final id = p.draft.ingredients[0].id;
      p.setFieldInvalid(id, 'quantity', true);
      expect(await p.save(), isNull);
      expect(p.ingredientErrors(0), contains('quantity_invalid'));
      p.setFieldInvalid(id, 'quantity', false);
      expect(await p.save(), isNotNull);
    });

    test('baseServings ngoài 1–100', () async {
      final p = newEditor();
      fillValid(p);
      p.setBaseServings(0);
      expect(await p.save(), isNull);
      expect(p.errors, contains('servings_invalid'));
    });

    test('nhiều lỗi cùng lúc', () async {
      final p = newEditor();
      expect(await p.save(), isNull);
      expect(p.errors, containsAll(['title_required', 'ingredients_required', 'steps_required']));
    });
  });

  group('không mất dữ liệu khi lưu lỗi', () {
    test('giữ nguyên những gì người dùng đã nhập', () async {
      final p = newEditor();
      p.setNote('ghi chú quan trọng');
      p.updateIngredient(0, p.draft.ingredients[0].copyWith(name: 'trứng', quantity: 2.0));
      p.updateStep(0, p.draft.steps[0].copyWith(text: 'Chiên', durationSec: 120));
      expect(await p.save(), isNull); // thiếu tên món
      expect(p.draft.note, 'ghi chú quan trọng');
      expect(p.draft.ingredients.single.name, 'trứng');
      expect(p.draft.ingredients.single.quantity, 2.0);
      expect(p.draft.steps.single.text, 'Chiên');
      expect(p.draft.steps.single.durationSec, 120);
      expect(p.hasUnsavedChanges, isTrue);
    });

    test('sửa lỗi thì thông báo lỗi tự cập nhật', () async {
      final p = newEditor();
      fillValid(p);
      p.setTitle('');
      await p.save();
      expect(p.errors, contains('title_required'));
      p.setTitle('Món mới');
      expect(p.errors, isNot(contains('title_required')));
    });
  });

  group('lưu thành công', () {
    test('tạo mới: ghi vào Firestore, trả về id', () async {
      final p = newEditor();
      fillValid(p);
      final id = await p.save();
      expect(id, isNotNull);
      final data = (await db.collection('recipes').doc(id).get()).data()!;
      expect(data['title'], 'Trứng chiên');
      expect(data['ownerId'], 'alice');
      expect(p.errors, isEmpty);
      expect(p.isSaving, isFalse);
    });

    test('bỏ các dòng nguyên liệu/bước trống khi lưu', () async {
      final p = newEditor()..addIngredient()..addIngredient()..addStep();
      p.setTitle('Món');
      p.updateIngredient(1, p.draft.ingredients[1].copyWith(name: 'muối'));
      p.updateStep(1, p.draft.steps[1].copyWith(text: 'Nêm muối'));
      final id = await p.save();
      expect(id, isNotNull);
      final saved = (await repo.watchRecipe(id!).first)!;
      expect(saved.ingredients.map((e) => e.name), ['muối']);
      expect(saved.steps.map((s) => s.text), ['Nêm muối']);
      expect(saved.steps.single.order, 1);
    });

    test('lưu lần hai trên cùng bản nháp là cập nhật, không tạo bản sao', () async {
      final p = newEditor();
      fillValid(p);
      final id1 = await p.save();
      p.setTitle('Tên mới');
      final id2 = await p.save();
      expect(id2, id1);
      final docs = (await db.collection('recipes').get()).docs;
      expect(docs, hasLength(1));
      expect(docs.single.data()['title'], 'Tên mới');
    });

    test('sửa công thức có sẵn: giữ id và ownerId', () async {
      final id = await repo.create(Recipe(
        id: '',
        ownerId: 'x',
        title: 'Cũ',
        baseServings: 2,
        ingredients: const [Ingredient(id: 'i', name: 'x')],
        steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
      ));
      final existing = (await repo.watchRecipe(id).first)!;
      final p = RecipeEditorProvider(repository: repo, existing: existing, idGenerator: nextId);
      expect(p.isEditing, isTrue);
      expect(p.hasUnsavedChanges, isFalse);
      p.setTitle('Mới');
      expect(await p.save(), id);
      final data = (await db.collection('recipes').doc(id).get()).data()!;
      expect(data['title'], 'Mới');
      expect(data['ownerId'], 'alice');
    });
  });

  group('tải ảnh', () {
    test('thành công: trả về url, không tự đổi bản nháp', () async {
      final p = newEditor();
      final url = await p.uploadImage(File('x.jpg'));
      expect(url, 'https://example.com/photo.jpg');
      expect(p.uploadError, isNull);
      expect(p.isUploading, isFalse);
      expect(repo.uploaded, hasLength(1));
    });

    test('dùng id công thức sẵn có làm thư mục', () async {
      final id = await repo.create(Recipe(
        id: '',
        ownerId: 'x',
        title: 'A',
        baseServings: 2,
        ingredients: const [Ingredient(id: 'i', name: 'x')],
        steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
      ));
      final existing = (await repo.watchRecipe(id).first)!;
      final p = RecipeEditorProvider(repository: repo, existing: existing, idGenerator: nextId);
      await p.uploadImage(File('x.jpg'));
      expect(repo.uploaded.single, id);
    });

    test('offline: trả null, giữ nguyên dữ liệu đang nhập, ghi nhận lỗi', () async {
      final p = newEditor();
      fillValid(p);
      repo.uploadError = OfflineException();
      final url = await p.uploadImage(File('x.jpg'));
      expect(url, isNull);
      expect(p.uploadError, isA<OfflineException>());
      expect(p.draft.title, 'Trứng chiên');
      expect(p.draft.ingredients.single.name, 'trứng');
    });

    test('setImageUrl và setStepImage cập nhật bản nháp', () {
      final p = newEditor();
      p.setImageUrl('https://x/a.jpg');
      p.setStepImage(0, 'https://x/b.jpg');
      expect(p.draft.imageUrl, 'https://x/a.jpg');
      expect(p.draft.steps[0].imageUrl, 'https://x/b.jpg');
      p.setStepImage(0, null);
      expect(p.draft.steps[0].imageUrl, isNull);
    });
  });

  group('thẻ', () {
    test('thêm thẻ hợp lệ', () {
      final p = newEditor();
      expect(p.addTag('món sinh viên'), TagAddResult.added);
      expect(p.draft.tags, ['món sinh viên']);
      expect(p.hasUnsavedChanges, isTrue);
    });

    test('cắt khoảng trắng hai đầu và gộp khoảng trắng bên trong', () {
      final p = newEditor();
      p.addTag('  món   sinh \t viên  ');
      expect(p.draft.tags, ['món sinh viên']);
    });

    test('thẻ rỗng hoặc chỉ khoảng trắng bị bỏ qua', () {
      final p = newEditor();
      expect(p.addTag(''), TagAddResult.empty);
      expect(p.addTag('    '), TagAddResult.empty);
      expect(p.draft.tags, isEmpty);
      expect(p.hasUnsavedChanges, isFalse);
    });

    test('thẻ dài đúng 30 ký tự được nhận, 31 ký tự bị từ chối', () {
      final p = newEditor();
      expect(p.addTag('a' * 30), TagAddResult.added);
      expect(p.addTag('b' * 31), TagAddResult.tooLong);
      expect(p.draft.tags, ['a' * 30]);
    });

    test('loại trùng không phân biệt hoa thường và dấu', () {
      final p = newEditor();
      expect(p.addTag('Món Sinh Viên'), TagAddResult.added);
      expect(p.addTag('món sinh viên'), TagAddResult.duplicate);
      expect(p.addTag('MON SINH VIEN'), TagAddResult.duplicate);
      expect(p.addTag('  mon   sinh vien '), TagAddResult.duplicate);
      expect(p.draft.tags, ['Món Sinh Viên']); // giữ cách viết đầu tiên
    });

    test('tối đa 20 thẻ', () {
      final p = newEditor();
      for (var i = 0; i < 20; i++) {
        expect(p.addTag('thẻ $i'), TagAddResult.added);
      }
      expect(p.addTag('thẻ thứ 21'), TagAddResult.tooMany);
      expect(p.draft.tags, hasLength(20));
    });

    test('xoá thẻ theo vị trí; chỉ số sai không gây lỗi', () {
      final p = newEditor()..addTag('a')..addTag('b')..addTag('c');
      p.removeTag(1);
      expect(p.draft.tags, ['a', 'c']);
      p.removeTag(9);
      p.removeTag(-1);
      expect(p.draft.tags, ['a', 'c']);
    });

    test('xoá bớt thẻ rồi thêm lại được (không còn bị coi là trùng)', () {
      final p = newEditor()..addTag('nhanh');
      p.removeTag(0);
      expect(p.addTag('Nhanh'), TagAddResult.added);
    });

    test('thẻ được lưu cùng công thức', () async {
      final p = newEditor();
      fillValid(p);
      p.addTag('nhanh');
      p.addTag('món sinh viên');
      final id = await p.save();
      final data = (await db.collection('recipes').doc(id).get()).data()!;
      expect(data['tags'], ['nhanh', 'món sinh viên']);
    });

    test('sửa công thức có sẵn: giữ thẻ cũ và không cho thêm thẻ trùng', () async {
      final id = await repo.create(Recipe(
        id: '',
        ownerId: 'x',
        title: 'A',
        baseServings: 2,
        ingredients: const [Ingredient(id: 'i', name: 'x')],
        steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
        tags: const ['nhanh'],
      ));
      final existing = (await repo.watchRecipe(id).first)!;
      final p = RecipeEditorProvider(repository: repo, existing: existing, idGenerator: nextId);
      expect(p.draft.tags, ['nhanh']);
      expect(p.hasUnsavedChanges, isFalse);
      expect(p.addTag('NHANH'), TagAddResult.duplicate);
      expect(p.hasUnsavedChanges, isFalse);
    });

    test('setTags vẫn dùng được để thay cả danh sách', () {
      final p = newEditor()..setTags(['a', 'b']);
      expect(p.draft.tags, ['a', 'b']);
    });
  });
}
