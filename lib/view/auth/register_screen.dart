import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/recipes/view/recipe_list_screen.dart';
import '../../providers/user_provider.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  bool _obscureText = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    FocusManager.instance.primaryFocus?.unfocus();

    // Mật khẩu được cắt khoảng trắng như bản cũ để tài khoản cũ vẫn đăng nhập được.
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text.trim();
    final confirmPassword = _confirmPassController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showAuthMessage(context, 'Vui lòng điền đầy đủ thông tin');
      return;
    }
    if (!email.contains('@')) {
      showAuthMessage(context, 'Email không hợp lệ');
      return;
    }
    if (password.length < 6) {
      showAuthMessage(context, 'Mật khẩu phải có ít nhất 6 ký tự');
      return;
    }
    if (password != confirmPassword) {
      showAuthMessage(context, 'Mật khẩu nhập lại không khớp');
      return;
    }

    final result = await userProvider.register(email: email, password: password, name: name);
    if (!mounted) return;

    if (result == 'Success') {
      showAuthMessage(context, 'Đăng ký thành công!');
      // Vào thẳng danh sách công thức của chính mình (giống luồng đăng nhập).
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => RecipeListScreen(loginBuilder: (_) => const LoginScreen())),
        (route) => false,
      );
    } else {
      showAuthMessage(context, result, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<UserProvider>().isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: AuthBody(
        children: [
          const AuthHeader(
            title: 'Tạo tài khoản',
            subtitle: 'Lưu công thức của riêng bạn và nấu theo từng bước',
            icon: Icons.person_add_alt_1_outlined,
          ),
          const SizedBox(height: 32),
          TextField(
            key: const Key('register_name'),
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              labelText: 'Họ và tên',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('register_email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'Dùng email này để đăng nhập',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _passwordField(
            key: const Key('register_password'),
            controller: _passController,
            label: 'Mật khẩu',
            helper: 'Ít nhất 6 ký tự',
            action: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _passwordField(
            key: const Key('register_confirm'),
            controller: _confirmPassController,
            label: 'Nhập lại mật khẩu',
            action: TextInputAction.done,
            onSubmitted: isLoading ? null : _handleRegister,
          ),
          const SizedBox(height: 28),
          AuthSubmitButton(label: 'Đăng ký', loading: isLoading, onPressed: _handleRegister),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Đã có tài khoản?', style: TextStyle(color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required TextInputAction action,
    String? helper,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: _obscureText,
      textInputAction: action,
      autofillHints: const [AutofillHints.newPassword],
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _obscureText ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
    );
  }
}
