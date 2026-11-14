import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chốt chặn bảo mật cho phần đăng nhập giữ lại từ bản cũ. Test đọc mã nguồn và rules,
/// để ai đó vô tình đưa lại các lỗ hổng đã vá sẽ bị phát hiện.
void main() {
  String read(String path) => File(path).readAsStringSync();

  group('không lưu mật khẩu', () {
    test('màn hình đăng nhập không ghi mật khẩu vào SharedPreferences', () {
      final login = read('lib/view/auth/login_screen.dart');
      expect(login, isNot(contains("setString('saved_password'")));
      expect(RegExp(r'setString\([^)]*pass', caseSensitive: false).hasMatch(login), isFalse);
    });

    test('mật khẩu cũ đã lưu trên máy được xoá khi mở màn hình đăng nhập', () {
      final login = read('lib/view/auth/login_screen.dart');
      expect(login, contains("'saved_password'"));
      expect(login, contains('prefs.remove(key)'));
    });

    test('hồ sơ người dùng không có trường mật khẩu', () {
      final model = read('lib/models/user_model.dart');
      expect(model, isNot(contains("'password'")));
    });
  });

  group('không tra hồ sơ người khác', () {
    test('AuthService không truy vấn collection users bằng where (tra username)', () {
      final service = read('lib/services/auth_service.dart');
      expect(service, isNot(contains('.where(')));
    });

    test('firestore.rules: users chỉ chủ tài khoản hoặc quản trị viên đọc; chỉ quản trị viên liệt kê', () {
      final rules = read('firestore.rules');
      final users = rules.substring(rules.indexOf('match /users/{userId}'), rules.indexOf('match /foods/{foodId}'));
      expect(users, contains('allow get: if isOwner(userId) || isAdmin();'));
      expect(users, contains('allow list: if isAdmin();'));
    });

    test('quyền quản trị chỉ đến từ custom claim, không từ trường role trong Firestore', () {
      final rules = read('firestore.rules');
      final isAdmin = rules.substring(rules.indexOf('function isAdmin()'), rules.indexOf('function notLocked()'));
      expect(isAdmin, contains('request.auth.token'));
      expect(isAdmin, isNot(contains('role')));
      // Không đọc tài liệu Firestore (như users/{uid}.role) để quyết định quyền admin.
      expect(isAdmin, isNot(contains('get(/')));
      expect(isAdmin, isNot(contains('exists(')));
    });

    test('quản trị viên không có nhánh đọc recipes', () {
      final rules = read('firestore.rules');
      final recipes = rules.substring(rules.indexOf('match /recipes/{recipeId}'), rules.indexOf('THỰC ĐƠN TUẦN, ĐI CHỢ'));
      expect(recipes, isNot(contains('isAdmin')));
      expect('notLocked()'.allMatches(recipes).length, 5, reason: 'get, list, create, update, delete');
    });

    test('firestore.rules: collection của bản cũ không ghi được', () {
      final rules = read('firestore.rules');
      final foods = rules.substring(rules.indexOf('match /foods/{foodId}'), rules.indexOf('RECIPES (KitchenLoop'));
      expect(foods, contains('allow write: if false;'));
      expect(rules, isNot(contains('match /meal_plans')));
      expect(rules, isNot(contains('match /followers')));
    });
  });

  group('storage.rules', () {
    final rules = File('storage.rules').readAsStringSync();

    test('không còn thư mục ai cũng ghi được (food_images; avatars cũ dạng /avatars/{fileName})', () {
      expect(rules, isNot(contains('match /food_images')));
      expect(rules, isNot(contains('match /avatars/{fileName}')));
      // Ảnh đại diện mới (spec 005): mỗi người một thư mục, chỉ chủ tài khoản ghi/xoá.
      final avatars = rules.substring(rules.indexOf('match /avatars/{userId}/{fileName}'));
      expect(avatars, contains('allow create, update: if isOwner(userId)'));
      expect(avatars, contains('allow delete: if isOwner(userId);'));
      expect(rules, isNot(contains('allow read: if true')));
    });

    test('đường dẫn ảnh trong rules khớp với đường dẫn RecipeRepository tải lên', () {
      final repo = read('lib/features/recipes/data/recipe_repository.dart');
      expect(repo, contains("storage.ref('foods/\$uid/recipes/\$recipeId/"));
      expect(rules, contains('match /foods/{userId}/recipes/{recipeId}/{fileName}'));
    });
  });
}
