import 'package:btl_ltdd/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Gửi email đặt lại mật khẩu (Firebase gửi liên kết, app không đụng tới mật khẩu).
  void _handleResetPassword() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showAuthMessage(context, 'Vui lòng nhập email để lấy lại mật khẩu');
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final result = await userProvider.forgotPassword(email);
    if (!mounted) return;

    if (result == 'Success') {
      showAuthMessage(context, 'Đã gửi email đặt lại mật khẩu. Hãy kiểm tra hộp thư.');
      // Đợi một chút để người dùng kịp đọc rồi quay lại màn hình đăng nhập.
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context);
    } else {
      showAuthMessage(context, result, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(),
      body: AuthBody(
        children: [
          const AuthHeader(
            title: 'Quên mật khẩu',
            subtitle: 'Nhập email của tài khoản, chúng tôi sẽ gửi liên kết để đặt lại mật khẩu.',
            icon: Icons.lock_reset,
          ),
          const SizedBox(height: 32),
          TextField(
            key: const Key('forgot_email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => isLoading ? null : _handleResetPassword(),
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          AuthSubmitButton(label: 'Gửi liên kết', loading: isLoading, onPressed: _handleResetPassword),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại đăng nhập'),
          ),
        ],
      ),
    );
  }
}
