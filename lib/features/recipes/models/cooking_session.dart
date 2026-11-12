const Object _unset = Object();

/// Hẹn giờ của một bước nấu.
///
/// Trạng thái được suy ra từ dữ liệu, không lưu cờ riêng:
/// - đang chạy: [endAt] != null (thời điểm kết thúc **tuyệt đối**);
/// - tạm dừng: [endAt] == null và [pausedRemainingSec] != null;
/// - chưa chạy: cả hai đều null.
///
/// Dùng thời điểm tuyệt đối để số giây còn lại luôn đúng dù ứng dụng bị hệ
/// điều hành đóng băng ở nền (bộ đếm Dart không chạy khi đó).
class StepTimer {
  const StepTimer({
    required this.stepId,
    required this.totalSec,
    this.endAt,
    this.pausedRemainingSec,
    this.notificationId,
  });

  final String stepId;

  /// Thời lượng gốc của bước (giây).
  final int totalSec;

  final DateTime? endAt;
  final int? pausedRemainingSec;

  /// Mã thông báo đã lên lịch cho lần chạy này (nếu có), để huỷ khi cần.
  final int? notificationId;

  bool get isRunning => endAt != null;
  bool get isPaused => endAt == null && pausedRemainingSec != null;

  /// Số giây còn lại tại thời điểm [now], làm tròn lên (còn 0,3 giây vẫn hiện 1).
  int remainingSec(DateTime now) {
    final end = endAt;
    if (end != null) {
      final ms = end.difference(now).inMilliseconds;
      return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
    }
    return pausedRemainingSec ?? totalSec;
  }

  /// Đang chạy và đã tới hoặc qua [endAt].
  bool isFinished(DateTime now) => endAt != null && !endAt!.isAfter(now);

  Map<String, dynamic> toJson() => {
        'stepId': stepId,
        'totalSec': totalSec,
        'endAt': endAt?.millisecondsSinceEpoch,
        'pausedRemainingSec': pausedRemainingSec,
        'notificationId': notificationId,
      };

  factory StepTimer.fromJson(Map<String, dynamic> json) {
    final endMs = json['endAt'] as int?;
    return StepTimer(
      stepId: json['stepId'] as String,
      totalSec: json['totalSec'] as int,
      endAt: endMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endMs),
      pausedRemainingSec: json['pausedRemainingSec'] as int?,
      notificationId: json['notificationId'] as int?,
    );
  }
}

/// Trạng thái nấu dở của một công thức, chỉ lưu cục bộ trên máy
/// (xem data-model.md, mục CookingSession).
class CookingSession {
  const CookingSession({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.startedAt,
    this.timers = const [],
  });

  final String recipeId;

  /// Chỉ số bước hiện tại, bắt đầu từ 0.
  final int stepIndex;

  /// Số người ăn đang chọn khi nấu.
  final int servings;

  final DateTime startedAt;
  final List<StepTimer> timers;

  /// Có gì đáng để hỏi "tiếp tục hay bắt đầu lại" không.
  bool get hasProgress => stepIndex > 0 || timers.isNotEmpty;

  CookingSession copyWith({
    int? stepIndex,
    int? servings,
    DateTime? startedAt,
    Object? timers = _unset,
  }) {
    return CookingSession(
      recipeId: recipeId,
      stepIndex: stepIndex ?? this.stepIndex,
      servings: servings ?? this.servings,
      startedAt: startedAt ?? this.startedAt,
      timers: identical(timers, _unset) ? this.timers : timers as List<StepTimer>,
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'recipeId': recipeId,
        'stepIndex': stepIndex,
        'servings': servings,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'timers': timers.map((t) => t.toJson()).toList(),
      };

  /// Ném lỗi nếu dữ liệu sai cấu trúc; kho lưu trữ sẽ bắt và bỏ phiên hỏng.
  factory CookingSession.fromJson(Map<String, dynamic> json) {
    return CookingSession(
      recipeId: json['recipeId'] as String,
      stepIndex: json['stepIndex'] as int,
      servings: json['servings'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int),
      timers: ((json['timers'] as List?) ?? const [])
          .map((e) => StepTimer.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
