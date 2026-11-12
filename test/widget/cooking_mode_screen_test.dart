import 'package:btl_ltdd/features/recipes/data/cooking_session_store.dart';
import 'package:btl_ltdd/features/recipes/models/cooking_session.dart';
import 'package:btl_ltdd/features/recipes/providers/cooking_mode_provider.dart';
import 'package:btl_ltdd/features/recipes/view/cooking_mode_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cooking_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime clock;
  late FakeTimerNotifier notifier;
  late FakeScreenAwake awake;
  late CookingSessionStore store;
  late CookingModeProvider provider;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    clock = DateTime(2026, 6, 1, 12);
    notifier = FakeTimerNotifier();
    awake = FakeScreenAwake();
    SharedPreferences.setMockInitialValues({});
    store = CookingSessionStore(uidGetter: () => 'alice');
    provider = CookingModeProvider(
      recipe: cookingRecipe(),
      store: store,
      notifier: notifier,
      awake: awake,
      now: () => clock,
      timerTitle: (_) => 'Hết giờ!',
      timerBody: (step) => step.text,
    );
  });

  /// Mở màn hình nấu từ một trang gốc, để kiểm tra được cả việc đóng màn hình.
  Future<void> pumpScreen(WidgetTester tester, {bool expectDialog = false}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path: 'assets/langs',
          fallbackLocale: const Locale('vi'),
          startLocale: const Locale('vi'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_cooking'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChangeNotifierProvider<CookingModeProvider>.value(
                            value: provider,
                            child: const CookingModeScreen(),
                          ),
                        ),
                      ),
                      child: const Text('mở'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_cooking')));
    if (expectDialog) {
      // Hộp thoại "tiếp tục" mở trên nền có vòng quay tải chạy mãi nên không dùng pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    } else {
      await tester.pumpAndSettle();
    }
  }

  /// Gỡ cây widget để dừng bộ đếm của provider trước khi test kết thúc.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  }

  Finder stepText(String text) => find.text(text);

  testWidgets('hiện "Bước 1 / 3", nội dung bước bằng chữ lớn và thanh tiến độ', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Bước 1 / 3'), findsOneWidget);
    final text = tester.widget<Text>(stepText('Sơ chế nguyên liệu'));
    expect(text.style!.fontSize, greaterThanOrEqualTo(24));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(provider.isActive, isTrue);
    expect(awake.enabled, isTrue);
    await closeApp(tester);
  });

  testWidgets('nút Trước bị vô hiệu ở bước 1', (tester) async {
    await pumpScreen(tester);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('cook_prev'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('cook_prev'))).onPressed, isNotNull);
    await closeApp(tester);
  });

  testWidgets('nút Tiếp thành "Hoàn thành" ở bước cuối', (tester) async {
    await pumpScreen(tester);
    expect(find.descendant(of: find.byKey(const Key('cook_next')), matching: find.text('Tiếp')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    expect(find.text('Bước 3 / 3'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cook_next')), matching: find.text('Hoàn thành')), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('vuốt trái/phải đổi bước', (tester) async {
    await pumpScreen(tester);
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Bước 2 / 3'), findsOneWidget);
    expect(provider.stepIndex, 1);

    await tester.fling(find.byType(PageView), const Offset(500, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Bước 1 / 3'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('chip hẹn giờ chỉ hiện với bước có thời gian', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('step_timer_chip')), findsNothing); // bước 1: không có thời gian
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('step_timer_chip')), findsOneWidget); // bước 2: 2 phút
    expect(find.text('2:00'), findsWidgets);
    await closeApp(tester);
  });

  testWidgets('bắt đầu → tạm dừng → tiếp tục → đặt lại hẹn giờ', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();
    expect(notifier.scheduled, hasLength(1));
    expect(find.text('Tạm dừng'), findsOneWidget);

    clock = clock.add(const Duration(seconds: 30));
    provider.onTick();
    await tester.pump();
    expect(find.text('1:30'), findsWidgets);

    await tester.tap(find.text('Tạm dừng'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(notifier.cancelled, hasLength(1));

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(notifier.scheduled, hasLength(2));

    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu hẹn giờ'), findsOneWidget);
    expect(find.text('2:00'), findsWidgets);
    await closeApp(tester);
  });

  testWidgets('hết giờ: hiện cảnh báo trong app, bấm Đóng để tắt', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();

    clock = clock.add(const Duration(seconds: 121));
    provider.onTick();
    await tester.pump();
    expect(find.text('Hết giờ! Bước 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dismiss_alarm_s2')));
    await tester.pumpAndSettle();
    expect(find.text('Hết giờ! Bước 2'), findsNothing);
    await closeApp(tester);
  });

  testWidgets('hẹn giờ đang chạy hiện ở thanh trên cùng kể cả khi sang bước khác', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_prev')));
    await tester.pumpAndSettle();

    expect(find.text('Bước 1 / 3'), findsOneWidget);
    expect(find.byKey(const Key('running_timer_s2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('running_timer_s2'))); // bấm để nhảy tới bước đó
    await tester.pumpAndSettle();
    expect(find.text('Bước 2 / 3'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('đổi khẩu phần trong ngăn kéo: số lượng nguyên liệu quy đổi tức thì và được lưu', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await tester.pumpAndSettle();
    expect(find.text('200 g thịt'), findsOneWidget); // 2 người

    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    expect(provider.servings, 4);
    expect(find.text('400 g thịt'), findsOneWidget);
    expect(find.text('8 quả trứng'), findsOneWidget);

    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect((await tester.runAsync(() => store.load('r1')))!.servings, 4);
    await closeApp(tester);
  });

  testWidgets('ngăn kéo bắt đầu với khẩu phần đã chọn trước đó', (tester) async {
    provider = CookingModeProvider(
      recipe: cookingRecipe(),
      store: store,
      notifier: notifier,
      awake: awake,
      now: () => clock,
      timerTitle: (_) => 'Hết giờ!',
      timerBody: (step) => step.text,
      initialServings: 6,
    );
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await tester.pumpAndSettle();
    expect(find.text('600 g thịt'), findsOneWidget);
    expect(find.text('12 quả trứng'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('nhập khẩu phần không hợp lệ trong ngăn kéo bị từ chối', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();
    expect(provider.servings, 2);
    expect(find.text('200 g thịt'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('ngăn kéo nguyên liệu', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await tester.pumpAndSettle();
    expect(find.text('200 g thịt'), findsOneWidget);
    expect(find.text('4 quả trứng'), findsOneWidget);
    await closeApp(tester);
  });

  group('phiên nấu dở', () {
    Future<void> saveSession({int stepIndex = 1}) => store.save(CookingSession(
          recipeId: 'r1',
          stepIndex: stepIndex,
          servings: 3,
          startedAt: clock,
          timers: [StepTimer(stepId: 's2', totalSec: 120, endAt: clock.add(const Duration(seconds: 90)), notificationId: 77)],
        ));

    testWidgets('hỏi tiếp tục hay bắt đầu lại; chọn tiếp tục thì vào đúng bước', (tester) async {
      await tester.runAsync(() => saveSession());
      await pumpScreen(tester, expectDialog: true);
      expect(find.text('Tiếp tục từ bước 2'), findsOneWidget);
      expect(find.text('Bắt đầu lại'), findsOneWidget);

      await tester.tap(find.text('Tiếp tục từ bước 2'));
      await tester.pumpAndSettle();
      expect(find.text('Bước 2 / 3'), findsOneWidget);
      expect(provider.servings, 3);
      expect(provider.stateOf('s2'), TimerState.running);
      await closeApp(tester);
    });

    testWidgets('chọn bắt đầu lại: về bước 1, huỷ thông báo cũ, xoá phiên', (tester) async {
      await tester.runAsync(() => saveSession());
      await pumpScreen(tester, expectDialog: true);
      await tester.tap(find.text('Bắt đầu lại'));
      await tester.pumpAndSettle();

      expect(find.text('Bước 1 / 3'), findsOneWidget);
      expect(notifier.cancelled, [77]);
      expect(provider.activeTimers, isEmpty);
      expect(await tester.runAsync(() => store.load('r1')), isNull);
      await closeApp(tester);
    });

    testWidgets('không hỏi khi chưa có phiên dở', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Bắt đầu lại'), findsNothing);
      expect(find.text('Bước 1 / 3'), findsOneWidget);
      await closeApp(tester);
    });
  });

  testWidgets('bấm Hoàn thành ở bước cuối: báo nấu xong rồi đóng màn hình, xoá phiên', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_next'))); // Hoàn thành
    await tester.pumpAndSettle();
    expect(find.text('Nấu xong rồi!'), findsOneWidget);

    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('open_cooking')), findsOneWidget); // đã về trang gốc
    expect(provider.isFinished, isTrue);
    expect(awake.enabled, isFalse);
    // Các thao tác lưu trữ cần thời gian thực để hoàn tất.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(await tester.runAsync(() => store.load('r1')), isNull);
    await closeApp(tester);
  });

  testWidgets('xuống nền tắt giữ màn hình sáng, quay lại bật lại, không huỷ thông báo', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await tester.pumpAndSettle();
    expect(awake.enabled, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(awake.enabled, isFalse);
    expect(notifier.cancelled, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(awake.enabled, isTrue);
    await closeApp(tester);
  });
}
