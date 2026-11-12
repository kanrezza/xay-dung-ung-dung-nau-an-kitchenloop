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

    test('firestore.rules: users chỉ chủ tài khoản đọc, không ai liệt kê', () {
      final rules = read('firestore.rules');
      final users = rules.substring(rules.indexOf('match /users/{userId}'), rules.indexOf('match /foods/{foodId}'));
      expect(users, contains('allow get: if isOwner(userId);'));
      expect(users, contains('allow list: if false;'));
      expect(users, isNot(contains('isAdmin')));
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

    test('không còn thư mục ai cũng ghi được (food_images, avatars)', () {
      expect(rules, isNot(contains('match /food_images')));
      expect(rules, isNot(contains('match /avatars')));
      expect(rules, isNot(contains('allow read: if true')));
    });

    test('đường dẫn ảnh trong rules khớp với đường dẫn RecipeRepository tải lên', () {
      final repo = read('lib/features/recipes/data/recipe_repository.dart');
      expect(repo, contains("storage.ref('foods/\$uid/recipes/\$recipeId/"));
      expect(rules, contains('match /foods/{userId}/recipes/{recipeId}/{fileName}'));
    });
  });
}
