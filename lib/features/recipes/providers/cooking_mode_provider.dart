import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/cooking_session_store.dart';
import '../data/screen_awake.dart';
import '../data/timer_notifier.dart';
import '../models/cooking_session.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';

export '../models/cooking_session.dart' show StepTimer;

enum TimerState { idle, running, paused, finished }

/// Trạng thái của một lần nấu: bước hiện tại, khẩu phần, các hẹn giờ.
///
/// Nguyên tắc về thời gian: mọi hẹn giờ lưu **thời điểm kết thúc tuyệt đối**
/// (`endAt`). `Timer.periodic` chỉ để làm mới giao diện mỗi giây; số giây còn
/// lại luôn là `endAt - now`, nên đúng cả khi hệ điều hành đóng băng ứng dụng.
/// Báo khi ở nền do thông báo đã lên lịch sẵn đảm nhiệm; thoát chế độ nấu hoặc
/// đưa ứng dụng xuống nền KHÔNG huỷ các thông báo đó.
class CookingModeProvider extends ChangeNotifier {
  CookingModeProvider({
    required this.recipe,
    required CookingSessionStore store,
    required TimerNotifier notifier,
    required ScreenAwake awake,
    required this.timerTitle,
    required this.timerBody,
    DateTime Function()? now,
    this.tickInterval = const Duration(seconds: 1),
    int? initialServings,
  })  : _store = store,
        _notifier = notifier,
        _awake = awake,
        _now = now ?? DateTime.now,
        // Khẩu phần người dùng đã chọn ở màn hình chi tiết; không hợp lệ thì dùng khẩu phần gốc.
        _servings = (initialServings != null && initialServings >= 1 && initialServings <= maxServings)
            ? initialServings
            : recipe.baseServings,
        _startedAt = (now ?? DateTime.now)();

  final Recipe recipe;
  final CookingSessionStore _store;
  final TimerNotifier _notifier;
  final ScreenAwake _awake;
  final DateTime Function() _now;
  final Duration tickInterval;

  /// Nội dung thông báo hết giờ của một bước (do giao diện cung cấp, đã dịch).
  final String Function(RecipeStep step) timerTitle;
  final String Function(RecipeStep step) timerBody;

  static const int maxServings = 100;

  int _stepIndex = 0;
  int _servings;
  DateTime _startedAt;
  final Map<String, StepTimer> _timers = {};
  final Set<String> _alarms = {};
  final Set<String> _handled = {};
  final Set<String> _starting = {};

  bool _active = false;
  bool _finished = false;
  bool _foreground = true;
  bool _disposed = false;
  bool _permissionAsked = false;
  bool _permissionGranted = false;
  bool _notificationsDenied = false;
  Timer? _ticker;
  Future<void> _persistChain = Future.value();

  // ------------------------------------------------------------------ trạng thái

  int get stepIndex => _stepIndex;
  int get stepCount => recipe.steps.length;
  RecipeStep get currentStep => recipe.steps[_stepIndex];
  bool get isLastStep => _stepIndex >= stepCount - 1;
  bool get canGoPrevious => _stepIndex > 0;
  int get servings => _servings;
  bool get isActive => _active;
  bool get isFinished => _finished;

  /// Người dùng từ chối quyền thông báo: hẹn giờ vẫn chạy và báo khi app đang mở.
  bool get notificationsDenied => _notificationsDenied;

  /// Các bước vừa hết giờ mà người dùng chưa xác nhận.
  Set<String> get alarms => Set.unmodifiable(_alarms);

  /// Mọi hẹn giờ (đang chạy, tạm dừng, đã hết giờ) theo thứ tự bước.
  List<StepTimer> get activeTimers {
    final order = {for (var i = 0; i < recipe.steps.length; i++) recipe.steps[i].id: i};
    return _timers.values.toList()..sort((a, b) => order[a.stepId]!.compareTo(order[b.stepId]!));
  }

  TimerState stateOf(String stepId) {
    final t = _timers[stepId];
    if (t == null) return TimerState.idle;
    if (t.isPaused) return TimerState.paused;
    if (t.isRunning) return t.isFinished(_now()) ? TimerState.finished : TimerState.running;
    return TimerState.idle;
  }

  /// Số giây còn lại của hẹn giờ ở [stepId]; chưa chạy thì là thời lượng gốc.
  int remainingSec(String stepId) {
    final t = _timers[stepId];
    if (t != null) return t.remainingSec(_now());
    return _stepById(stepId)?.durationSec ?? 0;
  }

