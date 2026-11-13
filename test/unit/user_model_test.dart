import 'package:btl_ltdd/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hồ sơ tạo ngoài app thiếu createdAt vẫn đọc được (không làm hỏng đăng nhập)', () {
    final user = UserModel.fromMap({'id': 'u', 'email': 'demo@example.com', 'recipeMigratedAt': Timestamp.now()});
    expect(user.email, 'demo@example.com');
    expect(user.createdAt, isNotNull);
  });

  test('createdAt dạng Timestamp được giữ nguyên', () {
    final at = DateTime(2026, 1, 2);
    expect(UserModel.fromMap({'createdAt': Timestamp.fromDate(at)}).createdAt, at);
  });
}
