/// Một tài khoản trong màn hình quản trị: chỉ các trường cần để nhận diện và khoá/mở.
/// Không có dữ liệu công thức (quản trị viên không xem được công thức của người dùng).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
    this.isLocked = false,
  });

  final String id;
  final String name;
  final String email;
  final DateTime? createdAt;
  final bool isLocked;

  /// Đọc từ hồ sơ `users/{id}` đã giải mã (Timestamp → DateTime). Hồ sơ của bản cũ có
  /// thể thiếu trường hoặc sai kiểu: dùng giá trị mặc định thay vì báo lỗi.
  factory AdminUser.fromMap(String id, Map<String, dynamic> data) {
    String text(String key) => data[key] is String ? (data[key] as String).trim() : '';
    final created = data['createdAt'];
    return AdminUser(
      id: id,
      name: text('name'),
      email: text('email'),
      createdAt: created is DateTime ? created : null,
      isLocked: data['isLocked'] == true,
    );
  }
}
