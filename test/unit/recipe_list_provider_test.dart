import 'package:btl_ltdd/features/recipes/data/migration_result.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe draft(String title) => Recipe(
      id: '',
      ownerId: 'x',
      title: title,
      baseServings: 2,
      ingredients: const [Ingredient(id: 'i', name: 'x')],
      steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
    );

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late FirestoreRecipeRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice'));
    repo = FirestoreRecipeRepository(firestore: db, auth: auth);
  });

  group('danh sách', () {
    test('bắt đầu ở trạng thái tải rồi hiện công thức của mình', () async {
      await repo.create(draft('Món A'));
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      expect(p.isLoading, isTrue);
      await pumpEventQueue();
      expect(p.isLoading, isFalse);
      expect(p.recipes.map((r) => r.title), ['Món A']);
      expect(p.error, isNull);
    });

    test('không có công thức → isEmpty và hết trạng thái tải', () async {
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      expect(p.isLoading, isFalse);
      expect(p.isEmpty, isTrue);
    });

    test('công thức mới tạo tự xuất hiện', () async {
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      await repo.create(draft('Mới'));
      await pumpEventQueue();
      expect(p.recipes.map((r) => r.title), ['Mới']);
    });

    test('đăng xuất → xoá ngay danh sách của tài khoản trước', () async {
      await repo.create(draft('Riêng tư'));
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      expect(p.recipes, hasLength(1));

      await auth.signOut();
      await pumpEventQueue();
      expect(p.recipes, isEmpty);
      expect(p.isLoading, isFalse); // không còn ai đăng nhập → không chờ dữ liệu
    });

    test('xoá công thức', () async {
      final id = await repo.create(draft('Xoá tôi'));
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.delete(id);
      await pumpEventQueue();
      expect(p.recipes, isEmpty);
    });

    test('thông báo cho người nghe khi dữ liệu đổi', () async {
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      var notified = 0;
      p.addListener(() => notified++);
      await pumpEventQueue();
      expect(notified, greaterThan(0));
    });
  });

  group('chuyển dữ liệu cũ', () {
    test('không có runner → không làm gì', () async {
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.runMigrationIfNeeded();
      expect(p.lastMigration, isNull);
    });

    test('chạy đúng một lần và lưu kết quả để hiển thị', () async {
      var calls = 0;
      final p = RecipeListProvider(
        repository: repo,
        migrationRunner: () async {
          calls++;
          return const MigrationResult(migrated: 3, unparsedIngredientLines: 2);
        },
      );
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.runMigrationIfNeeded();
      await p.runMigrationIfNeeded();
      expect(calls, 1);
      expect(p.lastMigration!.migrated, 3);
      expect(p.lastMigration!.unparsedIngredientLines, 2);

      p.clearMigrationNotice();
      expect(p.lastMigration, isNull);
    });

    test('không có gì để chuyển → không có thông báo', () async {
      final p = RecipeListProvider(repository: repo, migrationRunner: () async => const MigrationResult());
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.runMigrationIfNeeded();
      expect(p.lastMigration, isNull);
    });

    test('lỗi (ví dụ mất mạng) không chặn người dùng và được thử lại lần sau', () async {
      var calls = 0;
      final p = RecipeListProvider(
        repository: repo,
        migrationRunner: () async {
          calls++;
          if (calls == 1) throw Exception('mất mạng');
          return const MigrationResult(migrated: 1);
        },
      );
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.runMigrationIfNeeded();
      expect(p.lastMigration, isNull);
      await p.runMigrationIfNeeded();
      expect(calls, 2);
      expect(p.lastMigration!.migrated, 1);
    });

    test('đổi tài khoản thì được chuyển lại cho tài khoản mới', () async {
      final seen = <int>[];
      var n = 0;
      final p = RecipeListProvider(
        repository: repo,
        migrationRunner: () async {
          seen.add(++n);
          return MigrationResult(migrated: n);
        },
      );
      addTearDown(p.dispose);
      await pumpEventQueue();
      await p.runMigrationIfNeeded();
      expect(p.lastMigration!.migrated, 1);

      await auth.signOut();
      await pumpEventQueue();
      expect(p.lastMigration, isNull); // kết quả của tài khoản trước bị xoá
    });
  });

  group('tìm kiếm và lọc theo thẻ', () {
    Recipe tagged(String title, List<String> tags, {List<String> ingredients = const ['x']}) => Recipe(
          id: '',
          ownerId: 'x',
          title: title,
          baseServings: 2,
          ingredients: [for (var i = 0; i < ingredients.length; i++) Ingredient(id: 'i$i', name: ingredients[i])],
          steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
          tags: tags,
        );

    Future<RecipeListProvider> loaded() async {
      await repo.create(tagged('Gà rán', ['món sinh viên', 'nhanh'], ingredients: ['đùi gà']));
      await repo.create(tagged('Thịt kho', ['món sinh viên'], ingredients: ['thịt ba chỉ']));
      await repo.create(tagged('Canh chua', ['ăn kiêng'], ingredients: ['cá lóc']));
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      return p;
    }

    test('mặc định: không lọc, trả về toàn bộ', () async {
      final p = await loaded();
      expect(p.hasActiveFilters, isFalse);
      expect(p.filteredRecipes, hasLength(3));
      expect(p.isFilteredEmpty, isFalse);
    });

    test('setQuery lọc không dấu theo tên món và nguyên liệu, và thông báo cho giao diện', () async {
      final p = await loaded();
      var notified = 0;
      p.addListener(() => notified++);
      p.setQuery('ga');
      expect(p.query, 'ga');
      expect(p.filteredRecipes.map((r) => r.title), ['Gà rán']);
      expect(p.hasActiveFilters, isTrue);
      expect(notified, 1);

      p.setQuery('ba chi');
      expect(p.filteredRecipes.map((r) => r.title), ['Thịt kho']);
    });

    test('toggleTag chọn rồi bỏ chọn', () async {
      final p = await loaded();
      p.toggleTag('mon sinh vien');
      expect(p.selectedTags, {'mon sinh vien'});
      expect(p.filteredRecipes.map((r) => r.title).toSet(), {'Gà rán', 'Thịt kho'});

      p.toggleTag('mon sinh vien');
      expect(p.selectedTags, isEmpty);
      expect(p.filteredRecipes, hasLength(3));
    });

    test('nhiều thẻ: phải có đủ', () async {
      final p = await loaded();
      p.toggleTag('mon sinh vien');
      p.toggleTag('nhanh');
      expect(p.filteredRecipes.map((r) => r.title), ['Gà rán']);
    });

    test('từ khoá + thẻ kết hợp', () async {
      final p = await loaded();
      p.toggleTag('mon sinh vien');
      p.setQuery('thit');
      expect(p.filteredRecipes.map((r) => r.title), ['Thịt kho']);
    });

    test('không có kết quả: isFilteredEmpty = true (khác với chưa có công thức nào)', () async {
      final p = await loaded();
      p.setQuery('sushi');
      expect(p.filteredRecipes, isEmpty);
      expect(p.isFilteredEmpty, isTrue);
      expect(p.recipes, hasLength(3));
    });

    test('chưa có công thức nào thì không phải "lọc ra rỗng"', () async {
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();
      p.setQuery('abc');
      expect(p.isFilteredEmpty, isFalse);
    });

    test('clearFilters xoá cả từ khoá lẫn thẻ', () async {
      final p = await loaded();
      p.setQuery('ga');
      p.toggleTag('nhanh');
      p.clearFilters();
      expect(p.query, '');
      expect(p.selectedTags, isEmpty);
      expect(p.hasActiveFilters, isFalse);
      expect(p.filteredRecipes, hasLength(3));
    });

    test('availableTags đếm theo công thức, nhiều nhất trước', () async {
      final p = await loaded();
      expect(p.availableTags.map((t) => t.label), ['món sinh viên', 'ăn kiêng', 'nhanh']);
      expect(p.availableTags.map((t) => t.count), [2, 1, 1]);
    });

    test('từ khoá chỉ có khoảng trắng không tính là đang lọc', () async {
      final p = await loaded();
      p.setQuery('   ');
      expect(p.hasActiveFilters, isFalse);
      expect(p.filteredRecipes, hasLength(3));
    });

    test('xoá công thức cuối cùng của một thẻ thì thẻ đó tự bỏ chọn', () async {
      final p = await loaded();
      p.toggleTag('an kieng');
      expect(p.filteredRecipes.map((r) => r.title), ['Canh chua']);

      final soup = p.recipes.firstWhere((r) => r.title == 'Canh chua');
      await p.delete(soup.id);
      await pumpEventQueue();
      expect(p.selectedTags, isEmpty);
      expect(p.filteredRecipes, hasLength(2)); // không bị kẹt ở danh sách rỗng
    });

    test('đăng xuất thì bộ lọc được đặt lại', () async {
      final p = await loaded();
      p.setQuery('ga');
      p.toggleTag('nhanh');
      await auth.signOut();
      await pumpEventQueue();
      expect(p.query, '');
      expect(p.selectedTags, isEmpty);
    });

    test('công thức mới tạo xuất hiện trong kết quả lọc đang áp dụng', () async {
      final p = await loaded();
      p.toggleTag('nhanh');
      expect(p.filteredRecipes, hasLength(1));
      await repo.create(tagged('Mì tôm', ['nhanh']));
      await pumpEventQueue();
      expect(p.filteredRecipes.map((r) => r.title).toSet(), {'Gà rán', 'Mì tôm'});
    });
  });
}
