import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe draft({String title = 'Thịt kho', String ownerId = 'ignored'}) => Recipe(
      id: '',
      ownerId: ownerId,
      title: title,
      baseServings: 2,
      ingredients: const [Ingredient(id: 'i1', name: 'thịt', quantity: 200, unit: 'g')],
      steps: const [RecipeStep(id: 's1', order: 1, text: 'Kho thịt')],
    );

FirestoreRecipeRepository repoFor(FakeFirebaseFirestore db, String uid, {bool signedIn = true}) {
  final auth = MockFirebaseAuth(signedIn: signedIn, mockUser: MockUser(uid: uid, email: '$uid@test.dev'));
  return FirestoreRecipeRepository(firestore: db, auth: auth);
}

void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth aliceAuth;
  late FirestoreRecipeRepository alice;

  setUp(() {
    db = FakeFirebaseFirestore();
    aliceAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice'));
    alice = FirestoreRecipeRepository(firestore: db, auth: aliceAuth);
  });

  group('create', () {
    test('đặt ownerId từ tài khoản đăng nhập, bỏ qua ownerId của bản nháp', () async {
      final id = await alice.create(draft(ownerId: 'someone-else'));
      final doc = await db.collection('recipes').doc(id).get();
      expect(doc.data()!['ownerId'], 'alice');
      expect(doc.data()!['schemaVersion'], 1);
      expect(doc.data()!['createdAt'], isNotNull);
      expect(doc.data()!['updatedAt'], isNotNull);
    });

    test('đọc lại được qua watchRecipe', () async {
      final id = await alice.create(draft());
      final r = await alice.watchRecipe(id).first;
      expect(r, isNotNull);
      expect(r!.title, 'Thịt kho');
      expect(r.ingredients.single.quantity, 200);
      expect(r.steps.single.text, 'Kho thịt');
    });

    test('dữ liệu sai → RecipeValidationException và không ghi gì', () async {
      expect(
        () => alice.create(draft(title: '')),
        throwsA(isA<RecipeValidationException>().having((e) => e.errors, 'errors', contains('title_required'))),
      );
      expect((await db.collection('recipes').get()).docs, isEmpty);
    });

    test('chưa đăng nhập → NotSignedInException', () async {
      final guest = repoFor(db, 'guest', signedIn: false);
      expect(() => guest.create(draft()), throwsA(isA<NotSignedInException>()));
    });
  });

  group('update', () {
    test('đổi nội dung nhưng giữ ownerId, createdAt và legacy', () async {
      final createdAt = DateTime.utc(2026, 1, 1);
      await db.collection('recipes').doc('r1').set({
        'ownerId': 'alice',
        'title': 'Cũ',
        'baseServings': 2,
        'ingredients': [const Ingredient(id: 'i', name: 'x').toMap()],
        'steps': [const RecipeStep(id: 's', order: 1, text: 'y').toMap()],
        'createdAt': Timestamp.fromDate(createdAt),
        'legacy': {'title': 'Cũ', 'ingredients': ['x'], 'instructions': 'y', 'sourceCollection': 'foods'},
        'schemaVersion': 1,
      });
      final current = (await alice.watchRecipe('r1').first)!;

      await alice.update(current.copyWith(title: 'Mới', ownerId: 'hacker', legacy: null));

      final data = (await db.collection('recipes').doc('r1').get()).data()!;
      expect(data['title'], 'Mới');
      expect(data['ownerId'], 'alice');
      expect((data['createdAt'] as Timestamp).toDate().isAtSameMomentAs(createdAt), isTrue);
      expect((data['legacy'] as Map)['title'], 'Cũ');
      expect(data['updatedAt'], isNotNull);
    });

    test('công thức không tồn tại → RecipeNotFoundException', () async {
      final ghost = draft().copyWith(id: 'khong-co');
      expect(() => alice.update(ghost), throwsA(isA<RecipeNotFoundException>()));
    });

    test('id rỗng → RecipeNotFoundException', () async {
      expect(() => alice.update(draft()), throwsA(isA<RecipeNotFoundException>()));
    });

    test('dữ liệu sai → RecipeValidationException', () async {
      final id = await alice.create(draft());
      final current = (await alice.watchRecipe(id).first)!;
      expect(
        () => alice.update(current.copyWith(ingredients: const [])),
        throwsA(isA<RecipeValidationException>()),
      );
    });
  });

  test('delete xoá công thức', () async {
    final id = await alice.create(draft());
    await alice.delete(id);
    expect((await db.collection('recipes').doc(id).get()).exists, isFalse);
    expect(await alice.watchRecipe(id).first, isNull);
  });

  group('watchMyRecipes', () {
    test('chỉ trả công thức của chính mình, mới sửa nhất trước', () async {
      Map<String, dynamic> raw(String owner, String title, DateTime t) => {
            'ownerId': owner,
            'title': title,
            'baseServings': 2,
            'ingredients': [const Ingredient(id: 'i', name: 'x').toMap()],
            'steps': [const RecipeStep(id: 's', order: 1, text: 'y').toMap()],
            'updatedAt': Timestamp.fromDate(t),
          };
      await db.collection('recipes').doc('a1').set(raw('alice', 'Cũ nhất', DateTime(2026, 1, 1)));
      await db.collection('recipes').doc('a2').set(raw('alice', 'Mới nhất', DateTime(2026, 3, 1)));
      await db.collection('recipes').doc('a3').set(raw('alice', 'Giữa', DateTime(2026, 2, 1)));
      await db.collection('recipes').doc('b1').set(raw('bob', 'Của bob', DateTime(2026, 4, 1)));

      final list = await alice.watchMyRecipes().first;
      expect(list.map((r) => r.title), ['Mới nhất', 'Giữa', 'Cũ nhất']);
    });

    test('tài khoản khác không thấy công thức của alice', () async {
      await alice.create(draft());
      final bob = repoFor(db, 'bob');
      expect(await bob.watchMyRecipes().first, isEmpty);
      expect(await alice.watchMyRecipes().first, hasLength(1));
    });

    test('đăng xuất → danh sách rỗng', () async {
      await alice.create(draft());
      final expectation = expectLater(
        alice.watchMyRecipes(),
        emitsInOrder([hasLength(1), isEmpty]),
      );
      await pumpEventQueue();
      await aliceAuth.signOut();
      await expectation;
    });

    test('công thức mới tạo xuất hiện trên luồng đang nghe', () async {
      final expectation = expectLater(
        alice.watchMyRecipes(),
        emitsInOrder([isEmpty, hasLength(1)]),
      );
      await pumpEventQueue();
      await alice.create(draft());
      await expectation;
    });
  });

  group('watchRecipe', () {
    test('trả null nếu không tồn tại', () async {
      expect(await alice.watchRecipe('khong-co').first, isNull);
    });

    test('trả null nếu thuộc người khác', () async {
      await db.collection('recipes').doc('rb').set({
        'ownerId': 'bob',
        'title': 'x',
        'baseServings': 2,
        'ingredients': [const Ingredient(id: 'i', name: 'x').toMap()],
        'steps': [const RecipeStep(id: 's', order: 1, text: 'y').toMap()],
      });
      expect(await alice.watchRecipe('rb').first, isNull);
    });
  });

  group('watchUserId', () {
    test('phát UID rồi null khi đăng xuất', () async {
      final expectation = expectLater(alice.watchUserId(), emitsInOrder(['alice', isNull]));
      await pumpEventQueue();
      await aliceAuth.signOut();
      await expectation;
    });
  });
}
