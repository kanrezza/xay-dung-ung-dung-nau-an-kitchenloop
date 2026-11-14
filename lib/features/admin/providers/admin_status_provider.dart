import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/admin_repository.dart';

/// Tài khoản đang đăng nhập có phải quản trị viên không (spec 007). Chỉ để ẩn/hiện công cụ;
/// quyền thật do Firestore rules kiểm tra.
class AdminStatusProvider extends ChangeNotifier {
  AdminStatusProvider({required AdminRepository repository}) {
    _sub = repository.watchIsAdmin().listen(_set, onError: (Object _) => _set(false));
    // Một lần làm mới token: quyền vừa cấp bằng script có hiệu lực mà không cần đăng nhập lại.
    repository.isCurrentUserAdmin().then(_set, onError: (Object _) {});
  }

  StreamSubscription<bool>? _sub;
  bool _isAdmin = false;

  bool get isAdmin => _isAdmin;

  void _set(bool value) {
    if (value == _isAdmin) return;
    _isAdmin = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
