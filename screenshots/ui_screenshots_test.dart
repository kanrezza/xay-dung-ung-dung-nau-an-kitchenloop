// Bộ chụp ảnh giao diện KitchenLoop với dữ liệu mẫu.
//
// Chạy:  flutter test screenshots/ui_screenshots_test.dart
// Ảnh:   screenshots/out/*.png
//
// Dựng các màn hình THẬT của app (cùng theme, cùng widget) trong môi trường test
// của Flutter, với Firestore giả, tài khoản giả và font Roboto/Material Icons thật
// lấy từ Flutter SDK. Không cần thiết bị, không cần đăng nhập Firebase thật.
// Màn hình đăng nhập không có ở đây vì nó cần Firebase thật để khởi tạo.
//
// Bộ chụp nằm ngoài thư mục test/ nên cần cho phép dùng các hàm chỉ-dành-cho-test.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:btl_ltdd/app_theme.dart';
import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:btl_ltdd/features/admin/view/admin_screen.dart';
import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/community/providers/community_provider.dart';
import 'package:btl_ltdd/features/community/view/admin_community_tab.dart';
import 'package:btl_ltdd/features/account/providers/profile_provider.dart';
import 'package:btl_ltdd/features/account/providers/theme_mode_provider.dart';
import 'package:btl_ltdd/features/home/view/app_shell.dart';
import 'package:btl_ltdd/features/home/view/shell_destination.dart';
import 'package:btl_ltdd/features/planner/data/planner_repository.dart';
import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';
import 'package:btl_ltdd/features/planner/providers/meal_plan_provider.dart';
import 'package:btl_ltdd/features/planner/providers/shopping_provider.dart';
import 'package:btl_ltdd/features/recipes/data/account_actions.dart';
import 'package:btl_ltdd/features/recipes/data/cooking_session_store.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/data/screen_awake.dart';
import 'package:btl_ltdd/features/recipes/data/timer_notifier.dart';
import 'package:btl_ltdd/features/recipes/models/cooking_session.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/providers/cooking_mode_provider.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_editor_provider.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:btl_ltdd/features/recipes/view/cooking_mode_screen.dart';
import 'package:btl_ltdd/features/recipes/view/recipe_detail_screen.dart';
import 'package:btl_ltdd/features/recipes/view/recipe_editor_screen.dart';
import 'package:btl_ltdd/features/recipes/view/recipe_list_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/cooking_fakes.dart';
import '../test/support/community_fakes.dart';
import '../test/support/planner_fakes.dart';
import '../test/support/profile_fakes.dart';

const _outDir = 'screenshots/out';
final _shotKey = GlobalKey();

