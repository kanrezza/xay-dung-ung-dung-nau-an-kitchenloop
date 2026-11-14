import 'package:btl_ltdd/features/recipes/view/widgets/recipe_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpImage(WidgetTester tester, Widget image) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: image))));
  }

  testWidgets('không có đường dẫn: hiện khung dự phòng, không tải gì', (tester) async {
    await pumpImage(tester, const RecipeImage(url: '', width: 64, height: 64));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
  });

  testWidgets('khung dự phòng tuỳ chỉnh được dùng khi không có ảnh', (tester) async {
    await pumpImage(
      tester,
      const RecipeImage(url: '', width: 64, height: 64, fallback: Text('KHÔNG CÓ ẢNH')),
    );
    expect(find.text('KHÔNG CÓ ẢNH'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu), findsNothing);
  });

  testWidgets('có đường dẫn: dùng CachedNetworkImage (cache trên đĩa) đúng kích thước', (tester) async {
    await pumpImage(tester, const RecipeImage(url: 'https://example.com/a.jpg', width: 120, height: 80));
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(image.imageUrl, 'https://example.com/a.jpg');
    expect(image.width, 120);
    expect(image.height, 80);
    expect(image.fit, BoxFit.cover);
  });

  testWidgets('giải mã ảnh đúng cỡ hiển thị (× mật độ điểm ảnh), không phải ảnh gốc', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpImage(tester, const RecipeImage(url: 'https://example.com/a.jpg', width: 64, height: 64));
    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).memCacheWidth, 192);
  });

  testWidgets('không có width: dùng bề rộng chỗ chứa để tính cỡ giải mã', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpImage(tester, const Center(child: SizedBox(width: 150, child: RecipeImage(url: 'https://example.com/a.jpg', height: 80))));
    expect(tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).memCacheWidth, 300);
  });

  testWidgets('trong lúc tải hiện vòng quay thay vì ô trống', (tester) async {
    await pumpImage(tester, const RecipeImage(url: 'https://example.com/a.jpg', width: 120, height: 80));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  // Không chờ một lần tải thật thất bại: trong môi trường test không có plugin path_provider
  // nên bộ cache ném MissingPluginException (app thật không bị). Thay vào đó gọi trực tiếp
  // các hàm dựng giao diện mà RecipeImage đã trao cho CachedNetworkImage.
  Widget buildError(WidgetTester tester) {
    final image = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    final context = tester.element(find.byType(CachedNetworkImage));
    return image.errorWidget!(context, image.imageUrl, Exception('không có mạng'));
  }

  testWidgets('tải lỗi (ví dụ offline và ảnh chưa có trong cache): hiện biểu tượng ảnh hỏng', (tester) async {
    await pumpImage(tester, const RecipeImage(url: 'https://example.com/a.jpg', width: 120, height: 80));
    final error = buildError(tester);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: error)));
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    final box = tester.widget<Container>(find.byType(Container).first);
    expect(box.constraints?.maxWidth, 120); // giữ đúng kích thước, bố cục không nhảy
    expect(box.constraints?.maxHeight, 80);
  });

  testWidgets('tải lỗi nhưng có khung dự phòng riêng thì dùng khung đó', (tester) async {
    await pumpImage(
      tester,
      const RecipeImage(url: 'https://example.com/a.jpg', width: 64, height: 64, fallback: Icon(Icons.restaurant_menu)),
    );
    final error = buildError(tester);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: error)));
    expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });

  testWidgets('chưa chỉ định chiều cao: khung lỗi vẫn có chiều cao hợp lý', (tester) async {
    await pumpImage(tester, const RecipeImage(url: 'https://example.com/a.jpg', width: 200));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: buildError(tester))));
    final box = tester.widget<Container>(find.byType(Container).first);
    expect(box.constraints?.maxHeight, 100);
  });

  testWidgets('bo góc theo borderRadius', (tester) async {
    await pumpImage(
      tester,
      const RecipeImage(url: '', width: 64, height: 64, borderRadius: 12),
    );
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, BorderRadius.circular(12));
  });

  testWidgets('chiều rộng vô hạn (double.infinity) được chấp nhận', (tester) async {
    await pumpImage(tester, const RecipeImage(url: '', width: double.infinity, height: 100));
    expect(tester.takeException(), isNull);
  });
}
