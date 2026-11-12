/// Dữ liệu công thức không hợp lệ. [errors] là các mã lỗi từ `Recipe.validate()`
/// (ví dụ `title_required`, `ingredients[1].name_invalid`).
class RecipeValidationException implements Exception {
  RecipeValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => 'RecipeValidationException($errors)';
}

/// Công thức không tồn tại (hoặc không thuộc người dùng hiện tại).
class RecipeNotFoundException implements Exception {
  RecipeNotFoundException(this.id);

  final String id;

  @override
  String toString() => 'RecipeNotFoundException($id)';
}

/// Thao tác cần có mạng (ví dụ tải ảnh lên) nhưng thiết bị đang offline.
class OfflineException implements Exception {
  OfflineException([this.message = 'Cần có kết nối mạng cho thao tác này']);

  final String message;

  @override
  String toString() => 'OfflineException($message)';
}

/// Chưa đăng nhập.
class NotSignedInException implements Exception {
  @override
  String toString() => 'NotSignedInException';
}
