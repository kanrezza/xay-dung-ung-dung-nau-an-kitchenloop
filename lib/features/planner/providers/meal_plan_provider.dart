import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../domain/week.dart';
import '../models/week_plan.dart';

/// Lỗi khi thêm món vào thực đơn.
enum MealPlanError { full, saveFailed }

/// Trạng thái thực đơn: tuần đang xem (để lên kế hoạch) và tuần hiện tại (cho trang chủ).
class MealPlanProvider extends ChangeNotifier {
  MealPlanProvider({required PlannerRepository repository, DateTime Function()? now})
      : _repository = repository,
        _now = now ?? DateTime.now {
    _thisWeekStart = weekStartOf(_now());
    _weekStart = _thisWeekStart;
    _thisWeek = WeekPlan(weekStart: _thisWeekStart);
    _plan = _thisWeek;
    _thisWeekSub = _repository.watchWeek(_thisWeekStart).listen((p) {
      _thisWeek = p;
      if (_weekStart == _thisWeekStart) _plan = p;
      notifyListeners();
    }, onError: (_) {});
  }

  final PlannerRepository _repository;
  final DateTime Function() _now;
  final _random = Random();

  late DateTime _thisWeekStart;
  late DateTime _weekStart;
  late WeekPlan _thisWeek;
  late WeekPlan _plan;
  StreamSubscription<WeekPlan>? _thisWeekSub;
  StreamSubscription<WeekPlan>? _viewSub;

  DateTime get weekStart => _weekStart;
  DateTime get thisWeekStart => _thisWeekStart;
  bool get isThisWeek => _weekStart == _thisWeekStart;

  /// Thực đơn của tuần đang xem.
  WeekPlan get plan => _plan;

  /// Thực đơn tuần hiện tại (trang chủ: "hôm nay ăn gì").
  WeekPlan get thisWeek => _thisWeek;

  /// Món của hôm nay, theo thứ tự bữa.
  List<MealEntry> get today {
    final day = dayIndexInWeek(_thisWeekStart, _now());
    if (day < 0) return const [];
    return [for (final slot in MealSlot.values) ..._thisWeek.entriesFor(day, slot)];
  }

  /// Chuyển sang tuần cách tuần hiện tại [offset] tuần (0 = tuần này).
  void showWeek(int offset) => _setWeek(addWeeks(_thisWeekStart, offset));
  void nextWeek() => _setWeek(addWeeks(_weekStart, 1));
  void previousWeek() => _setWeek(addWeeks(_weekStart, -1));

  void _setWeek(DateTime start) {
    if (start == _weekStart) return;
    _weekStart = start;
    _viewSub?.cancel();
    _viewSub = null;
    if (start == _thisWeekStart) {
      _plan = _thisWeek;
    } else {
      _plan = WeekPlan(weekStart: start);
      _viewSub = _repository.watchWeek(start).listen((p) {
        if (p.weekStart != _weekStart) return;
        _plan = p;
        notifyListeners();
      }, onError: (_) {});
    }
    notifyListeners();
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 20).toRadixString(36)}';

  /// Thêm món vào tuần đang xem. Trả về lỗi hoặc `null` nếu thành công.
  Future<MealPlanError?> add({
    required int day,
    required MealSlot slot,
    required String recipeId,
    required String title,
    required int servings,
    DateTime? weekStart,
  }) async {
    final target = weekStart ?? _weekStart;
    if (target != _weekStart) _setWeek(target);
    if (_plan.entries.length >= WeekPlan.maxEntries) return MealPlanError.full;
    final entry = MealEntry(id: _newId(), day: day, slot: slot, recipeId: recipeId, title: title, servings: servings);
    return _save(_plan.copyWith(entries: [..._plan.entries, entry]));
  }

  Future<MealPlanError?> remove(String entryId) =>
      _save(_plan.copyWith(entries: _plan.entries.where((e) => e.id != entryId).toList()));

  Future<MealPlanError?> setServings(String entryId, int servings) => _save(_plan.copyWith(entries: [
        for (final e in _plan.entries)
          e.id == entryId
              ? MealEntry(id: e.id, day: e.day, slot: e.slot, recipeId: e.recipeId, title: e.title, servings: servings)
              : e,
      ]));

  Future<MealPlanError?> _save(WeekPlan next) async {
    final previous = _plan;
    // Cập nhật ngay trên giao diện; Firestore sẽ phát lại bản đã lưu.
    _plan = next;
    if (next.weekStart == _thisWeekStart) _thisWeek = next;
    notifyListeners();
    try {
      await _repository.saveWeek(next);
      return null;
    } catch (_) {
      _plan = previous;
      if (previous.weekStart == _thisWeekStart) _thisWeek = previous;
      notifyListeners();
      return MealPlanError.saveFailed;
    }
  }

  @override
  void dispose() {
    _thisWeekSub?.cancel();
    _viewSub?.cancel();
    super.dispose();
  }
}
