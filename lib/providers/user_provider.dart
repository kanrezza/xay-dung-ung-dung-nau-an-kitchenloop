import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user; // Dữ liệu User hiện tại (null = chưa đăng nhập)
  bool _isLoading = false; // Trạng thái đang tải

  // Getter
  UserModel? get user => _user;
  bool get isLoading => _isLoading;

  bool get isLoggedIn => _user != null;

  bool get isAdmin => _user?.role == UserRole.admin;

  bool get isBlocked => _user?.isLocked ?? false;

  // 1. Hàm Đăng ký
  Future<String> register({
    required String email,
    required String password,
    required String name,
  }) async {
    _setLoading(true);

    try {
      // Đảm bảo bên AuthService hàm register cũng nhận tham số kiểu này
      String? result = await _authService.register(
        email: email,
        password: password,
        name: name,
      );

      if (result == "Success") {
        return "Success";
      }
      return result ?? "Lỗi không xác định";
    } catch (e) {
      return "Lỗi đăng ký: $e";
    } finally {
      _setLoading(false);
    }
  }

  // 2. Hàm Đăng nhập
  Future<String> login(String loginInput, String password) async {
    _setLoading(true);

    try {
      // Gọi service
      var result = await _authService.login(loginInput, password);

      // Kiểm tra kết quả trả về
      if (result is UserModel) {
        _user = result; // Lưu user vào provider
        return "Success";
      } else {
        // Nếu thất bại, result sẽ là chuỗi thông báo lỗi
        return result.toString();
      }
    } catch (e) {
      return "Lỗi đăng nhập: $e";
    } finally {
      _setLoading(false);
    }
  }

  // 3. Hàm Quên mật khẩu
  Future<String> forgotPassword(String email) async {
    _setLoading(true);
    String result = await _authService.resetPassword(email);
    _setLoading(false);
    return result;
  }

  // 4. Hàm Đăng xuất (Bạn đang thiếu hàm này)
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  // Hàm này giúp cập nhật biến _isLoading và báo cho UI biết để quay vòng tròn
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
