import 'package:btl_ltdd/features/recipes/data/account_actions.dart';
import 'package:btl_ltdd/features/recipes/view/account_menu_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var signOutCalls = 0;
  var beforeSignOutCalls = 0;
  late AccountActions actions;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    signOutCalls = 0;
    beforeSignOutCalls = 0;
    actions = AccountActions(
      emailGetter: () => 'an@example.com',
      signOutCallback: () async => signOutCalls++,
      beforeSignOut: () async => beforeSignOutCalls++,
    );
  });

  Future<void> pumpScreen(WidgetTester tester, {String startLocale = 'vi'}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path: 'assets/langs',
          fallbackLocale: const Locale('vi'),
          startLocale: Locale(startLocale),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: AccountMenuScreen(
                actions: actions,
                loginBuilder: (_) => const Scaffold(body: Text('MÀN HÌNH ĐĂNG NHẬP')),
              ),
            ),
          ),
        ),
      );
      // Chờ easy_localization nạp xong các file dịch từ asset.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('hiện email đang đăng nhập và tiêu đề tiếng Việt', (tester) async {
    await pumpScreen(tester);
    expect(find.text('an@example.com'), findsOneWidget);
    expect(find.text('Tài khoản'), findsWidgets);
  });

  testWidgets('đổi sang English rồi về Tiếng Việt, giao diện đổi ngay', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsWidgets);
    expect(find.text('Log out'), findsWidgets);

    await tester.tap(find.byKey(const Key('lang_vi')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản'), findsWidgets);
    expect(find.text('Đăng xuất'), findsWidgets);
  });

  testWidgets('đăng xuất có hộp thoại xác nhận; chọn Huỷ thì không đăng xuất', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('logout_confirm')), findsOneWidget);

    await tester.tap(find.byKey(const Key('logout_cancel')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 0);
    expect(find.text('MÀN HÌNH ĐĂNG NHẬP'), findsNothing);
  });

  testWidgets('xác nhận đăng xuất: gọi signOut, huỷ hẹn giờ trước đó, về màn hình đăng nhập', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();

    expect(beforeSignOutCalls, 1);
    expect(signOutCalls, 1);
    expect(find.text('MÀN HÌNH ĐĂNG NHẬP'), findsOneWidget);
  });

  test('AccountActions.signOut gọi beforeSignOut trước signOutCallback', () async {
    final order = <String>[];
    final a = AccountActions(
      emailGetter: () => null,
      beforeSignOut: () async => order.add('before'),
      signOutCallback: () async => order.add('signOut'),
    );
    await a.signOut();
    expect(order, ['before', 'signOut']);
    expect(a.email, isNull);
  });

  testWidgets('tài khoản thường: không có mục Quản trị', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('admin_entry')), findsNothing);
  });

  testWidgets('quản trị viên (custom claim): có mục Quản trị', (tester) async {
    actions = AccountActions(
      emailGetter: () => 'boss@example.com',
      signOutCallback: () async {},
      adminChecker: () async => true,
    );
    await pumpScreen(tester);
    expect(find.byKey(const Key('admin_entry')), findsOneWidget);
    expect(find.text('Quản trị'), findsOneWidget);
  });

  test('AccountActions.isAdmin mặc định false khi không có adminChecker', () async {
    final a = AccountActions(emailGetter: () => null, signOutCallback: () async {});
    expect(await a.isAdmin(), isFalse);
  });
}
