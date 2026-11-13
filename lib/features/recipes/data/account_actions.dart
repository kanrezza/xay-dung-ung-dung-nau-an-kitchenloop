import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../../services/auth_service.dart';

/// Các thao tác tài khoản của màn hình tài khoản: xem email, đổi ngôn ngữ,
/// đăng xuất. Nhận hàm qua constructor để test được mà không cần Firebase.
class AccountActions {
  AccountActions({
    required String? Function() emailGetter,
    required Future<void> Function() signOutCallback,
    this.beforeSignOut,
    Future<bool> Function()? adminChecker,
  })  : _emailGetter = emailGetter,
        _signOutCallback = signOutCallback,
        _adminChecker = adminChecker;

  /// Bản dùng Firebase thật. [beforeSignOut] chạy trước khi đăng xuất, ví dụ
  /// để huỷ mọi hẹn giờ đang chạy.
  factory AccountActions.firebase({
    FirebaseAuth? auth,
    AuthService? authService,
    Future<void> Function()? beforeSignOut,
    Future<bool> Function()? adminChecker,
  }) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    final service = authService ?? AuthService();
    return AccountActions(
      emailGetter: () => firebaseAuth.currentUser?.email,
      signOutCallback: service.logout,
      beforeSignOut: beforeSignOut,
      adminChecker: adminChecker,
    );
  }

  final String? Function() _emailGetter;
  final Future<void> Function() _signOutCallback;
  final Future<bool> Function()? _adminChecker;

  /// `true` nếu tài khoản đang đăng nhập là quản trị viên (custom claim, spec 002).
  /// Chỉ để hiện mục "Quản trị"; quyền thật do Firestore rules kiểm tra.
  Future<bool> isAdmin() async => await _adminChecker?.call() ?? false;

  /// Chạy trước [signOut] (huỷ hẹn giờ, dọn dữ liệu cục bộ...).
  final Future<void> Function()? beforeSignOut;

  /// Email tài khoản đang đăng nhập.
  String? get email => _emailGetter();

  /// Đổi ngôn ngữ giao diện (`vi` hoặc `en`); easy_localization ghi nhớ lựa chọn.
  Future<void> setLanguage(BuildContext context, Locale locale) => context.setLocale(locale);

  Future<void> signOut() async {
    await beforeSignOut?.call();
    await _signOutCallback();
  }
}
