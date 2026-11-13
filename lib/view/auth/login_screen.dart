import 'dart:async';

import 'package:btl_ltdd/features/home/view/app_shell.dart';
import 'package:btl_ltdd/providers/user_provider.dart';
import 'package:btl_ltdd/view/auth/auth_widgets.dart';
import 'package:btl_ltdd/view/auth/forgot_password_screen.dart';
import 'package:btl_ltdd/view/auth/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _obscureText = true;
  bool _rememberMe = false; // Biến trạng thái cho ô checkbox

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials(); // Tự động tải mật khẩu khi mở màn hình
  }

  /// Khoá lưu email khi người dùng chọn "Nhớ email". KHÔNG BAO GIỜ lưu mật khẩu:
  /// SharedPreferences là tệp chữ thường, ai có máy hoặc bản sao lưu đều đọc được.
  /// Không cần lưu mật khẩu vì Firebase Auth đã tự giữ phiên đăng nhập.
  static const _savedEmailKey = 'saved_email';

  /// Các khoá của bản cũ (từng lưu mật khẩu dạng chữ thường), bị xoá khi mở màn hình.
  static const _legacyKeys = ['saved_password', 'saved_username'];

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _usernameController.text = prefs.getString(_savedEmailKey) ?? '';
      }
    });
  }

  Future<void> _saveSavedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString(_savedEmailKey, email);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove(_savedEmailKey);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // Xử lý đăng nhập, nhớ email (nếu chọn) và chuyển sang danh sách công thức.
  void _handleLogin() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    // Ẩn bàn phím trước khi xử lý
    FocusManager.instance.primaryFocus?.unfocus();

    final username = _usernameController.text.trim();
    final password = _passController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      showAuthMessage(context, 'Vui lòng nhập email và mật khẩu');
      return;
    }
    if (!username.contains('@')) {
      showAuthMessage(context, 'Vui lòng đăng nhập bằng email');
      return;
    }

    // Gọi hàm login từ Provider
    String result = await userProvider.login(
      username,
      password,
    );

    if (!mounted) return; // Kiểm tra xem màn hình còn tồn tại không

    if (result == "Success") {
      // Lưu "nhớ email" ở nền để người dùng được chuyển trang ngay khi Firebase login xong.
      unawaited(_saveSavedEmail(username));

      // Chuyển hướng: mọi vai trò (kể cả admin) vào thẳng danh sách công thức
      // của chính mình (KitchenLoop GĐ1). Xoá màn hình đăng nhập khỏi lịch sử để
      // nút Back không quay lại.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => AppShell(loginBuilder: (_) => const LoginScreen()),
        ),
        (route) => false,
      );
    } else {
      // Đăng nhập thất bại
      showAuthMessage(context, result, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserProvider>().isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AuthBody(
        children: [
          const SizedBox(height: 8),
          const AuthHeader(title: 'KitchenLoop', subtitle: 'Công thức của bạn, nấu theo từng bước'),
          const SizedBox(height: 36),

          // --- EMAIL ---
          TextField(
            key: const Key('login_email'),
            controller: _usernameController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // --- MẬT KHẨU ---
          TextField(
            key: const Key('login_password'),
            controller: _passController,
            obscureText: _obscureText,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => isLoading ? null : _handleLogin(),
            decoration: InputDecoration(
              labelText: 'Mật khẩu',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),

          // --- NHỚ EMAIL (không lưu mật khẩu) & QUÊN MẬT KHẨU ---
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) => setState(() => _rememberMe = value ?? false),
              ),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: const Text('Nhớ email'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                ),
                child: const Text('Quên mật khẩu?'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- NÚT ĐĂNG NHẬP ---
          AuthSubmitButton(
            key: const Key('login_submit'),
            label: 'Đăng nhập',
            loading: isLoading,
            onPressed: _handleLogin,
          ),
          const SizedBox(height: 24),

          // --- ĐĂNG KÝ ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Chưa có tài khoản?', style: TextStyle(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text('Đăng ký ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
