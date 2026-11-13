import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';
import 'package:btl_ltdd/features/planner/providers/meal_plan_provider.dart';
import 'package:btl_ltdd/features/planner/providers/shopping_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/planner_fakes.dart';

void main() {
  // Thứ 4, 11/11/2026 → tuần bắt đầu thứ 2, 9/11.
  final now = DateTime(2026, 11, 11, 12);
  final thisWeek = DateTime(2026, 11, 9);

  group('MealPlanProvider', () {
    late FakePlannerRepository repo;
    late MealPlanProvider p;

    setUp(() async {
      repo = FakePlannerRepository();
      p = MealPlanProvider(repository: repo, now: () => now);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() => p.dispose());

    test('bắt đầu ở tuần hiện tại', () {
      expect(p.weekStart, thisWeek);
      expect(p.isThisWeek, isTrue);
    });

    test('thêm món, lưu vào repository, hiện ở "hôm nay" khi đúng ngày', () async {
      expect(await p.add(day: 2, slot: MealSlot.dinner, recipeId: 'r', title: 'Phở', servings: 2), isNull);
      expect(repo.weeks[thisWeek]!.entries.single.title, 'Phở');
      expect(p.today.single.title, 'Phở');
      await p.add(day: 3, slot: MealSlot.lunch, recipeId: 'r2', title: 'Cơm', servings: 1);
      expect(p.today.length, 1, reason: 'món thứ 5 không phải hôm nay');
    });

    test('"hôm nay" xếp theo bữa sáng, trưa, tối', () async {
      await p.add(day: 2, slot: MealSlot.dinner, recipeId: 'a', title: 'Tối', servings: 1);
      await p.add(day: 2, slot: MealSlot.breakfast, recipeId: 'b', title: 'Sáng', servings: 1);
      expect(p.today.map((e) => e.title), ['Sáng', 'Tối']);
    });

    test('xoá và đổi số người', () async {
      await p.add(day: 0, slot: MealSlot.lunch, recipeId: 'r', title: 'Phở', servings: 2);
      final id = p.plan.entries.single.id;
      await p.setServings(id, 5);
      expect(repo.weeks[thisWeek]!.entries.single.servings, 5);
      await p.remove(id);
      expect(repo.weeks[thisWeek]!.entries, isEmpty);
    });

    test('chuyển tuần: tuần sau trống, tuần này vẫn giữ cho trang chủ', () async {
      await p.add(day: 2, slot: MealSlot.dinner, recipeId: 'r', title: 'Phở', servings: 2);
      p.nextWeek();
      await Future<void>.delayed(Duration.zero);
      expect(p.weekStart, DateTime(2026, 11, 16));
      expect(p.plan.entries, isEmpty);
      expect(p.today.single.title, 'Phở');
      await p.add(day: 0, slot: MealSlot.lunch, recipeId: 'x', title: 'Cơm', servings: 1);
      expect(repo.weeks[DateTime(2026, 11, 16)]!.entries.single.title, 'Cơm');
      p.showWeek(0);
      expect(p.plan.entries.single.title, 'Phở');
    });

    test('thêm vào một tuần cụ thể (từ màn chi tiết công thức)', () async {
      await p.add(day: 1, slot: MealSlot.dinner, recipeId: 'r', title: 'Phở', servings: 2, weekStart: DateTime(2026, 11, 23));
      expect(repo.weeks[DateTime(2026, 11, 23)]!.entries.single.day, 1);
      expect(p.weekStart, DateTime(2026, 11, 23));
    });

    test('tối đa 63 món một tuần', () async {
      repo.weeks[thisWeek] = WeekPlan(weekStart: thisWeek, entries: [
        for (var i = 0; i < WeekPlan.maxEntries; i++)
          MealEntry(id: '$i', day: i % 7, slot: MealSlot.lunch, recipeId: 'r', title: 't', servings: 1),
      ]);
      final p2 = MealPlanProvider(repository: repo, now: () => now);
      await Future<void>.delayed(Duration.zero);
      expect(await p2.add(day: 0, slot: MealSlot.lunch, recipeId: 'r', title: 't', servings: 1), MealPlanError.full);
      p2.dispose();
    });

    test('lưu thất bại: hoàn tác trên giao diện và báo lỗi', () async {
      repo.failSaves = true;
      expect(await p.add(day: 0, slot: MealSlot.lunch, recipeId: 'r', title: 'Phở', servings: 2), MealPlanError.saveFailed);
      expect(p.plan.entries, isEmpty);
    });
  });

  group('ShoppingProvider', () {
    late FakePlannerRepository repo;
    late ShoppingProvider s;

    setUp(() async {
      repo = FakePlannerRepository();
      s = ShoppingProvider(repository: repo)..attachWeek(thisWeek);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() => s.dispose());

    test('tick / bỏ tick đã mua, lưu theo tuần', () async {
      await s.toggle('trung|quả');
      expect(repo.shopping[thisWeek]!.checked, {'trung|quả'});
      await s.toggle('trung|quả');
      expect(repo.shopping[thisWeek]!.checked, isEmpty);
    });

    test('thêm và xoá món lẻ; xoá món lẻ bỏ luôn dấu đã mua của nó', () async {
      expect(await s.addExtra(name: '  Giấy bạc ', quantity: 1, unit: 'cuộn'), isTrue);
      final id = s.state.extras.single.id;
      expect(s.state.extras.single.name, 'Giấy bạc');
      await s.toggle('extra:$id');
      await s.removeExtra(id);
      expect(s.state.extras, isEmpty);
      expect(s.state.checked, isEmpty);
    });

    test('tên trống không thêm được', () async {
      expect(await s.addExtra(name: '   '), isFalse);
    });

    test('đổi tuần: đọc trạng thái của tuần mới', () async {
      repo.shopping[DateTime(2026, 11, 16)] = const ShoppingState(checked: {'a|g'});
      s.attachWeek(DateTime(2026, 11, 16));
      await Future<void>.delayed(Duration.zero);
      expect(s.state.checked, {'a|g'});
    });

    test('bỏ đánh dấu tất cả; ẩn món đã mua', () async {
      await s.toggle('a|g');
      await s.toggle('b|g');
      await s.clearChecked();
      expect(s.state.checked, isEmpty);
      s.setHideChecked(true);
      expect(s.hideChecked, isTrue);
    });

    test('lưu thất bại: hoàn tác', () async {
      repo.failSaves = true;
      expect(await s.toggle('a|g'), isFalse);
      expect(s.state.checked, isEmpty);
    });
  });
}
