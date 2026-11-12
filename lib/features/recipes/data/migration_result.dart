/// Kết quả chuyển dữ liệu công thức cũ sang dạng có cấu trúc.
class MigrationResult {
  const MigrationResult({this.migrated = 0, this.unparsedIngredientLines = 0});

  /// Số công thức đã chuyển.
  final int migrated;

  /// Số dòng nguyên liệu không phân tích được (giữ nguyên văn làm tên).
  final int unparsedIngredientLines;

  bool get isEmpty => migrated == 0;
}
