import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../features/recipes/view/recipe_list_screen.dart';
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

  void _handleRegister() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    FocusManager.instance.primaryFocus?.unfocus();

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passController.text.trim();
    String confirmPassword = _confirmPassController.text.trim();

    // 1. Validate dữ liệu
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vui lòng điền đầy đủ thông tin")));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mật khẩu nhập lại không khớp")));
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Mật khẩu phải có ít nhất 6 ký tự")));
      return;
    }

    // 2. Gọi API đăng ký
    String result = await userProvider.register(
      email: email,
      password: password,
      name: name,
    );

    if (!mounted) return;

    if (result == "Success") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Đăng ký thành công!"),
            backgroundColor: Colors.green),
      );

      // Vào thẳng danh sách công thức của chính mình (giống luồng đăng nhập).
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeListScreen(loginBuilder: (_) => const LoginScreen()),
        ),
        (route) => false,
      );
    } else {
      // SỬA: Dùng toán tử ?? để đề phòng result bị null
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<UserProvider>(context).isLoading;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        "ĐĂNG KÝ",
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Tạo tài khoản mới để bắt đầu",
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 40),
                      _buildTextField(
                          controller: _nameController,
                          label: "Họ và Tên",
                          icon: Icons.badge_outlined),
                      const SizedBox(height: 15),
                      _buildTextField(
                          controller: _emailController,
                          label: "Email",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                          controller: _passController, label: "Mật khẩu"),
                      const SizedBox(height: 15),
                      _buildPasswordField(
                          controller: _confirmPassController,
                          label: "Nhập lại mật khẩu"),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              // NÚT ĐĂNG KÝ (Sticky Footer)
              InkWell(
                onTap: isLoading ? null : _handleRegister,
                child: Container(
                  width: double.infinity,
                  height: 60,
                  color: const Color.fromARGB(
                      255, 30, 132, 190), // Màu nổi bật cho đăng ký
                  alignment: Alignment.center,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "ĐĂNG KÝ",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                            SizedBox(width: 5),
                            Icon(Icons.arrow_forward_ios,
                                color: Colors.white, size: 16)
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(35),
            borderSide: const BorderSide(color: Colors.grey)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }

  Widget _buildPasswordField(
      {required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      obscureText: _obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(35)),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    );
  }
}
