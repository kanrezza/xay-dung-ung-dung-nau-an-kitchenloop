import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chốt chặn cho T060 (Constitution VII): mã mạng xã hội, khám phá, quản trị của
/// phiên bản cũ đã được xoá khỏi dự án và không được quay lại; `lib/` không có mã chết.
///
/// Mã cũ đã được sao lưu ngoài dự án trước khi xoá (xem README). Cách kiểm tra: dựng
/// đồ thị `import` bắt đầu từ `lib/main.dart`; một file còn với tới được thì chắc chắn
/// còn một liên kết (trực tiếp hoặc gián tiếp) dẫn tới nó.
void main() {
  const package = 'btl_ltdd';
  final importPattern = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''', multiLine: true);

  /// `lib/a/b.dart` (dạng chuẩn, dấu gạch chéo) từ một đường dẫn import.
  String? resolve(String from, String target) {
    if (target.startsWith('dart:')) return null;
    if (target.startsWith('package:')) {
      final prefix = 'package:$package/';
      return target.startsWith(prefix) ? 'lib/${target.substring(prefix.length)}' : null;
    }
    final parts = [...from.split('/')..removeLast(), ...target.split('/')];
    final out = <String>[];
    for (final p in parts) {
      if (p == '..') {
        out.removeLast();
      } else if (p != '.') {
        out.add(p);
      }
    }
    return out.join('/');
  }

  Set<String> reachableFrom(String entry) {
    final seen = <String>{};
    final stack = [entry];
    while (stack.isNotEmpty) {
      final file = stack.removeLast();
      if (!seen.add(file)) continue;
      final f = File(file);
      if (!f.existsSync()) continue;
      for (final m in importPattern.allMatches(f.readAsStringSync())) {
        final next = resolve(file, m.group(1)!);
        if (next != null && next.endsWith('.dart')) stack.add(next);
      }
    }
    return seen;
  }

  final reachable = reachableFrom('lib/main.dart');

  /// Mã của phiên bản cũ không được phép với tới từ điểm vào của app.
  const legacy = [
    'lib/view/community/',
    'lib/view/admin/',
    'lib/view/discover_screen.dart',
    'lib/view/auth_screen.dart',
    'lib/view/home/',
    'lib/view/food/',
    'lib/view/profile/',
    'lib/view/widgets/',
    'lib/providers/admin_',
    'lib/providers/discover_provider.dart',
    'lib/providers/filter_provider.dart',
    'lib/services/admin_dashboard_service.dart',
    'lib/services/food_service.dart',
    'lib/services/meal_plan_service.dart',
    'lib/models/food_model.dart',
    'lib/models/comment_model.dart',
    'lib/models/dashboard_model.dart',
    'lib/models/filter_model.dart',
    'lib/models/log_model.dart',
    'lib/models/meal_plan_model.dart',
    'lib/models/report_model.dart',
  ];

  test('điểm vào của app với tới được nhiều file (đồ thị được dựng đúng)', () {
    expect(reachable, contains('lib/main.dart'));
    expect(reachable, contains('lib/features/recipes/view/recipe_list_screen.dart'));
    expect(reachable, contains('lib/view/auth/login_screen.dart'));
    expect(reachable.length, greaterThan(30));
  });

  test('đăng nhập, đăng ký, quên mật khẩu vẫn dùng được (giữ lại)', () {
    expect(reachable, contains('lib/view/auth/login_screen.dart'));
    expect(reachable, contains('lib/view/auth/register_screen.dart'));
    expect(reachable, contains('lib/view/auth/forgot_password_screen.dart'));
  });

  for (final prefix in legacy) {
    test('$prefix đã được xoá và không còn đường tới', () {
      final onDisk = prefix.endsWith('/')
          ? Directory(prefix).existsSync()
          : File(prefix).existsSync() || File('$prefix.dart').existsSync();
      expect(onDisk, isFalse, reason: '$prefix đã bị xoá, không được thêm lại');
      final hits = reachable.where((f) => f.startsWith(prefix)).toList()..sort();
      expect(hits, isEmpty, reason: 'còn liên kết tới: $hits');
    });
  }

  test('không có file nào của phiên bản cũ ngoài các file đăng nhập còn dùng', () {
    final keep = {
      'lib/app_theme.dart', // giao diện chung của KitchenLoop, không phải mã cũ
      'lib/main.dart',
      'lib/firebase_options.dart',
      'lib/models/user_model.dart',
      'lib/providers/user_provider.dart',
      'lib/services/auth_service.dart',
      'lib/view/auth/login_screen.dart',
      'lib/view/auth/register_screen.dart',
      'lib/view/auth/forgot_password_screen.dart',
      'lib/view/auth/auth_widgets.dart', // giao diện chung của 3 màn tài khoản (mới)
    };
    final legacyFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart') && !p.startsWith('lib/features/') && !keep.contains(p))
        .toList()
      ..sort();
    expect(legacyFiles, isEmpty, reason: 'file cũ còn sót: $legacyFiles');
  });

  test('không có mã chết: mọi file trong lib/ đều với tới được từ lib/main.dart', () {
    final all = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path)
        .where((p) => p.endsWith('.dart'))
        .toSet();
    final dead = all.difference(reachable).toList()..sort();
    expect(dead, isEmpty, reason: 'file không còn được dùng: $dead');
  });

  test('pubspec không còn thư viện chỉ mã cũ dùng (video_player, fl_chart)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('video_player')));
    expect(pubspec, isNot(contains('fl_chart')));
  });

  test('sau đăng nhập và sau đăng ký đều vào danh sách công thức', () {
    for (final path in ['lib/view/auth/login_screen.dart', 'lib/view/auth/register_screen.dart']) {
      final source = File(path).readAsStringSync();
      expect(source, contains('RecipeListScreen'), reason: path);
      expect(source, isNot(contains('BloggerHomeScreen')), reason: path);
      expect(source, isNot(contains('AdminHomeScreen')), reason: path);
    }
  });

  test('main.dart không còn đăng ký provider của màn hình quản trị/cộng đồng cũ', () {
    final main = File('lib/main.dart').readAsStringSync();
    for (final name in ['AdminFoodProvider', 'AdminUserProvider', 'AdminDashboardProvider', 'AdminDashboardService', 'DiscoverProvider']) {
      expect(main, isNot(contains(name)), reason: name);
    }
  });
}
