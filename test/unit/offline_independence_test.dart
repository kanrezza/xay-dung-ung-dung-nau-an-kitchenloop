import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Chốt chặn cho US6 / FR-019: các chức năng phải dùng được khi mất mạng thì
/// không được phụ thuộc vào Firebase hay HTTP. Test đọc mã nguồn và kiểm tra các
/// dòng `import`, nên ai đó vô tình thêm phụ thuộc mạng vào các tệp này sẽ bị phát hiện.
void main() {
  const base = 'lib/features/recipes';

  final networkImport = RegExp(
    r'''^\s*import\s+['"]package:(cloud_firestore|firebase_auth|firebase_storage|firebase_core|http|dio)/''',
    multiLine: true,
  );

  List<String> networkImportsIn(String path) =>
      networkImport.allMatches(File(path).readAsStringSync()).map((m) => m.group(0)!.trim()).toList();

  group('không phụ thuộc mạng: hẹn giờ, quy đổi khẩu phần, chế độ nấu', () {
    const offlineSafe = [
      // Hẹn giờ và thông báo cục bộ.
      '$base/models/cooking_session.dart',
      '$base/data/cooking_session_store.dart',
      '$base/data/timer_notifier.dart',
      '$base/data/timer_notification_service.dart',
      '$base/data/screen_awake.dart',
      '$base/providers/cooking_mode_provider.dart',
      // Quy đổi khẩu phần và định dạng số lượng.
      '$base/domain/serving_scaler.dart',
      '$base/domain/quantity_parser.dart',
      // Màn hình chế độ nấu và các phần của nó.
      '$base/view/cooking_mode_screen.dart',
      '$base/view/widgets/cooking_step_page.dart',
      '$base/view/widgets/cooking_timer_bar.dart',
      '$base/view/widgets/cooking_ingredients_drawer.dart',
      '$base/view/widgets/step_timer_chip.dart',
      '$base/view/widgets/servings_stepper.dart',
      // Tìm kiếm và lọc chạy trên danh sách đã có trong máy.
      '$base/domain/text_normalizer.dart',
      '$base/domain/recipe_filter.dart',
    ];

    for (final path in offlineSafe) {
      test(path.replaceFirst('$base/', ''), () {
        expect(File(path).existsSync(), isTrue, reason: 'thiếu file $path');
        expect(networkImportsIn(path), isEmpty, reason: '$path không được import thư viện mạng');
      });
    }
  });

  group('ghi dữ liệu khi offline', () {
    test('main.dart bật bộ nhớ đệm bền của Firestore (xem công thức khi mất mạng)', () {
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains('persistenceEnabled: true'));
    });

    test('repository dùng settleWrite cho create/update/delete để không treo giao diện', () {
      final repo = File('$base/data/recipe_repository.dart').readAsStringSync();
      expect(RegExp(r'await settleWrite\(').allMatches(repo).length, 3);
      expect(repo, isNot(contains('await ref.set(')));
    });

    test('danh sách và chi tiết đọc qua snapshots() có siêu dữ liệu (lấy từ cache, biết đang đồng bộ)', () {
      final repo = File('$base/data/recipe_repository.dart').readAsStringSync();
      expect(RegExp(r'snapshots\(includeMetadataChanges: true\)').allMatches(repo).length, 2);
    });

    test('chỉ thư mục data/ được import Firebase; model, domain, providers, view thì không (Constitution IV)', () {
      final files = Directory(base)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('/data/'))
          .toList();
      expect(files.length, greaterThan(25), reason: 'bộ quét file có vấn đề');
      for (final f in files) {
        expect(networkImportsIn(f.path), isEmpty, reason: f.path);
      }
    });
  });

  // Constitution IV cho mọi feature khác ngoài recipes (admin: spec 002; home, planner: spec 003).
  for (final feature in ['admin', 'community', 'home', 'planner']) {
    test('$feature: chỉ thư mục data/ được import Firebase (Constitution IV)', () {
      final files = Directory('lib/features/$feature')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('/data/'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(3), reason: 'bộ quét file có vấn đề');
      for (final f in files) {
        expect(networkImportsIn(f.path), isEmpty, reason: f.path);
      }
    });
  }

  test('thực đơn và danh sách đi chợ: logic gộp, tuần, provider không phụ thuộc mạng', () {
    for (final path in [
      'lib/features/planner/domain/shopping_builder.dart',
      'lib/features/planner/domain/week.dart',
      'lib/features/planner/models/week_plan.dart',
      'lib/features/planner/models/shopping_state.dart',
      'lib/features/planner/providers/meal_plan_provider.dart',
      'lib/features/planner/providers/shopping_provider.dart',
    ]) {
      expect(networkImportsIn(path), isEmpty, reason: path);
    }
  });

  group('xử lý tải ảnh khi offline', () {
    test('trình chọn ảnh bắt OfflineException và hiện thông báo, không làm mất dữ liệu đang nhập', () {
      final picking = File('$base/view/widgets/image_picking.dart').readAsStringSync();
      expect(picking, contains('OfflineException'));
      expect(picking, contains('recipes.err_offline_image'));
    });

    test('mọi ảnh dùng RecipeImage (có cache) thay vì Image.network', () {
      for (final f in Directory('$base/view').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('recipe_image.dart')) continue;
        expect(f.readAsStringSync(), isNot(contains('Image.network')), reason: f.path);
      }
    });
  });
}