  // ----------------------------------------------------------------- bắt đầu/kết thúc

  /// Phiên nấu dở của công thức này, nếu có và đáng để hỏi tiếp tục.
  Future<CookingSession?> loadSavedSession() async {
    final saved = await _store.load(recipe.id);
    return (saved != null && saved.hasProgress) ? saved : null;
  }

  /// Bắt đầu nấu mới, hoặc tiếp tục từ [resumeFrom]. Bật giữ màn hình sáng.
  Future<void> begin({CookingSession? resumeFrom}) async {
    final s = resumeFrom;
    if (s != null) {
      _stepIndex = s.stepIndex.clamp(0, stepCount - 1);
      _servings = (s.servings >= 1 && s.servings <= maxServings) ? s.servings : recipe.baseServings;
      _startedAt = s.startedAt;
      for (final t in s.timers) {
        final step = _stepById(t.stepId);
        if (step != null && step.durationSec != null) _timers[t.stepId] = t;
      }
    }
    _active = true;
    _finished = false;
    await _awake.enable();
    _startTicker();
    _checkFinished();
    _notify();
  }

  /// Bỏ phiên dở cũ: huỷ các thông báo đã lên lịch và xoá phiên.
  Future<void> discardSaved(CookingSession saved) async {
    for (final t in saved.timers) {
      await _cancelNotification(t.notificationId);
    }
    await _store.clear(recipe.id);
  }

  /// Hoàn thành: huỷ mọi hẹn giờ, xoá phiên, tắt giữ màn hình sáng.
  Future<void> finish() async {
    if (_finished) return;
    _active = false;
    _finished = true;
    _stopTicker();
    // Nấu xong là màn hình được phép tắt ngay, không chờ các thao tác lưu trữ.
    unawaited(_awake.disable());
    final ids = _timers.values.map((t) => t.notificationId).whereType<int>().toList();
    _timers.clear();
    _alarms.clear();
    _notify();
    for (final id in ids) {
      await _cancelNotification(id);
    }
    await _persistChain;
    await _store.clear(recipe.id);
  }

  // ------------------------------------------------------------------ điều hướng

  void next() {
    if (!_active) return;
    if (isLastStep) {
      unawaited(finish());
    } else {
      _setStep(_stepIndex + 1);
    }
  }

  void previous() {
    if (!_active || !canGoPrevious) return;
    _setStep(_stepIndex - 1);
  }

  void goTo(int index) {
    if (!_active) return;
    _setStep(index.clamp(0, stepCount - 1));
  }

  void _setStep(int index) {
    if (index == _stepIndex) return;
    _stepIndex = index;
    _persist();
    _notify();
  }

  /// Đổi số người ăn khi nấu. Trả về `false` (giữ giá trị cũ) nếu không hợp lệ.
  bool setServings(int value) {
    if (value < 1 || value > maxServings) return false;
    if (value == _servings) return true;
    _servings = value;
    _persist();
    _notify();
    return true;
  }

  // ---------------------------------------------------------------------- hẹn giờ

  /// Bắt đầu hoặc tiếp tục hẹn giờ của một bước (cần bước có `durationSec`).
  Future<void> startTimer(String stepId) async {
    if (!_active) return;
    final step = _stepById(stepId);
    final total = step?.durationSec;
    if (step == null || total == null || total <= 0) return;
    if (!_starting.add(stepId)) return;
    try {
      final now = _now();
      final existing = _timers[stepId];
      if (existing != null && existing.isRunning && !existing.isFinished(now)) return;
      final remaining = (existing != null && existing.isPaused) ? existing.pausedRemainingSec! : total;
      final endAt = now.add(Duration(seconds: remaining));

      int? notificationId;
      if (!_permissionAsked) {
        _permissionAsked = true;
        _permissionGranted = await _safePermission();
        _notificationsDenied = !_permissionGranted;
      }
      if (_permissionGranted) {
        try {
          notificationId = await _notifier.schedule(
            endAt: endAt,
            title: timerTitle(step),
            body: timerBody(step),
          );
        } catch (e) {
          debugPrint('Không lên lịch được thông báo hết giờ: $e');
        }
      }

      _timers[stepId] = StepTimer(
        stepId: stepId,
        totalSec: total,
        endAt: endAt,
        notificationId: notificationId,
      );
      _alarms.remove(stepId);
      _handled.remove(stepId);
      _persist();
      _notify();
    } finally {
      _starting.remove(stepId);
    }
  }

