import 'package:btl_ltdd/features/planner/domain/week.dart';
import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tuần', () {
    test('thứ 2 của tuần, kể cả khi đang là chủ nhật hoặc thứ 2', () {
      expect(weekStartOf(DateTime(2026, 11, 14, 23, 59)), DateTime(2026, 11, 9)); // thứ 7
      expect(weekStartOf(DateTime(2026, 11, 15)), DateTime(2026, 11, 9)); // chủ nhật
      expect(weekStartOf(DateTime(2026, 11, 16, 0, 1)), DateTime(2026, 11, 16)); // thứ 2
    });

    test('qua tháng, qua năm', () {
      expect(weekStartOf(DateTime(2027, 1, 2)), DateTime(2026, 12, 28));
      expect(addWeeks(DateTime(2026, 12, 28), 1), DateTime(2027, 1, 4));
      expect(addWeeks(DateTime(2026, 11, 2), -1), DateTime(2026, 10, 26));
    });

    test('khoá tuần dạng yyyy-MM-dd', () {
      expect(weekKey(DateTime(2026, 3, 2)), '2026-03-02');
    });

    test('vị trí ngày trong tuần', () {
      final w = DateTime(2026, 11, 9);
      expect(dayIndexInWeek(w, DateTime(2026, 11, 9, 8)), 0);
      expect(dayIndexInWeek(w, DateTime(2026, 11, 15, 22)), 6);
      expect(dayIndexInWeek(w, DateTime(2026, 11, 16)), -1);
      expect(dayOfWeek(w, 3), DateTime(2026, 11, 12));
    });
  });

  group('WeekPlan', () {
    final w = DateTime(2026, 11, 9);
    const e = MealEntry(id: 'e1', day: 2, slot: MealSlot.lunch, recipeId: 'r1', title: 'Phở', servings: 3);

    test('toMap / fromMap giữ nguyên dữ liệu', () {
      final map = WeekPlan(weekStart: w, entries: const [e]).toMap(ownerId: 'u', weekKey: '2026-11-09');
      expect(map['ownerId'], 'u');
      expect(map['weekStart'], '2026-11-09');
      final back = WeekPlan.fromMap(w, map);
      expect(back.entries.single.title, 'Phở');
      expect(back.entries.single.slot, MealSlot.lunch);
      expect(back.entriesFor(2, MealSlot.lunch).length, 1);
      expect(back.entriesFor(2, MealSlot.dinner), isEmpty);
    });

    test('mục hỏng bị bỏ qua, không làm hỏng cả tuần', () {
      final back = WeekPlan.fromMap(w, {
        'entries': [
          e.toMap(),
          {'day': 9, 'slot': 'lunch', 'recipeId': 'x'},
          {'day': 1, 'slot': 'brunch', 'recipeId': 'x'},
          'rác',
          {'day': 1, 'slot': 'dinner', 'recipeId': 'y', 'servings': -2},
        ],
      });
      expect(back.entries.length, 2);
      expect(back.entries.last.servings, 1);
    });

    test('tài liệu chưa tồn tại: tuần trống', () {
      expect(WeekPlan.fromMap(w, null).entries, isEmpty);
    });
  });

  group('ShoppingState', () {
    test('toMap / fromMap', () {
      const s = ShoppingState(checked: {'b|g', 'a|quả'}, extras: [ShoppingExtra(id: 'x', name: 'Giấy bạc', quantity: 1, unit: 'cuộn')]);
      final map = s.toMap(ownerId: 'u', weekKey: '2026-11-09');
      expect(map['checked'], ['a|quả', 'b|g']);
      final back = ShoppingState.fromMap(map);
      expect(back.checked, {'a|quả', 'b|g'});
      expect(back.extras.single.unit, 'cuộn');
    });

    test('dữ liệu hỏng hoặc thiếu: trạng thái trống', () {
      final back = ShoppingState.fromMap({'checked': 'x', 'extras': [1, {'id': 'a'}]});
      expect(back.checked, isEmpty);
      expect(back.extras, isEmpty);
    });
  });
}
