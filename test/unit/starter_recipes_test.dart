import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/domain/starter_recipes.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var n = 0;
  String seq() => 'id${n++}';

  group('bộ công thức mẫu', () {
    final recipes = buildStarterRecipes(seq);

    test('có đủ số món, tên không trùng', () {
      expect(recipes, hasLength(starterRecipeCount));
      expect(starterRecipeCount, greaterThanOrEqualTo(10));
      expect(recipes.map((r) => r.title).toSet(), hasLength(recipes.length));
    });

    test('mọi món đều hợp lệ theo luật của công thức', () {
      for (final r in recipes) {
        expect(r.validate(), isEmpty, reason: r.title);
      }
    });

    test('bước đánh số liên tục từ 1; ID nguyên liệu/bước không trùng', () {
      final ids = <String>{};
      for (final r in recipes) {
        expect(r.steps.map((s) => s.order), [for (var i = 1; i <= r.steps.length; i++) i], reason: r.title);
        for (final id in [...r.ingredients.map((i) => i.id), ...r.steps.map((s) => s.id)]) {
          expect(ids.add(id), isTrue, reason: 'trùng $id');
        }
      }
    });

    test('mỗi món có giá và kcal để thống kê, ít nhất một bước có hẹn giờ', () {
      for (final r in recipes) {
        expect(r.ingredients.any((i) => i.price != null && i.kcal != null), isTrue, reason: r.title);
        expect(r.steps.any((s) => s.durationSec != null), isTrue, reason: r.title);
      }
    });
  });

  group('RecipeListProvider.addStarterRecipes', () {
    late FirestoreRecipeRepository repo;

    setUp(() {
      repo = FirestoreRecipeRepository(
        firestore: FakeFirebaseFirestore(),
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')),
      );
    });

    test('thêm toàn bộ, bỏ món trùng tên (không phân biệt dấu/hoa thường), lần sau không thêm gì', () async {
      await repo.create(Recipe(
        id: '',
        ownerId: 'alice',
        title: 'RAU MUONG XAO TOI',
        baseServings: 1,
        ingredients: const [Ingredient(id: 'i', name: 'rau')],
        steps: const [RecipeStep(id: 's', order: 1, text: 'xào')],
      ));
      final p = RecipeListProvider(repository: repo);
      addTearDown(p.dispose);
      await pumpEventQueue();

      expect(await p.addStarterRecipes(newId: seq), starterRecipeCount - 1);
      await pumpEventQueue();
      expect(p.recipes, hasLength(starterRecipeCount));
      expect(p.recipes.every((r) => r.ownerId == 'alice'), isTrue);

      expect(await p.addStarterRecipes(newId: seq), 0);
    });
  });
}
