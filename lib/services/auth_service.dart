import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return "Không kết nối được Firebase. Hãy kiểm tra Internet của máy ảo/điện thoại rồi thử lại.";
      case 'user-not-found':
        return "Tài khoản không tồn tại.";
      case 'wrong-password':
      case 'invalid-credential':
        return "Sai tài khoản hoặc mật khẩu.";
      case 'invalid-email':
        return "Email không hợp lệ.";
      case 'user-disabled':
        return "Tài khoản này đã bị vô hiệu hóa.";
      case 'too-many-requests':
        return "Bạn thử đăng nhập quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.";
      case 'email-already-in-use':
        return "Email này đã được đăng ký.";
      default:
        return "Lỗi đăng nhập: ${e.message ?? e.code}";
    }
  }

  UserModel _buildDefaultUserFromAuth(User user, String email) {
    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : email.split('@').first;

    return UserModel(
      id: user.uid,
      username: email.split('@').first,
      name: name,
      email: email,
      role: UserRole.blogger,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      isLocked: false,
      favorites: const [],
      followers: const [],
      bio: '',
    );
  }

  Future<void> _deleteCreatedAuthUser(User? user) async {
    if (user == null) return;

    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  // --- 1. ĐĂNG KÝ ---
  // Không còn tên đăng nhập riêng: kiểm tra trùng tên cần đọc hồ sơ của người khác,
  // điều mà Firestore rules (chỉ chủ tài khoản đọc hồ sơ của mình) không cho phép.
  // Email do Firebase Auth đảm bảo không trùng.
  Future<String?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    UserCredential? cred;

    try {
      // B1: Tạo tài khoản Auth trước để Firestore rules cho phép đọc/ghi hồ sơ.
      cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // B2: Lưu hồ sơ (chỉ chủ tài khoản đọc được, xem firestore.rules)
      UserModel newUser = UserModel(
        id: cred.user!.uid,
        username: email.split('@').first,
        name: name,
        email: email,
        phoneNumber: '',
        address: '',
        role: UserRole.blogger,
        createdAt: DateTime.now(),
        isLocked: false,
        favorites: [],
        followers: [],
        bio: '',
      );

      await _firestore.collection('users').doc(newUser.id).set(newUser.toMap());
      return "Success"; // Trả về chuỗi Success nếu thành công
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } on FirebaseException catch (e) {
      await _deleteCreatedAuthUser(cred?.user);
      if (e.code == 'permission-denied') {
        return "Firestore đang chặn quyền tạo hồ sơ. Hãy kiểm tra lại Rules rồi thử đăng ký lại.";
      }
      return "Lỗi Firebase: ${e.message ?? e.code}";
    } catch (e) {
      await _deleteCreatedAuthUser(cred?.user);
      return "Lỗi không xác định: $e";
    }
  }

  // --- 2. ĐĂNG NHẬP (bằng email) ---
  // Bản cũ cho đăng nhập bằng tên người dùng bằng cách tra collection `users` khi
  // CHƯA đăng nhập. Muốn vậy rules phải cho người lạ liệt kê toàn bộ hồ sơ (lộ email
  // của mọi người), nên tính năng này đã bị bỏ.
  Future<dynamic> login(String loginInput, String password) async {
    try {
      final emailToLogin = loginInput.trim();
      if (!emailToLogin.contains('@')) {
        return "Vui lòng đăng nhập bằng email.";
      }

      UserCredential cred = await _auth
          .signInWithEmailAndPassword(
            email: emailToLogin,
            password: password,
          )
          .timeout(const Duration(seconds: 15));

      final firebaseUser = cred.user;
      if (firebaseUser == null) {
        return "Không lấy được thông tin tài khoản sau khi đăng nhập.";
      }

      // Lấy thông tin chi tiết
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) {
        final newUser = _buildDefaultUserFromAuth(firebaseUser, emailToLogin);
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(newUser.toMap())
            .timeout(const Duration(seconds: 10));
        return newUser;
      }

      final data = doc.data() as Map<String, dynamic>;

      // KIỂM TRA TÀI KHOẢN BỊ KHÓA
      if (data['isLocked'] == true) {
        await _auth.signOut(); // Đăng xuất ngay
        return "Tài khoản đã bị khóa.";
      }

      // Nếu không bị khóa thì trả về user
      return UserModel.fromMap(data);
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        await _auth.signOut();
        return "Đăng nhập thành công nhưng Firestore đang chặn quyền đọc hồ sơ người dùng.";
      }
      return "Lỗi Firebase: ${e.message ?? e.code}";
    } on TimeoutException {
      return "Kết nối Firebase quá lâu, vui lòng kiểm tra mạng hoặc thử lại.";
    } catch (e) {
      return "Lỗi đăng nhập: $e";
    }
  }

  // --- 3. QUÊN MẬT KHẨU ---
  // Firebase gửi Link reset pass về email (Cách chuẩn bảo mật nhất)
  Future<String> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return "Success";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return "Email này chưa đăng ký tài khoản nào.";
      }
      return e.message ?? "Lỗi gửi mail";
    }
  }

  // ... (Hàm logout và stream giữ nguyên)
  Future<void> logout() async {
    await _auth.signOut();
  }
}
