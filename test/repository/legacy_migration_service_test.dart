import 'package:btl_ltdd/features/recipes/data/legacy_migration_service.dart';
import 'package:btl_ltdd/features/recipes/domain/legacy_converter.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// Firestore giả có thể bắt mọi lần ghi theo lô (batch) thất bại, để thử lỗi giữa chừng.
class _FailingFirestore extends FakeFirebaseFirestore {
  bool failCommits = false;

  @override
  WriteBatch batch() => failCommits ? _FailingBatch() : super.batch();
}

class _FailingBatch implements WriteBatch {
  @override
  Future<void> commit() => Future.error(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));

  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

void main() {
  late _FailingFirestore db;
  late FirebaseAuth auth;
  late LegacyMigrationService service;
  final fixedNow = DateTime.utc(2026, 6, 1, 12);

  /// Một món ăn của phiên bản cũ.
  Map<String, dynamic> food({
    String authorId = 'alice',
    String title = 'Thịt kho trứng',
    Object? ingredients = const ['500g thịt ba chỉ', '4 quả trứng', 'nước mắm vừa đủ'],
    String instructions = '1. Luộc trứng\n2. Kho thịt\n3. Bày ra đĩa',
    DateTime? createdAt,
    Map<String, dynamic> extra = const {},
  }) {
    return {
      'authorId': authorId,
      'title': title,
      'imageUrl': 'https://img/x.jpg',
      'ingredients': ingredients,
      'instructions': instructions,
      'note': 'ghi chú cũ',
      'isShared': true,
      'likedBy': ['bob'],
      'tags': ['món sinh viên', 'nhanh'],
      'category': 'Món mặn',
      'isApproved': true,
      'time': '45 phút',
      'servings': '4 người',
      'difficulty': 'Dễ',
      'isFeatured': false,
      'rating': 4.5,
      'videoUrl': 'https://video/x.mp4',
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt),
      ...extra,
    };
  }

  Future<Map<String, dynamic>> recipeData(String id) async => (await db.collection('recipes').doc(id).get()).data()!;

  Recipe recipeOf(Map<String, dynamic> data, String id) => Recipe.fromMap(data, id);

  setUp(() {
    db = _FailingFirestore();
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice'));
    service = LegacyMigrationService(firestore: db, auth: auth, now: () => fixedNow);
  });

  group('chuyển dữ liệu', () {
    test('ghi recipes/{foodId} cho món của người dùng, giữ nguyên văn trong legacy', () async {
      await db.collection('foods').doc('f1').set(food());
      final result = await service.migrateIfNeeded();

      expect(result.migrated, 1);
      final data = await recipeData('f1'); // ID xác định = ID món cũ
      expect(data['ownerId'], 'alice');
      expect(data['title'], 'Thịt kho trứng');
      expect(data['imageUrl'], 'https://img/x.jpg');
      expect(data['note'], 'ghi chú cũ');
      expect(data['tags'], ['món sinh viên', 'nhanh']);
      expect(data['schemaVersion'], 1);

      final legacy = data['legacy'] as Map<String, dynamic>;
      expect(legacy['title'], 'Thịt kho trứng');
      expect(legacy['ingredients'], ['500g thịt ba chỉ', '4 quả trứng', 'nước mắm vừa đủ']);
      expect(legacy['instructions'], '1. Luộc trứng\n2. Kho thịt\n3. Bày ra đĩa');
      expect(legacy['sourceCollection'], 'foods');
      expect(legacy['migratedAt'], isA<Timestamp>());
    });

    test('nguyên liệu được tách cấu trúc, bước được tách và đánh số', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      final recipe = recipeOf(await recipeData('f1'), 'f1');

      expect(recipe.ingredients.map((i) => [i.quantity, i.unit, i.name]), [
        [500.0, 'g', 'thịt ba chỉ'],
        [4.0, 'quả', 'trứng'],
        [null, null, 'nước mắm vừa đủ'],
      ]);
      expect(recipe.steps.map((s) => s.text), ['Luộc trứng', 'Kho thịt', 'Bày ra đĩa']);
      expect(recipe.steps.map((s) => s.order), [1, 2, 3]);
      expect(recipe.ingredients.every((i) => !i.isPlaceholder), isTrue);
      expect(recipe.steps.every((s) => !s.isPlaceholder), isTrue);
    });

    test('kết quả đếm số công thức và số dòng nguyên liệu giữ nguyên văn', () async {
      await db.collection('foods').doc('f1').set(food()); // 1 dòng tự do ("nước mắm vừa đủ")
      await db.collection('foods').doc('f2').set(food(ingredients: ['muối', 'tiêu', '2 quả chanh']));
      final result = await service.migrateIfNeeded();
      expect(result.migrated, 2);
      expect(result.unparsedIngredientLines, 3);
    });

    test('chuyển xong thì đặt users/{uid}.recipeMigratedAt', () async {
      await db.collection('foods').doc('f1').set(food());
      await db.collection('users').doc('alice').set({'role': 'blogger', 'name': 'An'});
      await service.migrateIfNeeded();
      final user = (await db.collection('users').doc('alice').get()).data()!;
      expect(user['recipeMigratedAt'], isNotNull);
      expect(user['name'], 'An'); // không làm mất dữ liệu hồ sơ
      expect(user['role'], 'blogger');
    });

    test('hồ sơ người dùng chưa có thì tạo mới chỉ với cờ', () async {
      await service.migrateIfNeeded();
      final user = (await db.collection('users').doc('alice').get()).data()!;
      expect(user.keys, ['recipeMigratedAt']);
    });

    test('chỉ chuyển món có authorId == uid', () async {
      await db.collection('foods').doc('mine').set(food());
      await db.collection('foods').doc('theirs').set(food(authorId: 'bob', title: 'Của bob'));
      await db.collection('foods').doc('admin').set(food(authorId: 'admin_id', title: 'Của admin'));
      final result = await service.migrateIfNeeded();

      expect(result.migrated, 1);
      final recipes = (await db.collection('recipes').get()).docs;
      expect(recipes.map((d) => d.id), ['mine']);
    });

    test('foods không bị sửa hoặc xoá', () async {
      await db.collection('foods').doc('f1').set(food());
      await db.collection('foods').doc('f2').set(food(title: 'Món 2'));
      final before = {for (final d in (await db.collection('foods').get()).docs) d.id: d.data()};
      await service.migrateIfNeeded();
      final after = {for (final d in (await db.collection('foods').get()).docs) d.id: d.data()};
      expect(after, before);
    });

    test('tài khoản không có dữ liệu cũ: chỉ đặt cờ, không có công thức nào', () async {
      final result = await service.migrateIfNeeded();
      expect(result.migrated, 0);
      expect(result.isEmpty, isTrue);
      expect((await db.collection('recipes').get()).docs, isEmpty);
      expect((await db.collection('users').doc('alice').get()).data()!['recipeMigratedAt'], isNotNull);
    });

    test('chưa đăng nhập: không làm gì', () async {
      final guest = LegacyMigrationService(
        firestore: db,
        auth: MockFirebaseAuth(signedIn: false),
        now: () => fixedNow,
      );
      await db.collection('foods').doc('f1').set(food());
      final result = await guest.migrateIfNeeded();
      expect(result.isEmpty, isTrue);
      expect((await db.collection('recipes').get()).docs, isEmpty);
    });

    test('hơn 400 món vẫn chuyển đủ (ghi theo từng lô)', () async {
      for (var i = 0; i < 450; i++) {
        await db.collection('foods').doc('f$i').set(food(title: 'Món $i'));
      }
      final result = await service.migrateIfNeeded();
      expect(result.migrated, 450);
      expect((await db.collection('recipes').get()).docs, hasLength(450));
    });
  });

  group('chạy lại an toàn (idempotent)', () {
    test('đã có cờ thì lần sau không làm gì', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      await db.collection('foods').doc('f2').set(food(title: 'Món thêm sau'));

      final second = await service.migrateIfNeeded();
      expect(second.isEmpty, isTrue);
      expect((await db.collection('recipes').get()).docs, hasLength(1));
    });

    test('chạy lại sau khi mất cờ không tạo bản sao', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      await db.collection('users').doc('alice').update({'recipeMigratedAt': FieldValue.delete()});

      final again = await service.migrateIfNeeded();
      expect(again.migrated, 0);
      expect((await db.collection('recipes').get()).docs, hasLength(1));
      expect((await db.collection('users').doc('alice').get()).data()!['recipeMigratedAt'], isNotNull);
    });

    test('chạy lại không ghi đè chỉnh sửa của người dùng trên công thức đã chuyển', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      await db.collection('recipes').doc('f1').update({'title': 'Tôi đã sửa tên'});
      await db.collection('users').doc('alice').update({'recipeMigratedAt': FieldValue.delete()});

      await service.migrateIfNeeded();
      expect((await recipeData('f1'))['title'], 'Tôi đã sửa tên');
    });

    test('chạy lại chỉ chuyển nốt những món chưa có', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      await db.collection('foods').doc('f2').set(food(title: 'Món chưa chuyển'));
      await db.collection('users').doc('alice').update({'recipeMigratedAt': FieldValue.delete()});

      final result = await service.migrateIfNeeded();
      expect(result.migrated, 1);
      expect((await db.collection('recipes').get()).docs.map((d) => d.id).toSet(), {'f1', 'f2'});
    });

    test('hai lần chuyển cho cùng một món cho cùng nội dung (ID nguyên liệu/bước xác định)', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      final first = recipeOf(await recipeData('f1'), 'f1');
      await db.collection('recipes').doc('f1').delete();
      await db.collection('users').doc('alice').update({'recipeMigratedAt': FieldValue.delete()});
      await service.migrateIfNeeded();
      final second = recipeOf(await recipeData('f1'), 'f1');
      expect(second.ingredients.map((i) => i.id), first.ingredients.map((i) => i.id));
      expect(second.steps.map((s) => s.id), first.steps.map((s) => s.id));
    });
  });

  group('lỗi giữa chừng', () {
    test('ghi thất bại: ném lỗi, chưa đặt cờ, chưa có công thức nào', () async {
      await db.collection('foods').doc('f1').set(food());
      db.failCommits = true;

      await expectLater(service.migrateIfNeeded(), throwsA(isA<FirebaseException>()));
      expect((await db.collection('users').doc('alice').get()).data()?['recipeMigratedAt'], isNull);
      expect((await db.collection('recipes').get()).docs, isEmpty);
    });

    test('thử lại sau khi có mạng thì chuyển được bình thường', () async {
      await db.collection('foods').doc('f1').set(food());
      db.failCommits = true;
      await expectLater(service.migrateIfNeeded(), throwsA(anything));

      db.failCommits = false;
      final result = await service.migrateIfNeeded();
      expect(result.migrated, 1);
      expect((await db.collection('users').doc('alice').get()).data()!['recipeMigratedAt'], isNotNull);
    });
  });

  group('quy tắc bù (FR-022): mọi bản chuyển đều hợp lệ', () {
    test('không có nguyên liệu → đúng 1 dòng giữ chỗ, đánh dấu isPlaceholder', () async {
      await db.collection('foods').doc('f1').set(food(ingredients: <String>[]));
      await service.migrateIfNeeded();
      final r = recipeOf(await recipeData('f1'), 'f1');
      expect(r.ingredients, hasLength(1));
      expect(r.ingredients.single.isPlaceholder, isTrue);
      expect(r.ingredients.single.name, '(Chưa có nguyên liệu)');
      expect(r.ingredients.single.quantity, isNull);
      expect(r.validate(), isEmpty);
    });

    test('nguyên liệu null hoặc toàn dòng rỗng cũng được bù', () async {
      await db.collection('foods').doc('a').set(food(ingredients: null));
      await db.collection('foods').doc('b').set(food(ingredients: ['', '   ']));
      await service.migrateIfNeeded();
      for (final id in ['a', 'b']) {
        final r = recipeOf(await recipeData(id), id);
        expect(r.ingredients.single.isPlaceholder, isTrue, reason: id);
        expect(r.validate(), isEmpty, reason: id);
      }
    });

    test('hướng dẫn rỗng → đúng 1 bước giữ chỗ, đánh dấu isPlaceholder', () async {
      await db.collection('foods').doc('f1').set(food(instructions: ''));
      await service.migrateIfNeeded();
      final r = recipeOf(await recipeData('f1'), 'f1');
      expect(r.steps, hasLength(1));
      expect(r.steps.single.isPlaceholder, isTrue);
      expect(r.steps.single.text, '(Chưa có hướng dẫn)');
      expect(r.steps.single.order, 1);
      expect(r.validate(), isEmpty);
    });

    test('tên rỗng → tên giữ chỗ, tên gốc rỗng nằm ở legacy.title', () async {
      await db.collection('foods').doc('f1').set(food(title: '   '));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      expect(data['title'], '(Món chưa đặt tên)');
      expect((data['legacy'] as Map)['title'], '   ');
      expect(recipeOf(data, 'f1').validate(), isEmpty);
    });

    test('tên dài hơn 120 ký tự → cắt còn 120, tên đầy đủ nằm ở legacy.title', () async {
      final longTitle = 'Món ăn ${'rất ' * 60}ngon';
      expect(longTitle.length, greaterThan(120));
      await db.collection('foods').doc('f1').set(food(title: longTitle));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      expect((data['title'] as String).length, lessThanOrEqualTo(120));
      expect(longTitle.startsWith((data['title'] as String).trim()), isTrue);
      expect((data['legacy'] as Map)['title'], longTitle);
      expect(recipeOf(data, 'f1').validate(), isEmpty);
    });

    test('dòng nguyên liệu quá 100 ký tự → cắt tên, nguyên văn nằm ở legacy.ingredients', () async {
      final longLine = '2 quả ${'trứng ' * 50}';
      await db.collection('foods').doc('f1').set(food(ingredients: [longLine]));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      final r = recipeOf(data, 'f1');
      expect(r.ingredients.single.name.length, lessThanOrEqualTo(100));
      expect(((data['legacy'] as Map)['ingredients'] as List).single, longLine);
      expect(r.validate(), isEmpty);
    });

    test('bước dài hơn 1000 ký tự được tách, không mất chữ nào', () async {
      final longStep = List.generate(400, (i) => 'từ$i').join(' ');
      expect(longStep.length, greaterThan(1000));
      await db.collection('foods').doc('f1').set(food(instructions: longStep));
      await service.migrateIfNeeded();
      final r = recipeOf(await recipeData('f1'), 'f1');
      expect(r.steps.length, greaterThan(1));
      expect(r.steps.every((s) => s.text.length <= 1000), isTrue);
      expect(r.steps.map((s) => s.text).join(' '), longStep);
      expect(r.validate(), isEmpty);
    });

    test('hơn 100 nguyên liệu và hơn 100 bước → giữ 100 mục đầu, phần còn lại nằm trong legacy', () async {
      final ingredients = [for (var i = 0; i < 130; i++) '$i quả thứ $i'];
      final steps = [for (var i = 0; i < 130; i++) 'Bước làm số $i'].join('\n');
      await db.collection('foods').doc('f1').set(food(ingredients: ingredients, instructions: steps));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      final r = recipeOf(data, 'f1');
      expect(r.ingredients, hasLength(100));
      expect(r.steps, hasLength(100));
      expect(r.validate(), isEmpty);
      final legacy = data['legacy'] as Map;
      expect(legacy['ingredients'], hasLength(130));
      expect((legacy['instructions'] as String).split('\n'), hasLength(130));
    });

    test('thẻ: tối đa 20 thẻ, mỗi thẻ ≤ 30 ký tự, bỏ thẻ rỗng và trùng', () async {
      final tags = [
        for (var i = 0; i < 30; i++) 'thẻ $i',
        'x' * 50,
        '  ',
        'Nhanh',
        'nhanh',
      ];
      await db.collection('foods').doc('f1').set(food(extra: {'tags': tags}));
      await service.migrateIfNeeded();
      final r = recipeOf(await recipeData('f1'), 'f1');
      expect(r.tags.length, lessThanOrEqualTo(20));
      expect(r.tags.every((t) => t.length <= 30 && t.trim().isNotEmpty), isTrue);
      expect(r.validate(), isEmpty);
    });

    test('ghi chú dài hơn 2000 ký tự → cắt, phần gốc đầy đủ nằm ở legacy.extra', () async {
      final note = 'ghi chú ' * 400;
      await db.collection('foods').doc('f1').set(food(extra: {'note': note}));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      expect((data['note'] as String).length, lessThanOrEqualTo(2000));
      expect(((data['legacy'] as Map)['extra'] as Map)['note'], note);
      expect(recipeOf(data, 'f1').validate(), isEmpty);
    });

    test('dữ liệu hỏng/thiếu trường vẫn chuyển được và hợp lệ', () async {
      await db.collection('foods').doc('f1').set({'authorId': 'alice'}); // thiếu mọi thứ
      await db.collection('foods').doc('f2').set({'authorId': 'alice', 'ingredients': [1, null, 'muối'], 'tags': 'không phải mảng', 'title': 42});
      final result = await service.migrateIfNeeded();
      expect(result.migrated, 2);
      for (final id in ['f1', 'f2']) {
        expect(recipeOf(await recipeData(id), id).validate(), isEmpty, reason: id);
      }
    });

    test('mọi bản chuyển đều qua Recipe.validate() không lỗi', () async {
      await db.collection('foods').doc('a').set(food());
      await db.collection('foods').doc('b').set(food(title: '', ingredients: <String>[], instructions: ''));
      await db.collection('foods').doc('c').set(food(title: 'x' * 300, ingredients: ['y' * 300], instructions: 'z' * 3000));
      await service.migrateIfNeeded();
      for (final id in ['a', 'b', 'c']) {
        expect(recipeOf(await recipeData(id), id).validate(), isEmpty, reason: id);
      }
    });
  });

  group('createdAt, khẩu phần và dữ liệu phụ', () {
    test('giữ createdAt của món cũ', () async {
      final created = DateTime.utc(2025, 3, 4, 5, 6, 7);
      await db.collection('foods').doc('f1').set(food(createdAt: created));
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      expect((data['createdAt'] as Timestamp).toDate().isAtSameMomentAs(created), isTrue);
    });

    test('thiếu createdAt thì dùng thời điểm chuyển', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      expect((data['createdAt'] as Timestamp).toDate().isAtSameMomentAs(fixedNow), isTrue);
    });

    test('updatedAt được đặt khi chuyển', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      expect((await recipeData('f1'))['updatedAt'], isNotNull);
    });

    test('baseServings suy ra từ servings cũ, mặc định 2', () async {
      await db.collection('foods').doc('a').set(food(extra: {'servings': '4 người'}));
      await db.collection('foods').doc('b').set(food(extra: {'servings': '4-5 người'}));
      await db.collection('foods').doc('c').set(food(extra: {'servings': ''}));
      await db.collection('foods').doc('d').set(food(extra: {'servings': 'vài người'}));
      await db.collection('foods').doc('e').set(food(extra: {'servings': '0 người'}));
      await service.migrateIfNeeded();
      expect((await recipeData('a'))['baseServings'], 4);
      expect((await recipeData('b'))['baseServings'], 4);
      expect((await recipeData('c'))['baseServings'], 2);
      expect((await recipeData('d'))['baseServings'], 2);
      expect((await recipeData('e'))['baseServings'], 2);
    });

    test('thông tin cũ không có chỗ trong mô hình mới (thời gian, độ khó, danh mục, video) được giữ ở legacy.extra', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      final extra = ((await recipeData('f1'))['legacy'] as Map)['extra'] as Map;
      expect(extra['time'], '45 phút');
      expect(extra['difficulty'], 'Dễ');
      expect(extra['category'], 'Món mặn');
      expect(extra['videoUrl'], 'https://video/x.mp4');
      expect(extra['servings'], '4 người');
    });

    test('công thức chuyển không mang theo trường mạng xã hội cũ', () async {
      await db.collection('foods').doc('f1').set(food());
      await service.migrateIfNeeded();
      final data = await recipeData('f1');
      for (final key in ['likedBy', 'isShared', 'isApproved', 'isFeatured', 'rating', 'authorId']) {
        expect(data.containsKey(key), isFalse, reason: key);
      }
    });
  });

  group('convertLegacyFood', () {
    test('trả về số dòng nguyên liệu không phân tích được', () {
      final c = convertLegacyFood(
        foodId: 'f',
        ownerId: 'u',
        data: food(ingredients: ['2 quả trứng', 'muối', 'tiêu']),
        migratedAt: fixedNow,
      );
      expect(c.unparsedIngredientLines, 2);
    });

    test('dòng giữ chỗ không được tính là dòng không phân tích được', () {
      final c = convertLegacyFood(foodId: 'f', ownerId: 'u', data: food(ingredients: <String>[]), migratedAt: fixedNow);
      expect(c.unparsedIngredientLines, 0);
    });

    test('ID nguyên liệu và bước xác định theo foodId và vị trí', () {
      final c = convertLegacyFood(foodId: 'abc', ownerId: 'u', data: food(), migratedAt: fixedNow);
      expect(c.recipe.id, 'abc');
      expect(c.recipe.ingredients.map((i) => i.id), ['abc_i0', 'abc_i1', 'abc_i2']);
      expect(c.recipe.steps.map((s) => s.id), ['abc_s0', 'abc_s1', 'abc_s2']);
    });
  });
}
