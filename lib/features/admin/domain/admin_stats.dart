import '../../recipes/domain/text_normalizer.dart';
import '../models/admin_user.dart';

/// Số liệu tổng quan cho màn hình quản trị.
class AdminStats {
  const AdminStats({required this.total, required this.locked, required this.newLast7Days});

  final int total;
  final int locked;

  /// Tài khoản tạo trong 7 ngày gần nhất (tính từ [now]).
  final int newLast7Days;
}

AdminStats computeAdminStats(List<AdminUser> users, DateTime now) {
  final since = now.subtract(const Duration(days: 7));
  return AdminStats(
    total: users.length,
    locked: users.where((u) => u.isLocked).length,
    newLast7Days: users.where((u) => u.createdAt != null && !u.createdAt!.isBefore(since)).length,
  );
}

/// Lọc theo tên hoặc email, không phân biệt hoa thường và dấu tiếng Việt.
/// Sắp xếp: tài khoản bị khoá lên đầu, sau đó mới nhất trước.
List<AdminUser> filterAdminUsers(List<AdminUser> users, String query) {
  final q = normalizeForSearch(query);
  final result = q.isEmpty
      ? [...users]
      : users.where((u) => normalizeForSearch('${u.name} ${u.email}').contains(q)).toList();
  result.sort((a, b) {
    if (a.isLocked != b.isLocked) return a.isLocked ? -1 : 1;
    final ad = a.createdAt, bd = b.createdAt;
    if (ad == null && bd == null) return a.email.compareTo(b.email);
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return result;
}
