import 'dart:async';

import 'package:btl_ltdd/features/planner/data/planner_repository.dart';
import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';

/// Repository giả trong bộ nhớ: phát lại dữ liệu đã lưu như Firestore.
class FakePlannerRepository implements PlannerRepository {
  final weeks = <DateTime, WeekPlan>{};
  final shopping = <DateTime, ShoppingState>{};
  final _weekCtrl = StreamController<WeekPlan>.broadcast();
  final _shopCtrl = StreamController<MapEntry<DateTime, ShoppingState>>.broadcast();
  bool failSaves = false;

  @override
  Stream<WeekPlan> watchWeek(DateTime weekStart) async* {
    yield weeks[weekStart] ?? WeekPlan(weekStart: weekStart);
    yield* _weekCtrl.stream.where((p) => p.weekStart == weekStart);
  }

  @override
  Future<void> saveWeek(WeekPlan plan) async {
    if (failSaves) throw Exception('offline');
    weeks[plan.weekStart] = plan;
    _weekCtrl.add(plan);
  }

  @override
  Stream<ShoppingState> watchShopping(DateTime weekStart) async* {
    yield shopping[weekStart] ?? const ShoppingState();
    yield* _shopCtrl.stream.where((e) => e.key == weekStart).map((e) => e.value);
  }

  @override
  Future<void> saveShopping(DateTime weekStart, ShoppingState state) async {
    if (failSaves) throw Exception('offline');
    shopping[weekStart] = state;
    _shopCtrl.add(MapEntry(weekStart, state));
  }
}