// ------------------------------------------------------------------ font thật

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> font(String name) async => ByteData.sublistView(await File('$dir/$name').readAsBytes());

  final roboto = FontLoader('Roboto')
    ..addFont(font('Roboto-Regular.ttf'))
    ..addFont(font('Roboto-Medium.ttf'))
    ..addFont(font('Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(font('MaterialIcons-Regular.otf'));
  await icons.load();
}

// ----------------------------------------------------------------- dữ liệu mẫu

Map<String, dynamic> _ing(String id, String name, [double? q, String? unit]) =>
    {'id': id, 'name': name, 'quantity': q, 'unit': unit, 'isPlaceholder': false};

Map<String, dynamic> _step(String id, int order, String text, [int? sec]) =>
    {'id': id, 'order': order, 'text': text, 'durationSec': sec, 'isPlaceholder': false};

final Map<String, Map<String, dynamic>> _sampleRecipes = {
  'thit-kho': {
    'title': 'Thịt kho trứng',
    'baseServings': 4,
    'note': 'Kho lửa nhỏ để thịt mềm và thấm. Ngon hơn khi để qua đêm.',
    'tags': ['cơm nhà', 'món mặn'],
    'ingredients': [
      _ing('a1', 'thịt ba chỉ', 500, 'g'),
      _ing('a2', 'trứng vịt', 6, 'quả'),
      _ing('a3', 'nước dừa', 400, 'ml'),
      _ing('a4', 'nước mắm', 3, 'muỗng canh'),
      _ing('a5', 'đường', 2, 'muỗng canh'),
      _ing('a6', 'tỏi băm', 3, 'tép'),
      _ing('a7', 'tiêu xay vừa đủ'),
    ],
    'steps': [
      _step('b1', 1, 'Luộc trứng khoảng 10 phút, ngâm nước lạnh rồi bóc vỏ.', 600),
      _step('b2', 2, 'Thịt cắt miếng vừa ăn, ướp với nước mắm, đường và tỏi trong 20 phút.', 1200),
      _step('b3', 3, 'Thắng đường lấy màu, cho thịt vào đảo đến khi săn lại.'),
      _step('b4', 4, 'Đổ nước dừa, cho trứng vào, kho lửa nhỏ khoảng 45 phút.', 2700),
      _step('b5', 5, 'Nêm lại cho vừa ăn, rắc tiêu rồi tắt bếp.'),
    ],
  },
  'ga-ran': {
    'title': 'Gà rán giòn',
    'baseServings': 2,
    'tags': ['món sinh viên', 'nhanh'],
    'ingredients': [_ing('c1', 'đùi gà', 4, 'cái'), _ing('c2', 'bột chiên giòn', 150, 'g'), _ing('c3', 'dầu ăn', 500, 'ml')],
    'steps': [_step('d1', 1, 'Ướp gà với muối tiêu.', 900), _step('d2', 2, 'Lăn bột rồi chiên ngập dầu.', 720)],
  },
  'canh-chua': {
    'title': 'Canh chua cá lóc',
    'baseServings': 4,
    'tags': ['ăn kiêng', 'cơm nhà'],
    'ingredients': [_ing('e1', 'cá lóc', 1, 'con'), _ing('e2', 'me chua', 50, 'g'), _ing('e3', 'cà chua', 2, 'quả'), _ing('e4', 'giá đỗ', 100, 'g')],
    'steps': [_step('f1', 1, 'Nấu nước me lọc lấy nước chua.'), _step('f2', 2, 'Cho cá vào nấu chín, thêm rau.', 600)],
  },
  'trung-chien': {
    'title': 'Trứng chiên hành',
    'baseServings': 1,
    'tags': ['món sinh viên', 'nhanh'],
    'ingredients': [_ing('g1', 'trứng gà', 2, 'quả'), _ing('g2', 'hành lá', 1, 'nhánh')],
    'steps': [_step('h1', 1, 'Đánh trứng với hành rồi chiên vàng hai mặt.', 300)],
  },
  'pho-bo': {
    'title': 'Phở bò',
    'baseServings': 6,
    'tags': ['cuối tuần'],
    'ingredients': [_ing('i1', 'xương ống bò', 2, 'kg'), _ing('i2', 'bánh phở', 1, 'kg'), _ing('i3', 'thịt bò tái', 500, 'g')],
    'steps': [_step('j1', 1, 'Hầm xương lấy nước dùng.', 10800), _step('j2', 2, 'Trụng bánh phở, xếp thịt, chan nước dùng.')],
  },
  'salad': {
    'title': 'Salad ức gà',
    'baseServings': 2,
    'tags': ['ăn kiêng', 'nhanh'],
    'ingredients': [_ing('k1', 'ức gà', 300, 'g'), _ing('k2', 'xà lách', 1, 'cây'), _ing('k3', 'dầu ô liu', 2, 'muỗng canh')],
    'steps': [_step('l1', 1, 'Luộc ức gà rồi xé nhỏ.', 900), _step('l2', 2, 'Trộn với rau và sốt.')],
  },
};

Future<void> _seed(FakeFirebaseFirestore db) async {
  var minutesAgo = 0;
  for (final entry in _sampleRecipes.entries) {
    await db.collection('recipes').doc(entry.key).set({
      ...entry.value,
      'ownerId': 'alice',
      'imageUrl': '',
      'schemaVersion': 1,
      'createdAt': DateTime(2026, 11, 1),
      'updatedAt': DateTime(2026, 11, 12, 12).subtract(Duration(minutes: minutesAgo += 30)),
    });
  }
}

Recipe _recipeOf(String id) => Recipe.fromMap({..._sampleRecipes[id]!, 'ownerId': 'alice'}, id);

// --------------------------------------------------------------------- khung chụp

class _Env {
  _Env() {
    db = FakeFirebaseFirestore();
    repo = FirestoreRecipeRepository(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', email: 'an.nguyen@example.com')),
    );
  }

  late final FakeFirebaseFirestore db;
  late final FirestoreRecipeRepository repo;
  late final admin = FirestoreAdminRepository(
    firestore: db,
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', customClaim: {'admin': true})),
  );
  final store = CookingSessionStore(uidGetter: () => 'alice');
  final notifier = FakeTimerNotifier();
  final awake = FakeScreenAwake();
  final account = AccountActions(emailGetter: () => 'an.nguyen@example.com', signOutCallback: () async {});
  final planner = FakePlannerRepository();
  final community = FakeCommunityRepository(now: () => _now);
}

/// "Bây giờ" cố định cho ảnh chụp: thứ 4, 11/11/2026 lúc 18 giờ (bữa tối, tuần 9/11).
final _now = DateTime(2026, 11, 11, 18);
final _week = DateTime(2026, 11, 9);

Future<void> _pump(WidgetTester tester, _Env env, Widget home, {String locale = 'vi', Brightness brightness = Brightness.light}) async {
  // flutter_test mặc định vẽ bóng đổ thành viền đen (debugDisableShadows); bật lại bóng thật
  // để ảnh giống trên điện thoại. _capture trả lại giá trị cũ ngay sau khi chụp.
  debugDisableShadows = false;
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.runAsync(() async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('vi'), Locale('en')],
        path: 'assets/langs',
        fallbackLocale: const Locale('vi'),
        startLocale: Locale(locale),
        saveLocale: false,
        child: Builder(
          builder: (context) => MultiProvider(
            providers: [
              Provider<RecipeRepository>.value(value: env.repo),
              ChangeNotifierProvider(create: (_) => RecipeListProvider(repository: env.repo)),
              Provider<AccountActions>.value(value: env.account),
              Provider<AdminRepository>.value(value: env.admin),
              Provider<CookingSessionStore>.value(value: env.store),
              Provider<TimerNotifier>.value(value: env.notifier),
              Provider<ScreenAwake>.value(value: env.awake),
              Provider<CommunityRepository>.value(value: env.community),
              ChangeNotifierProvider(create: (_) => CommunityProvider(repository: env.community, recipes: env.repo)),
              Provider<PlannerRepository>.value(value: env.planner),
              ChangeNotifierProvider(create: (_) => ProfileProvider(repository: FakeProfileRepository())),
              ChangeNotifierProvider(create: (_) => ThemeModeProvider()),
              ChangeNotifierProvider(create: (_) => MealPlanProvider(repository: env.planner, now: () => _now)),
              ChangeNotifierProxyProvider<MealPlanProvider, ShoppingProvider>(
                create: (_) => ShoppingProvider(repository: env.planner),
                update: (_, plan, shop) => shop!..attachWeek(plan.weekStart),
              ),
            ],
            child: RepaintBoundary(
              key: _shotKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(brightness: brightness),
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: home,
              ),
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _settle(tester);
}

/// Xen kẽ thời gian thực (cho luồng dữ liệu) và đồng hồ giả (cho khung hình).
Future<void> _settle(WidgetTester tester, {int rounds = 6}) async {
  await tester.runAsync(() => tester.pump());
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_outDir).create(recursive: true);
    await File('$_outDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
  // Trả lại trước khi test kết thúc (flutter_test kiểm tra cờ này ngay sau thân test).
  debugDisableShadows = true;
}

CookingModeProvider _cooking(_Env env, String recipeId, DateTime Function() now) => CookingModeProvider(
      recipe: _recipeOf(recipeId),
      store: env.store,
      notifier: env.notifier,
      awake: env.awake,
      now: now,
      tickInterval: const Duration(days: 1),
      timerTitle: (_) => 'Hết giờ!',
      timerBody: (step) => step.text,
    );

Future<void> _closeCooking(WidgetTester tester, CookingModeProvider p) async {
  await tester.pumpWidget(const SizedBox.shrink());
  p.dispose();
}

// ------------------------------------------------------------------------ ảnh

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await _loadFonts();
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget list() => const RecipeListScreen();

  testWidgets('01 danh sách công thức', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, list());
    await _capture(tester, '01_danh_sach');
  });

  testWidgets('02 lọc theo thẻ', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, list());
    await tester.ensureVisible(find.byKey(const Key('tag_chip_mon sinh vien')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await _settle(tester);
    await _capture(tester, '02_loc_theo_the');
  });

  testWidgets('03 tìm không dấu', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, list());
    await tester.enterText(find.byKey(const Key('search_field')), 'ga');
    await _settle(tester);
    await _capture(tester, '03_tim_khong_dau');
  });

  testWidgets('04 không có kết quả', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, list());
    await tester.enterText(find.byKey(const Key('search_field')), 'sushi');
    await _settle(tester);
    await _capture(tester, '04_khong_ket_qua');
  });

  testWidgets('05 danh sách trống', (tester) async {
    final env = _Env();
    await _pump(tester, env, list());
    await _capture(tester, '05_danh_sach_trong');
  });

  testWidgets('06 chi tiết công thức', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, const RecipeDetailScreen(recipeId: 'thit-kho'));
    await _capture(tester, '06_chi_tiet');
  });

  testWidgets('07 đổi khẩu phần', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, const RecipeDetailScreen(recipeId: 'thit-kho'));
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    // Màn chi tiết cuộn bằng CustomScrollView (ảnh bìa + nội dung).
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -620));
    await _settle(tester);
    await _capture(tester, '07_doi_khau_phan');
  });

  testWidgets('08 soạn thảo công thức', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(
      tester,
      env,
      ChangeNotifierProvider(
        create: (_) => RecipeEditorProvider(repository: env.repo, existing: _recipeOf('thit-kho')),
        child: const RecipeEditorScreen(tagSuggestions: ['món sinh viên', 'nhanh', 'ăn kiêng']),
      ),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await _settle(tester);
    await _capture(tester, '08_soan_thao');
  });

  testWidgets('09 soạn thảo báo lỗi', (tester) async {
    final env = _Env();
    await _pump(
      tester,
      env,
      ChangeNotifierProvider(
        create: (_) => RecipeEditorProvider(repository: env.repo),
        child: const RecipeEditorScreen(),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Tên nguyên liệu'), 'trứng');
    await tester.enterText(find.widgetWithText(TextField, 'Số lượng'), 'abc');
    await tester.tap(find.byKey(const Key('save_recipe')));
    await _settle(tester);
    await _capture(tester, '09_soan_thao_bao_loi');
  });

  testWidgets('10 chế độ nấu với hẹn giờ', (tester) async {
    final env = _Env();
    var clock = DateTime(2026, 11, 12, 18);
    final p = _cooking(env, 'thit-kho', () => clock);
    await _pump(tester, env, ChangeNotifierProvider<CookingModeProvider>.value(value: p, child: const CookingModeScreen()));
    await tester.tap(find.byKey(const Key('cook_next')));
    await _settle(tester);
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await _settle(tester);
    clock = clock.add(const Duration(minutes: 7, seconds: 25));
    p.onTick();
    await _settle(tester);
    await _capture(tester, '10_che_do_nau');
    await _closeCooking(tester, p);
  });

  testWidgets('11 hết giờ', (tester) async {
    final env = _Env();
    var clock = DateTime(2026, 11, 12, 18);
    final p = _cooking(env, 'thit-kho', () => clock);
    await _pump(tester, env, ChangeNotifierProvider<CookingModeProvider>.value(value: p, child: const CookingModeScreen()));
    await tester.tap(find.text('Bắt đầu hẹn giờ'));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('cook_next')));
    await _settle(tester);
    clock = clock.add(const Duration(minutes: 11));
    p.onTick();
    await _settle(tester);
    await _capture(tester, '11_het_gio');
    await _closeCooking(tester, p);
  });

  testWidgets('12 nguyên liệu khi đang nấu', (tester) async {
    final env = _Env();
    final p = _cooking(env, 'thit-kho', () => DateTime(2026, 11, 12, 18));
    await _pump(tester, env, ChangeNotifierProvider<CookingModeProvider>.value(value: p, child: const CookingModeScreen()));
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('servings_plus')));
    await _settle(tester);
    await _capture(tester, '12_nguyen_lieu_khi_nau');
    await _closeCooking(tester, p);
  });

  testWidgets('13 tiếp tục nấu dở', (tester) async {
    final env = _Env();
    await tester.runAsync(() => env.store.save(CookingSession(
          recipeId: 'thit-kho',
          stepIndex: 3,
          servings: 4,
          startedAt: DateTime(2026, 11, 12, 17),
        )));
    final p = _cooking(env, 'thit-kho', () => DateTime(2026, 11, 12, 18));
    await _pump(tester, env, ChangeNotifierProvider<CookingModeProvider>.value(value: p, child: const CookingModeScreen()));
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, '13_tiep_tuc_nau_do');
    await _closeCooking(tester, p);
  });

  testWidgets('14 nấu xong', (tester) async {
    final env = _Env();
    final p = _cooking(env, 'trung-chien', () => DateTime(2026, 11, 12, 18));
    await _pump(tester, env, ChangeNotifierProvider<CookingModeProvider>.value(value: p, child: const CookingModeScreen()));
    await tester.tap(find.byKey(const Key('cook_next')));
    await _settle(tester);
    await _capture(tester, '14_nau_xong');
    await _closeCooking(tester, p);
  });

  testWidgets('15 tài khoản', (tester) async {
    final env = _Env();
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold(), initial: ShellDestination.account));
    await tester.pumpAndSettle();
    await _capture(tester, '15_tai_khoan');
  });

  testWidgets('18 quản trị', (tester) async {
    final env = _Env();
    final now = DateTime(2026, 11, 14);
    Future<void> user(String id, String name, String email, int daysAgo, {bool locked = false}) =>
        env.db.collection('users').doc(id).set({
          'name': name,
          'email': email,
          'createdAt': now.subtract(Duration(days: daysAgo)), // fake_cloud_firestore lưu thành Timestamp
          'isLocked': locked,
        });
    await user('alice', 'An Nguyễn', 'an.nguyen@example.com', 120);
    await user('u2', 'Bình Trần', 'binh.tran@example.com', 2);
    await user('u3', 'Chi Lê', 'chi.le@example.com', 30, locked: true);
    await user('u4', 'Dũng Phạm', 'dung.pham@example.com', 5);
    await user('u5', 'Em Võ', 'em.vo@example.com', 60);
    await user('u6', '', 'tai.khoan.cu@example.com', 400);
    await _pump(tester, env, AdminScreen(now: () => now));
    await _capture(tester, '18_quan_tri');
  });

  /// Thực đơn mẫu cho tuần 9/11: vài bữa trong tuần, hôm nay (thứ 4) có bữa trưa và tối.
  void seedPlan(_Env env) {
    MealEntry e(String id, int day, MealSlot slot, String recipeId, String title, int servings) =>
        MealEntry(id: id, day: day, slot: slot, recipeId: recipeId, title: title, servings: servings);
    env.planner.weeks[_week] = WeekPlan(weekStart: _week, entries: [
      e('m1', 0, MealSlot.dinner, 'canh-chua', 'Canh chua cá lóc', 4),
      e('m2', 1, MealSlot.breakfast, 'trung-chien', 'Trứng chiên hành', 2),
      e('m3', 2, MealSlot.lunch, 'salad', 'Salad ức gà', 2),
      e('m4', 2, MealSlot.dinner, 'thit-kho', 'Thịt kho trứng', 4),
      e('m5', 4, MealSlot.dinner, 'ga-ran', 'Gà rán giòn', 2),
      e('m6', 6, MealSlot.lunch, 'pho-bo', 'Phở bò', 6),
    ]);
    env.planner.shopping[_week] = const ShoppingState(checked: {'nuoc mam|muỗng canh', 'trung vit|quả'});
  }

  Future<void> settleShell(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('19 trang chủ', (tester) async {
    final env = _Env();
    await _seed(env.db);
    seedPlan(env);
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold()));
    await settleShell(tester);
    await _capture(tester, '19_trang_chu');
  });

  testWidgets('20 thực đơn tuần', (tester) async {
    final env = _Env();
    await _seed(env.db);
    seedPlan(env);
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold(), initial: ShellDestination.planner));
    await settleShell(tester);
    await _capture(tester, '20_thuc_don_tuan');
  });

  testWidgets('21 đi chợ', (tester) async {
    final env = _Env();
    await _seed(env.db);
    seedPlan(env);
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold(), initial: ShellDestination.shopping));
    await settleShell(tester);
    await _capture(tester, '21_di_cho');
  });

  testWidgets('22 chế độ tối', (tester) async {
    final env = _Env();
    await _seed(env.db);
    seedPlan(env);
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold(), initial: ShellDestination.recipes), brightness: Brightness.dark);
    await settleShell(tester);
    await _capture(tester, '22_che_do_toi');
  });

  /// Bài cộng đồng mẫu: vài bài của người khác, một bài của mình, một bài bị ẩn do báo cáo.
  void seedCommunity(_Env env) {
    Map<String, dynamic> post(String author, String name, String title, int day, {String status = 'visible', int reports = 0, int secs = 600}) => {
          'authorId': author,
          'authorName': name,
          'sourceRecipeId': title,
          'title': title,
          'note': '',
          'baseServings': 2,
          'ingredients': [_ing('a', 'nguyên liệu chính', 300, 'g'), _ing('b', 'gia vị', 1, 'muỗng canh')],
          'steps': [_step('s1', 1, 'Sơ chế nguyên liệu sạch sẽ.', secs), _step('s2', 2, 'Nấu chín và nêm vừa ăn.')],
          'tags': <String>[],
          'status': status,
          'reportCount': reports,
          'createdAt': DateTime(2026, 11, day, 9),
        };
    void add(String id, Map<String, dynamic> m) => env.community.posts[id] = CommunityPost.fromMap(id, m);
    add('b1', post('u2', 'Bình Trần', 'Bún bò Huế', 11, secs: 7200));
    add('b2', post('u3', 'Chi Lê', 'Gỏi cuốn tôm thịt', 10, secs: 1200));
    add('b3', post('alice', 'An Nguyễn', 'Thịt kho trứng', 9, secs: 4500));
    add('b4', post('u4', 'Dũng Phạm', 'Cá kho tộ', 8, secs: 3600));
    add('b5', post('u5', 'Em Võ', 'Chè đậu xanh', 6, secs: 2400));
    add('b6', post('u6', 'Tài khoản lạ', 'Món ngon khó cưỡng', 11, status: 'hidden', reports: 3));
    env.community.reports['b6'] = const [
      PostReport(reporterId: 'x', reason: ReportReason.notRecipe),
      PostReport(reporterId: 'y', reason: ReportReason.spam),
    ];
  }

  testWidgets('23 cộng đồng', (tester) async {
    final env = _Env();
    await _seed(env.db);
    seedCommunity(env);
    await _pump(tester, env, AppShell(loginBuilder: (_) => const Scaffold(), initial: ShellDestination.community));
    await settleShell(tester);
    await _capture(tester, '23_cong_dong');
  });

  testWidgets('24 quản trị cộng đồng', (tester) async {
    final env = _Env();
    seedCommunity(env);
    await _pump(tester, env, Scaffold(appBar: AppBar(title: const Text('Quản trị · Cộng đồng')), body: AdminCommunityTab(now: () => _now)));
    await settleShell(tester);
    await _capture(tester, '24_quan_tri_cong_dong');
  });

  testWidgets('16 danh sách bằng tiếng Anh', (tester) async {
    final env = _Env();
    await _seed(env.db);
    await _pump(tester, env, list(), locale: 'en');
    await _capture(tester, '16_danh_sach_tieng_anh');
  });

  testWidgets('17 công thức chuyển từ dữ liệu cũ', (tester) async {
    final env = _Env();
    await env.db.collection('recipes').doc('cu').set({
      'ownerId': 'alice',
      'title': 'Bò kho bánh mì',
      'baseServings': 4,
      'imageUrl': '',
      'tags': ['món cũ'],
      'ingredients': [
        _ing('m0', 'thịt bò nạm', 1, 'kg'),
        _ing('m1', 'sả', 3, 'cây'),
        {'id': 'm2', 'name': 'gia vị bò kho vừa đủ', 'isPlaceholder': false},
      ],
      'steps': [_step('n0', 1, 'Ướp thịt với gia vị.', 1800), _step('n1', 2, 'Hầm lửa nhỏ đến khi mềm.', 5400)],
      'schemaVersion': 1,
      'legacy': {
        'title': 'Bò kho bánh mì',
        'ingredients': ['1kg thịt bò nạm', '3 cây sả', 'gia vị bò kho vừa đủ'],
        'instructions': '1. Ướp thịt với gia vị\n2. Hầm lửa nhỏ đến khi mềm',
        'sourceCollection': 'foods',
        'extra': {'time': '2 giờ', 'difficulty': 'Trung bình'},
      },
    });
    await _pump(tester, env, const RecipeDetailScreen(recipeId: 'cu'));
    final page = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('legacy_section')), 300, scrollable: page);
    await tester.tap(find.byKey(const Key('legacy_section')));
    await _settle(tester);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -400));
    await _settle(tester);
    await _capture(tester, '17_noi_dung_goc');
  });

  // Bảng tổng hợp: xếp các ảnh đã chụp thành lưới 3 cột kèm chú thích (chạy sau cùng).
  testWidgets('00 bảng tổng hợp', (tester) async {
    const captions = {
      '01_danh_sach': 'Danh sách công thức',
      '02_loc_theo_the': 'Lọc theo thẻ',
      '03_tim_khong_dau': 'Tìm không dấu: "ga" ra "gà"',
      '04_khong_ket_qua': 'Không có kết quả',
      '05_danh_sach_trong': 'Danh sách trống',
      '06_chi_tiet': 'Chi tiết công thức',
      '07_doi_khau_phan': 'Đổi khẩu phần từ 4 lên 6 người',
      '08_soan_thao': 'Sửa công thức, gợi ý thẻ',
      '09_soan_thao_bao_loi': 'Báo lỗi khi lưu',
      '10_che_do_nau': 'Chế độ nấu, hẹn giờ đang chạy',
      '11_het_gio': 'Cảnh báo hết giờ',
      '12_nguyen_lieu_khi_nau': 'Nguyên liệu khi nấu (6 người)',
      '13_tiep_tuc_nau_do': 'Tiếp tục nấu dở',
      '14_nau_xong': 'Nấu xong',
      '15_tai_khoan': 'Tài khoản',
      '16_danh_sach_tieng_anh': 'Giao diện tiếng Anh',
      '17_noi_dung_goc': 'Công thức chuyển từ dữ liệu cũ',
      '18_quan_tri': 'Quản trị (chỉ tài khoản admin)',
      '19_trang_chu': 'Trang chủ',
      '20_thuc_don_tuan': 'Thực đơn tuần',
      '21_di_cho': 'Đi chợ (tự gộp nguyên liệu)',
      '22_che_do_toi': 'Chế độ tối',
      '23_cong_dong': 'Cộng đồng (đã kiểm duyệt)',
      '24_quan_tri_cong_dong': 'Quản trị: thống kê, hàng chờ duyệt',
    };
    final names = captions.keys.where((n) => File('$_outDir/$n.png').existsSync()).toList();
    final images = <String, ui.Image>{};
    await tester.runAsync(() async {
      for (final n in names) {
        final codec = await ui.instantiateImageCodec(await File('$_outDir/$n.png').readAsBytes());
        images[n] = (await codec.getNextFrame()).image;
      }
    });

    const cols = 3;
    const tileW = 300.0;
    const tileH = 650.0;
    const perSheet = 9;
    for (var sheet = 0; sheet * perSheet < names.length; sheet++) {
      final part = names.skip(sheet * perSheet).take(perSheet).toList();
      final rows = (part.length / cols).ceil();
      tester.view.physicalSize = Size(cols * (tileW + 24) + 24, rows * (tileH + 64) + 90);
      tester.view.devicePixelRatio = 1.0;
      debugDisableShadows = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _shotKey,
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Container(
              color: const Color(0xFFF2F0F4),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    child: Text(
                      'KitchenLoop — giao diện (${sheet + 1}/${(names.length / perSheet).ceil()}) · dữ liệu mẫu',
                      style: const TextStyle(fontFamily: 'Roboto', fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1D1B20)),
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final n in part)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: tileW,
                            child: Column(
                              children: [
                                Container(
                                  width: tileW,
                                  height: tileH,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFFFF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFCAC4D0)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: RawImage(image: images[n], fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${n.substring(0, 2)}. ${captions[n]}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontFamily: 'Roboto', fontSize: 17, color: Color(0xFF1D1B20)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$_outDir/00_tong_hop_${sheet + 1}.png').writeAsBytes(bytes!.buffer.asUint8List());
      });
      debugDisableShadows = true;
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    for (final img in images.values) {
      img.dispose();
    }
  });

  // Dùng để bỏ cảnh báo "import không dùng" khi cần chỉnh nhanh dữ liệu mẫu.
  test('dữ liệu mẫu hợp lệ', () {
    for (final id in _sampleRecipes.keys) {
      expect(_recipeOf(id).validate(), isEmpty, reason: id);
    }
    expect(const Ingredient(id: 'x', name: 'x').validate(), isEmpty);
    expect(const RecipeStep(id: 'x', order: 1, text: 'x').validate(), isEmpty);
  });
}
