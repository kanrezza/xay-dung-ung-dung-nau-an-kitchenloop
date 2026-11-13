/// Tuần bắt đầu từ thứ 2 (thói quen Việt Nam). Mọi ngày ở đây chỉ có phần ngày, giờ địa phương.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Ngày thứ 2 của tuần chứa [d].
DateTime weekStartOf(DateTime d) {
  final day = dateOnly(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
}

/// Cộng/trừ [weeks] tuần (an toàn với giờ mùa hè vì tạo lại theo ngày).
DateTime addWeeks(DateTime weekStart, int weeks) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day + 7 * weeks);

/// Ngày thứ [index] (0 = thứ 2) của tuần.
DateTime dayOfWeek(DateTime weekStart, int index) => DateTime(weekStart.year, weekStart.month, weekStart.day + index);

/// "2026-11-09": dùng làm id tài liệu và trường `weekStart` trong Firestore.
String weekKey(DateTime weekStart) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${weekStart.year}-${two(weekStart.month)}-${two(weekStart.day)}';
}

/// Vị trí của [now] trong tuần bắt đầu [weekStart] (0..6), hoặc -1 nếu ở tuần khác.
int dayIndexInWeek(DateTime weekStart, DateTime now) {
  final diff = dateOnly(now).difference(weekStart).inHours;
  final days = (diff / 24).round();
  return days >= 0 && days < 7 ? days : -1;
}
