import 'package:btl_ltdd/features/planner/data/planner_repository.dart';
import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_exceptions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final week = DateTime(2026, 11, 9);
  late FakeFirebaseFirestore db;
  late FirestorePlannerRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestorePlannerRepository(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')),
      offlineGrace: const Duration(milliseconds: 50),
    );
  });

  test('id tài liệu gắn UID và thứ 2 của tuần', () {
    expect(FirestorePlannerRepository.docId('alice', week), 'alice_2026-11-09');
  });

  test('tuần chưa có tài liệu: tuần trống', () async {
    final plan = await repo.watchWeek(week).first;
    expect(plan.entries, isEmpty);
    expect(plan.weekStart, week);
  });

  test('lưu rồi đọc lại thực đơn; ghi đúng ownerId, weekStart', () async {
    const e = MealEntry(id: 'e', day: 1, slot: MealSlot.dinner, recipeId: 'r', title: 'Phở', servings: 2);
    await repo.saveWeek(WeekPlan(weekStart: week, entries: const [e]));
    final doc = await db.collection('weekPlans').doc('alice_2026-11-09').get();
    expect(doc.data()!['ownerId'], 'alice');
    expect(doc.data()!['weekStart'], '2026-11-09');
    final plan = await repo.watchWeek(week).first;
    expect(plan.entries.single.title, 'Phở');
  });

  test('trạng thái đi chợ: lưu, đọc lại', () async {
    await repo.saveShopping(week, const ShoppingState(checked: {'trung|quả'}, extras: [ShoppingExtra(id: 'x', name: 'Giấy bạc')]));
    final s = await repo.watchShopping(week).first;
    expect(s.checked, {'trung|quả'});
    expect(s.extras.single.name, 'Giấy bạc');
  });

  test('chưa đăng nhập: không ghi được', () async {
    final anon = FirestorePlannerRepository(firestore: db, auth: MockFirebaseAuth());
    expect(() => anon.saveWeek(WeekPlan(weekStart: week)), throwsA(isA<NotSignedInException>()));
    expect((await anon.watchWeek(week).first).entries, isEmpty);
  });
}
