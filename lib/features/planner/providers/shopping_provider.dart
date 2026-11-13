import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/planner_repository.dart';
import '../models/shopping_state.dart';

/// Trạng thái đi chợ (đã mua, món lẻ) của tuần đang xem trong thực đơn.
class ShoppingProvider extends ChangeNotifier {
  ShoppingProvider({required PlannerRepository repository}) : _repository = repository;

  final PlannerRepository _repository;
  final _random = Random();

  DateTime? _weekStart;
  ShoppingState _state = const ShoppingState();
  StreamSubscription<ShoppingState>? _sub;
  bool _hideChecked = false;

  ShoppingState get state => _state;
  bool get hideChecked => _hideChecked;
  DateTime? get weekStart => _weekStart;

  /// Gọi khi tuần đang xem thay đổi (ChangeNotifierProxyProvider).
  void attachWeek(DateTime weekStart) {
    if (weekStart == _weekStart) return;
    _weekStart = weekStart;
    _state = const ShoppingState();
    _sub?.cancel();
    _sub = _repository.watchShopping(weekStart).listen((s) {
      if (weekStart != _weekStart) return;
      _state = s;
      notifyListeners();
    }, onError: (_) {});
  }

  void setHideChecked(bool value) {
    _hideChecked = value;
    notifyListeners();
  }

  Future<bool> toggle(String key) {
    final checked = {..._state.checked};
    if (!checked.remove(key)) {
      if (checked.length >= ShoppingState.maxChecked) return Future.value(false);
      checked.add(key);
    }
    return _save(_state.copyWith(checked: checked));
  }

  Future<bool> addExtra({required String name, double? quantity, String? unit}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _state.extras.length >= ShoppingState.maxExtras) return Future.value(false);
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 16).toRadixString(36)}';
    final u = unit?.trim();
    return _save(_state.copyWith(extras: [
      ..._state.extras,
      ShoppingExtra(id: id, name: trimmed, quantity: quantity, unit: u == null || u.isEmpty ? null : u),
    ]));
  }

  Future<bool> removeExtra(String id) => _save(_state.copyWith(
        extras: _state.extras.where((e) => e.id != id).toList(),
        checked: {..._state.checked}..remove('extra:$id'),
      ));

  /// Bỏ đánh dấu tất cả (đi chợ tuần mới với cùng thực đơn).
  Future<bool> clearChecked() => _save(_state.copyWith(checked: {}));

  Future<bool> _save(ShoppingState next) async {
    final week = _weekStart;
    if (week == null) return false;
    final previous = _state;
    _state = next;
    notifyListeners();
    try {
      await _repository.saveShopping(week, next);
      return true;
    } catch (_) {
      if (week == _weekStart) {
        _state = previous;
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
