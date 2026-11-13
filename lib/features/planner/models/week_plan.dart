/// Bữa trong ngày.
enum MealSlot { breakfast, lunch, dinner }

MealSlot? mealSlotFromName(Object? name) {
  for (final s in MealSlot.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// Một món trong thực đơn tuần: công thức nào, ngày nào (0 = thứ 2), bữa nào, cho mấy người.
/// `title` được lưu kèm để vẫn hiện được tên khi công thức đã bị xoá khỏi sổ.
class MealEntry {
  const MealEntry({
    required this.id,
    required this.day,
    required this.slot,
    required this.recipeId,
    required this.title,
    required this.servings,
  });

  final String id;

  /// 0 = thứ 2 … 6 = chủ nhật.
  final int day;
  final MealSlot slot;
  final String recipeId;
  final String title;
  final int servings;

  Map<String, dynamic> toMap() => {
        'id': id,
        'day': day,
        'slot': slot.name,
        'recipeId': recipeId,
        'title': title,
        'servings': servings,
      };

  /// `null` nếu dữ liệu hỏng (bỏ qua mục đó thay vì làm hỏng cả tuần).
  static MealEntry? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final day = raw['day'];
    final slot = mealSlotFromName(raw['slot']);
    final servings = raw['servings'];
    final recipeId = raw['recipeId'];
    if (day is! int || day < 0 || day > 6 || slot == null || recipeId is! String) return null;
    return MealEntry(
      id: raw['id'] is String ? raw['id'] as String : '$day-${slot.name}-$recipeId',
      day: day,
      slot: slot,
      recipeId: recipeId,
      title: raw['title'] is String ? raw['title'] as String : '',
      servings: servings is int && servings > 0 ? servings : 1,
    );
  }
}

/// Thực đơn của một tuần (thứ 2 → chủ nhật).
class WeekPlan {
  const WeekPlan({required this.weekStart, this.entries = const [], this.isSyncing = false});

  /// Ngày thứ 2 đầu tuần (chỉ phần ngày, giờ địa phương).
  final DateTime weekStart;
  final List<MealEntry> entries;

  /// Có thay đổi chưa gửi lên máy chủ (đang offline).
  final bool isSyncing;

  /// Tối đa 9 món mỗi bữa × 21 bữa là quá nhiều; giữ giới hạn hợp lý, khớp firestore.rules.
  static const maxEntries = 63;

  List<MealEntry> entriesFor(int day, MealSlot slot) =>
      entries.where((e) => e.day == day && e.slot == slot).toList();

  WeekPlan copyWith({List<MealEntry>? entries}) => WeekPlan(weekStart: weekStart, entries: entries ?? this.entries);

  Map<String, dynamic> toMap({required String ownerId, required String weekKey}) => {
        'ownerId': ownerId,
        'weekStart': weekKey,
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory WeekPlan.fromMap(DateTime weekStart, Map<String, dynamic>? data, {bool isSyncing = false}) {
    final raw = data?['entries'];
    final entries = raw is List ? raw.map(MealEntry.fromMap).whereType<MealEntry>().toList() : <MealEntry>[];
    return WeekPlan(weekStart: weekStart, entries: entries, isSyncing: isSyncing);
  }
}
