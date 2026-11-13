import 'package:btl_ltdd/features/admin/domain/admin_stats.dart';
import 'package:btl_ltdd/features/admin/models/admin_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 14, 12);
  AdminUser u(String id, {String name = '', String email = '', DateTime? created, bool locked = false}) =>
      AdminUser(id: id, name: name, email: email, createdAt: created, isLocked: locked);

  group('AdminUser.fromMap', () {
    test('đọc đủ trường', () {
      final user = AdminUser.fromMap('a', {
        'name': ' An ',
        'email': 'an@example.com',
        'createdAt': DateTime(2026, 1, 2),
        'isLocked': true,
      });
      expect(user.name, 'An');
      expect(user.email, 'an@example.com');
      expect(user.createdAt, DateTime(2026, 1, 2));
      expect(user.isLocked, isTrue);
    });

    test('hồ sơ cũ thiếu trường hoặc sai kiểu: dùng mặc định, không lỗi', () {
      final user = AdminUser.fromMap('b', {'name': 42, 'createdAt': 'hôm qua', 'isLocked': 'yes'});
      expect(user.name, '');
      expect(user.email, '');
      expect(user.createdAt, isNull);
      expect(user.isLocked, isFalse);
    });
  });

  group('computeAdminStats', () {
    test('đếm tổng, đang khoá, mới trong 7 ngày', () {
      final stats = computeAdminStats([
        u('1', created: now.subtract(const Duration(days: 1))),
        u('2', created: now.subtract(const Duration(days: 7))),
        u('3', created: now.subtract(const Duration(days: 8)), locked: true),
        u('4', locked: true),
      ], now);
      expect(stats.total, 4);
      expect(stats.locked, 2);
      expect(stats.newLast7Days, 2);
    });

    test('danh sách rỗng', () {
      final stats = computeAdminStats([], now);
      expect([stats.total, stats.locked, stats.newLast7Days], [0, 0, 0]);
    });
  });

  group('filterAdminUsers', () {
    final users = [
      u('1', name: 'Nguyễn Văn An', email: 'an@example.com', created: DateTime(2026, 1, 1)),
      u('2', name: 'Bình', email: 'binh@example.com', created: DateTime(2026, 3, 1)),
      u('3', name: 'Chi', email: 'chi@example.com', created: DateTime(2026, 2, 1), locked: true),
      u('4', email: 'cu@example.com'),
    ];

    test('tìm không dấu, không phân biệt hoa thường, theo tên hoặc email', () {
      expect(filterAdminUsers(users, 'NGUYEN van').map((e) => e.id), ['1']);
      expect(filterAdminUsers(users, 'binh@').map((e) => e.id), ['2']);
    });

    test('tài khoản bị khoá lên đầu, rồi mới nhất trước, thiếu ngày tạo xuống cuối', () {
      expect(filterAdminUsers(users, '').map((e) => e.id), ['3', '2', '1', '4']);
    });
  });
}