  /// Tạm dừng: huỷ thông báo và giữ số giây còn lại.
  Future<void> pauseTimer(String stepId) async {
    final t = _timers[stepId];
    final now = _now();
    if (t == null || !t.isRunning || t.isFinished(now)) return;
    final remaining = t.remainingSec(now);
    _timers[stepId] = StepTimer(stepId: stepId, totalSec: t.totalSec, pausedRemainingSec: remaining);
    _persist();
    _notify();
    await _cancelNotification(t.notificationId);
  }

  /// Đặt lại: huỷ thông báo (nếu còn) và về trạng thái chưa chạy.
  Future<void> resetTimer(String stepId) async {
    final t = _timers.remove(stepId);
    if (t == null) return;
    _alarms.remove(stepId);
    _handled.remove(stepId);
    _persist();
    _notify();
    await _cancelNotification(t.notificationId);
  }

  /// Người dùng đã thấy cảnh báo hết giờ; hẹn giờ vẫn ở trạng thái "hết giờ".
  void acknowledgeAlarm(String stepId) {
    if (_alarms.remove(stepId)) _notify();
  }

  // ------------------------------------------------------------------ vòng đời

  /// Giao diện báo ứng dụng đang ở trước hay ở nền. Ở nền: tắt giữ màn hình sáng
  /// và dừng làm mới mỗi giây, nhưng KHÔNG huỷ thông báo đã lên lịch.
  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!_active) return;
    if (foreground) {
      unawaited(_awake.enable());
      _startTicker();
      _checkFinished();
      _notify();
    } else {
      _stopTicker();
      unawaited(_awake.disable());
    }
  }

  /// Một nhịp làm mới (mỗi giây khi đang mở app). Công khai để test gọi trực tiếp.
  @visibleForTesting
  void onTick() {
    if (_disposed || !_active) return;
    final changed = _checkFinished();
    if (changed || _timers.values.any((t) => t.isRunning)) _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    // Chỉ tắt giữ màn hình sáng. Không huỷ thông báo: hẹn giờ phải báo đúng lúc
    // dù người dùng đã thoát chế độ nấu.
    unawaited(_awake.disable());
    super.dispose();
  }

  // ------------------------------------------------------------------- nội bộ

  RecipeStep? _stepById(String id) {
    for (final s in recipe.steps) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Phát hiện hẹn giờ vừa hết. Chỉ khi đang mở app mới báo trong app và huỷ
  /// thông báo (để khỏi báo hai lần); ở nền thì để thông báo đã lên lịch lo.
  bool _checkFinished() {
    if (!_foreground) return false;
    final now = _now();
    var changed = false;
    for (final t in _timers.values.toList()) {
      if (!t.isFinished(now) || _handled.contains(t.stepId)) continue;
      _handled.add(t.stepId);
      _alarms.add(t.stepId);
      changed = true;
      final id = t.notificationId;
      if (id != null) {
        _timers[t.stepId] = StepTimer(stepId: t.stepId, totalSec: t.totalSec, endAt: t.endAt);
        unawaited(_cancelNotification(id));
      }
    }
    if (changed) _persist();
    return changed;
  }

  Future<bool> _safePermission() async {
    try {
      return await _notifier.requestPermission();
    } catch (e) {
      debugPrint('Không xin được quyền thông báo: $e');
      return false;
    }
  }

  Future<void> _cancelNotification(int? id) async {
    if (id == null) return;
    try {
      await _notifier.cancel(id);
    } catch (e) {
      debugPrint('Không huỷ được thông báo $id: $e');
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Lưu phiên theo thứ tự (hàng đợi) để lần ghi cũ không đè lần ghi mới, và
  /// không ghi lại sau khi đã hoàn thành.
  void _persist() {
    if (_finished) return;
    final session = CookingSession(
      recipeId: recipe.id,
      stepIndex: _stepIndex,
      servings: _servings,
      startedAt: _startedAt,
      timers: activeTimers,
    );
    _persistChain = _persistChain.then((_) async {
      if (_finished) return;
      try {
        await _store.save(session);
      } catch (e) {
        debugPrint('Không lưu được phiên nấu: $e');
      }
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}
