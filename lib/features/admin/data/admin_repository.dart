import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/firestore_codec.dart';
import '../models/admin_user.dart';

/// Dữ liệu cho màn hình quản trị (spec 002). Quyền thật sự do Firestore rules kiểm tra:
/// chỉ tài khoản có custom claim `admin` mới đọc/khoá được; ở đây chỉ để ẩn/hiện giao diện.
abstract class AdminRepository {
  /// UID của tài khoản đang đăng nhập (để không cho tự khoá mình).
  String? get currentUid;

  /// `true` nếu tài khoản đang đăng nhập có custom claim `admin == true`.
  Future<bool> isCurrentUserAdmin();

  /// Danh sách hồ sơ `users`, cập nhật theo thời gian thực.
  Stream<List<AdminUser>> watchUsers();

  /// Khoá hoặc mở khoá tài khoản [uid].
  Future<void> setLocked(String uid, bool locked);
}

class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({required FirebaseFirestore firestore, required FirebaseAuth auth})
      : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<bool> isCurrentUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // forceRefresh: quyền vừa được cấp/thu bằng script có hiệu lực mà không cần đăng nhập lại.
      final token = await user.getIdTokenResult(true);
      return token.claims?['admin'] == true;
    } catch (_) {
      // Mất mạng: dùng token đang có trong máy.
      try {
        final token = await user.getIdTokenResult();
        return token.claims?['admin'] == true;
      } catch (_) {
        return false;
      }
    }
  }

  @override
  Stream<List<AdminUser>> watchUsers() => _firestore.collection('users').snapshots().map(
        (snap) => [for (final d in snap.docs) AdminUser.fromMap(d.id, decodeFirestoreMap(d.data()))],
      );

  @override
  Future<void> setLocked(String uid, bool locked) => _firestore.collection('users').doc(uid).update({
        'isLocked': locked,
        'lockedAt': locked ? FieldValue.serverTimestamp() : null,
      });
}
