import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/providers/community_provider.dart';
import 'package:btl_ltdd/features/home/view/app_shell.dart';
import 'package:btl_ltdd/features/home/view/widgets/recipe_cover.dart';
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
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cooking_fakes.dart';
import '../support/community_fakes.dart';
import '../support/planner_fakes.dart';

Map<String, dynamic> _ing(String id, String name, double? q, String? unit) =>
    {'id': id, 'name': name, 'quantity': q, 'unit': unit, 'isPlaceholder': false};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Thứ 4, 11/11/2026: tuần bắt đầu 9/11, hôm nay là ngày 2 (0 = thứ 2).
  final now = DateTime(2026, 11, 11, 9);
  final week = DateTime(2026, 11, 9);
  late FakeFirebaseFirestore db;
  late FakePlannerRepository planner;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() async {
    db = FakeFirebaseFirestore();
    planner = FakePlannerRepository();
    Future<void> recipe(String id, String title, int servings, List<Map<String, dynamic>> ings) =>
        db.collection('recipes').doc(id).set({
          'ownerId': 'alice',
          'title': title,
          'baseServings': servings,
          'imageUrl': '',
          'tags': <String>[],
          'note': '',
          'ingredients': ings,
          'steps': [
            {'id': 's1', 'order': 1, 'text': 'Nấu', 'durationSec': 600, 'isPlaceholder': false},
          ],
          'schemaVersion': 1,
        });
    await recipe('tk', 'Thịt kho trứng', 4, [_ing('a', 'trứng', 4, 'quả'), _ing('b', 'thịt ba chỉ', 500, 'g')]);
    await recipe('tc', 'Trứng chiên', 1, [_ing('a', 'Trứng', 2, 'quả'), _ing('b', 'hành lá', 1, 'nhánh')]);
  });

  Future<void> pumpShell(WidgetTester tester, {int tab = 0}) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FirestoreRecipeRepository(firestore: db, auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')));
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
                Provider<RecipeRepository>.value(value: repo),
                ChangeNotifierProvider(create: (_) => RecipeListProvider(repository: repo)),
                Provider<PlannerRepository>.value(value: planner),
                ChangeNotifierProvider(create: (_) => MealPlanProvider(repository: planner, now: () => now)),
                ChangeNotifierProxyProvider<MealPlanProvider, ShoppingProvider>(
                  create: (_) => ShoppingProvider(repository: planner),
                  update: (_, plan, shop) => shop!..attachWeek(plan.weekStart),
                ),
                Provider<CommunityRepository>.value(value: FakeCommunityRepository()),
                ChangeNotifierProvider(create: (ctx) => CommunityProvider(repository: ctx.read<CommunityRepository>(), recipes: repo)),
                Provider<CookingSessionStore>.value(value: CookingSessionStore(uidGetter: () => 'alice')),
                Provider<TimerNotifier>.value(value: FakeTimerNotifier()),
                Provider<ScreenAwake>.value(value: FakeScreenAwake()),
                Provider<AccountActions>.value(value: AccountActions(emailGetter: () => 'a@test.dev', signOutCallback: () async {})),
              ],
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: AppShell(loginBuilder: (_) => const Scaffold(), initialTab: tab),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('ảnh minh hoạ theo loại món', () {
    test('chọn theo từ khoá xuất hiện sớm nhất trong tên', () {
      expect(dishStyleFor('Thịt kho trứng').icon, Icons.outdoor_grill);
      expect(dishStyleFor('Trứng chiên hành').icon, Icons.egg_alt);
      expect(dishStyleFor('Canh chua cá lóc').icon, Icons.soup_kitchen);
      expect(dishStyleFor('Phở bò').icon, Icons.ramen_dining);
      expect(dishStyleFor('Gà rán giòn').icon, Icons.kebab_dining);
      expect(dishStyleFor('Salad ức gà').icon, Icons.eco);
    });

    test('từ khoá dài thắng khi cùng vị trí; không khớp thì dùng ảnh mặc định', () {
      expect(dishStyleFor('Mì Ý sốt bò').icon, Icons.dinner_dining);
      expect(dishStyleFor('Cà phê sữa đá').icon, Icons.local_cafe);
      expect(dishStyleFor('Món bí mật').icon, Icons.restaurant);
    });
  });

  testWidgets('khung 4 tab: trang chủ trước, chuyển sang Công thức, Thực đơn, Đi chợ', (tester) async {
    await pumpShell(tester);
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    expect(find.text('Chào buổi sáng'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav_recipes')));
    await settle(tester);
    expect(find.text('Thịt kho trứng'), findsWidgets);
    await tester.tap(find.byKey(const Key('nav_planner')));
    await settle(tester);
    expect(find.text('Thực đơn tuần'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav_shopping')));
    await settle(tester);
    expect(find.text('Chưa có gì để mua. Lên thực đơn tuần, danh sách sẽ tự tạo.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shopping_go_plan')));
    await settle(tester);
    expect(find.text('Thực đơn tuần'), findsOneWidget);
  });

  testWidgets('thực đơn: thêm món vào bữa tối thứ 4 qua bảng chọn công thức', (tester) async {
    await pumpShell(tester, tab: 2);
    expect(find.text('Hôm nay'), findsOneWidget, reason: 'thứ 4 được đánh dấu hôm nay');
    await tester.ensureVisible(find.byKey(const Key('add_2_dinner')));
    await tester.tap(find.byKey(const Key('add_2_dinner')));
    await settle(tester);
    expect(find.text('Chọn công thức'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick_tk')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('add_meal_confirm')));
    await settle(tester);
    final entry = planner.weeks[week]!.entries.single;
    expect([entry.day, entry.slot, entry.recipeId, entry.servings], [2, MealSlot.dinner, 'tk', 4]);
    expect(find.text('Thịt kho trứng'), findsWidgets);
    expect(find.text('4 người'), findsOneWidget);
  });

  testWidgets('trang chủ hiện món hôm nay; đi chợ gộp nguyên liệu và tick đã mua', (tester) async {
    planner.weeks[week] = WeekPlan(weekStart: week, entries: const [
      MealEntry(id: 'e1', day: 2, slot: MealSlot.dinner, recipeId: 'tk', title: 'Thịt kho trứng', servings: 4),
      MealEntry(id: 'e2', day: 3, slot: MealSlot.breakfast, recipeId: 'tc', title: 'Trứng chiên', servings: 1),
    ]);
    planner.shopping[week] = const ShoppingState();
    await pumpShell(tester);
    expect(find.byKey(const Key('today_e1')), findsOneWidget);
    expect(find.byKey(const Key('today_e2')), findsNothing, reason: 'thứ 5 không phải hôm nay');

    await tester.tap(find.byKey(const Key('nav_shopping')));
    await settle(tester);
    expect(find.text('6 quả trứng'), findsOneWidget, reason: '4 + 2 quả gộp lại');
    expect(find.text('500 g thịt ba chỉ'), findsOneWidget);
    expect(find.text('Đã mua 0 / 3'), findsOneWidget);
    await tester.tap(find.text('6 quả trứng'));
    await settle(tester);
    expect(planner.shopping[week]!.checked, {'trung|quả'});
    expect(find.text('Đã mua 1 / 3'), findsOneWidget);
  });

  testWidgets('đi chợ: thêm món lẻ', (tester) async {
    await pumpShell(tester, tab: 3);
    await tester.tap(find.byKey(const Key('add_extra')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('extra_name')), 'Giấy bạc');
    await tester.enterText(find.byKey(const Key('extra_quantity')), '2');
    await tester.enterText(find.byKey(const Key('extra_unit')), 'cuộn');
    await tester.tap(find.byKey(const Key('extra_save')));
    await settle(tester);
    expect(planner.shopping[week]!.extras.single.name, 'Giấy bạc');
    expect(find.text('2 cuộn Giấy bạc'), findsOneWidget);
  });
}
