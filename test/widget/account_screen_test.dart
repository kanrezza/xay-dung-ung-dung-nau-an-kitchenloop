import 'package:btl_ltdd/features/account/providers/profile_provider.dart';
import 'package:btl_ltdd/features/account/providers/theme_mode_provider.dart';
import 'package:btl_ltdd/features/account/view/account_screen.dart';
import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/providers/community_provider.dart';
import 'package:btl_ltdd/features/planner/data/planner_repository.dart';
import 'package:btl_ltdd/features/planner/providers/meal_plan_provider.dart';
import 'package:btl_ltdd/features/recipes/data/account_actions.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/community_fakes.dart';
import '../support/planner_fakes.dart';
import '../support/profile_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int signOutCalls;
  late int beforeSignOutCalls;
  late AccountActions actions;
  late FakeProfileRepository profile;
  late ThemeModeProvider themeMode;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    signOutCalls = 0;
    beforeSignOutCalls = 0;
    profile = FakeProfileRepository();
    themeMode = ThemeModeProvider();
    actions = AccountActions(
      emailGetter: () => 'an.nguyen@example.com',
      signOutCallback: () async => signOutCalls++,
      beforeSignOut: () async => beforeSignOutCalls++,
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final recipes = FirestoreRecipeRepository(firestore: FakeFirebaseFirestore(), auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path: 'assets/langs',
          fallbackLocale: const Locale('vi'),
          startLocale: const Locale('vi'),
          saveLocale: false,
          child: Builder(
            builder: (context) => MultiProvider(
              providers: [
                Provider<RecipeRepository>.value(value: recipes),
                ChangeNotifierProvider(create: (_) => RecipeListProvider(repository: recipes)),
                Provider<PlannerRepository>.value(value: FakePlannerRepository()),
                ChangeNotifierProvider(create: (ctx) => MealPlanProvider(repository: ctx.read<PlannerRepository>())),
                Provider<CommunityRepository>.value(value: FakeCommunityRepository()),
                ChangeNotifierProvider(create: (ctx) => CommunityProvider(repository: ctx.read<CommunityRepository>(), recipes: recipes)),
                ChangeNotifierProvider(create: (_) => ProfileProvider(repository: profile)),
                ChangeNotifierProvider.value(value: themeMode),
              ],
              child: Builder(
                builder: (inner) => MaterialApp(
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  locale: context.locale,
                  themeMode: inner.watch<ThemeModeProvider>().mode,
                  darkTheme: ThemeData(brightness: Brightness.dark),
                  home: AccountScreen(actions: actions, loginBuilder: (_) => const Scaffold(body: Text('MÀN HÌNH ĐĂNG NHẬP'))),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
  }

  testWidgets('hồ sơ: tên hiển thị, email, ảnh mặc định là chữ cái đầu', (tester) async {
    await pumpScreen(tester);
    expect(find.text('An Nguyễn'), findsOneWidget);
    expect(find.text('an.nguyen@example.com'), findsOneWidget);
    expect(find.text('AN'), findsOneWidget);
    expect(find.text('Tài khoản'), findsWidgets);
  });

  testWidgets('đổi tên hiển thị; tên không hợp lệ bị từ chối kèm lý do', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('edit_name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name_field')), 'Bếp của An');
    await tester.tap(find.byKey(const Key('name_save')));
    await settle(tester);
    expect(profile.profile.name, 'Bếp của An');
    expect(find.text('Bếp của An'), findsOneWidget);

    await tester.tap(find.byKey(const Key('edit_name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('name_field')), 'shop.vn giá rẻ');
    await tester.tap(find.byKey(const Key('name_save')));
    await settle(tester);
    expect(find.text('Tên không được chứa link hay từ ngữ không phù hợp.'), findsOneWidget);
    expect(profile.profile.name, 'Bếp của An');
  });

  testWidgets('bảng ảnh đại diện khi chưa có ảnh: thư viện, máy ảnh; không có "Xoá ảnh"', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('change_avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Ảnh đại diện'), findsOneWidget);
    expect(find.byKey(const Key('avatar_gallery')), findsOneWidget);
    expect(find.byKey(const Key('avatar_camera')), findsOneWidget);
    expect(find.byKey(const Key('avatar_remove')), findsNothing);
  });

  testWidgets('có ảnh đại diện: hiện ảnh; xoá ảnh thì về chữ cái đầu', (tester) async {
    profile = FakeProfileRepository(withPhoto: true);
    await pumpScreen(tester);
    expect(find.byKey(const Key('avatar_photo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('change_avatar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('avatar_remove')));
    await settle(tester);
    expect(profile.profile.hasAvatar, isFalse);
    expect(find.text('Đã xoá ảnh đại diện'), findsOneWidget);
    expect(find.byKey(const Key('avatar_initials')), findsOneWidget);
  });

  testWidgets('đổi ngôn ngữ sang English rồi về Tiếng Việt', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('lang_en')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsWidgets);
    expect(find.text('Log out'), findsWidgets);
    await tester.tap(find.byKey(const Key('lang_vi')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Đăng xuất'), findsWidgets);
  });

  testWidgets('chọn giao diện Tối: áp dụng ngay và được nhớ', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('theme_dark')));
    await settle(tester);
    expect(themeMode.mode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byKey(const Key('profile_name')))).brightness, Brightness.dark);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('đổi mật khẩu: xác nhận rồi gửi email đặt lại', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('change_password')));
    await tester.pumpAndSettle();
    expect(find.text('Gửi email đặt lại mật khẩu tới an.nguyen@example.com?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('password_send')));
    await settle(tester);
    expect(profile.resets, 1);
    expect(find.text('Đã gửi email đặt lại mật khẩu tới an.nguyen@example.com'), findsOneWidget);
  });

  testWidgets('đăng xuất: Huỷ thì ở lại; xác nhận thì huỷ hẹn giờ, đăng xuất, về đăng nhập', (tester) async {
    await pumpScreen(tester);
    await tester.ensureVisible(find.byKey(const Key('logout_button')));
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_cancel')));
    await tester.pumpAndSettle();
    expect(signOutCalls, 0);
    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('logout_confirm')));
    await tester.pumpAndSettle();
    expect([beforeSignOutCalls, signOutCalls], [1, 1]);
    expect(find.text('MÀN HÌNH ĐĂNG NHẬP'), findsOneWidget);
  });

  testWidgets('mục Quản trị chỉ hiện với quản trị viên (custom claim)', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('admin_entry')), findsNothing);
  });

  testWidgets('quản trị viên thấy mục Quản trị', (tester) async {
    actions = AccountActions(emailGetter: () => 'boss@example.com', signOutCallback: () async {}, adminChecker: () async => true);
    await pumpScreen(tester);
    expect(find.byKey(const Key('admin_entry')), findsOneWidget);
  });

  test('AccountActions: beforeSignOut chạy trước signOutCallback; isAdmin mặc định false', () async {
    final order = <String>[];
    final a = AccountActions(
      emailGetter: () => null,
      beforeSignOut: () async => order.add('before'),
      signOutCallback: () async => order.add('signOut'),
    );
    await a.signOut();
    expect(order, ['before', 'signOut']);
    expect(await a.isAdmin(), isFalse);
  });
}
