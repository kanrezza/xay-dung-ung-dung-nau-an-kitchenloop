import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:btl_ltdd/features/admin/providers/admin_status_provider.dart';
import 'package:btl_ltdd/features/admin/view/widgets/admin_home_card.dart';
import 'package:btl_ltdd/features/community/providers/announcement_provider.dart';
import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/community/providers/community_provider.dart';
import 'package:btl_ltdd/features/community/view/admin_community_tab.dart';
import 'package:btl_ltdd/features/community/view/community_screen.dart';
import 'package:btl_ltdd/features/planner/data/planner_repository.dart';
import 'package:btl_ltdd/features/planner/providers/meal_plan_provider.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:btl_ltdd/features/recipes/view/recipe_detail_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/community_fakes.dart';
import '../support/planner_fakes.dart';

Map<String, dynamic> _post(String author, String title, {String status = 'visible', int reports = 0, DateTime? at}) => {
      'authorId': author,
      'authorName': author == 'alice' ? 'Alice' : 'Bình',
      'sourceRecipeId': title,
      'title': title,
      'note': '',
      'baseServings': 2,
      'ingredients': [
        {'id': 'a', 'name': 'trứng gà', 'quantity': 2, 'unit': 'quả'},
        {'id': 'b', 'name': 'hành lá', 'quantity': 1, 'unit': 'nhánh'},
      ],
      'steps': [
        {'id': 's1', 'order': 1, 'text': 'Đánh trứng với hành.'},
        {'id': 's2', 'order': 2, 'text': 'Chiên vàng hai mặt.'},
      ],
      'tags': ['nhanh'],
      'status': status,
      'reportCount': reports,
      'createdAt': at ?? DateTime(2026, 11, 14),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore db;
  late FirestoreRecipeRepository recipes;
  late FakeCommunityRepository community;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    recipes = FirestoreRecipeRepository(firestore: db, auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')));
    community = FakeCommunityRepository(now: () => DateTime(2026, 11, 14, 12));
    community.posts['binh_tc'] = CommunityPost.fromMap('binh_tc', _post('binh', 'Trứng chiên hành'));
    community.posts['binh_ph'] = CommunityPost.fromMap('binh_ph', _post('binh', 'Phở gà', at: DateTime(2026, 11, 12)));
    community.posts['alice_tk'] = CommunityPost.fromMap('alice_tk', _post('alice', 'Thịt kho trứng', at: DateTime(2026, 11, 10)));
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home, {bool admin = false}) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                Provider<CommunityRepository>.value(value: community),
                ChangeNotifierProvider(create: (_) => CommunityProvider(repository: community, recipes: recipes)),
                ChangeNotifierProvider(create: (_) => AnnouncementProvider(repository: community)),
                Provider<AdminRepository>.value(value: StubAdminRepository(admin: admin)),
                ChangeNotifierProvider(create: (ctx) => AdminStatusProvider(repository: ctx.read<AdminRepository>())),
              ],
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: home,
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
  }

  testWidgets('tab Cộng đồng: bài đang hiện, mới nhất trước, đánh dấu bài của mình; tìm kiếm', (tester) async {
    await pump(tester, const CommunityScreen());
    expect(find.text('Trứng chiên hành'), findsOneWidget);
    expect(find.text('Bài của bạn'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Trứng chiên hành') < y('Phở gà'), isTrue);
    await tester.enterText(find.byKey(const Key('community_search')), 'pho');
    await settle(tester);
    expect(find.text('Phở gà'), findsOneWidget);
    expect(find.text('Trứng chiên hành'), findsNothing);
  });

  testWidgets('chi tiết bài người khác: lưu vào sổ của tôi tạo công thức riêng', (tester) async {
    await pump(tester, const CommunityScreen());
    await tester.tap(find.text('Trứng chiên hành'));
    await settle(tester);
    expect(find.byKey(const Key('report_post')), findsOneWidget);
    await tester.tap(find.byKey(const Key('save_post')));
    await settle(tester);
    expect(find.text('Đã lưu vào sổ công thức của bạn'), findsOneWidget);
    final mine = await db.collection('recipes').where('ownerId', isEqualTo: 'alice').get();
    expect(mine.docs.single.data()['title'], 'Trứng chiên hành');
  });

  testWidgets('báo cáo bài kèm lý do; bài đủ 3 báo cáo biến mất khỏi danh sách', (tester) async {
    community.posts['binh_tc'] = CommunityPost.fromMap('binh_tc', _post('binh', 'Trứng chiên hành', reports: 2));
    await pump(tester, const CommunityScreen());
    await tester.tap(find.text('Trứng chiên hành'));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('report_post')));
    await tester.tap(find.byKey(const Key('report_post')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('reason_not_recipe')));
    await settle(tester);
    expect(community.reports['binh_tc']!.single.reason, ReportReason.notRecipe);
    expect(community.posts['binh_tc']!.status, PostStatus.hidden);
    expect(find.text('Trứng chiên hành'), findsNothing);
  });

  testWidgets('bài của mình: không có nút báo cáo, gỡ được bài', (tester) async {
    await pump(tester, const CommunityScreen());
    await tester.tap(find.text('Thịt kho trứng'));
    await settle(tester);
    expect(find.byKey(const Key('report_post')), findsNothing);
    expect(find.byKey(const Key('save_post')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('unshare_post')));
    await tester.tap(find.byKey(const Key('unshare_post')));
    await settle(tester);
    await tester.tap(find.text('Gỡ bài').last);
    await settle(tester);
    expect(community.posts.containsKey('alice_tk'), isFalse);
  });

  Future<void> seedRecipe(String id, Map<String, dynamic> over) => db.collection('recipes').doc(id).set({
        'ownerId': 'alice',
        'title': 'Canh chua cá lóc',
        'baseServings': 4,
        'imageUrl': '',
        'note': '',
        'tags': <String>[],
        'ingredients': [
          {'id': 'a', 'name': 'cá lóc', 'quantity': 1, 'unit': 'con', 'isPlaceholder': false},
          {'id': 'b', 'name': 'me chua', 'quantity': 50, 'unit': 'g', 'isPlaceholder': false},
        ],
        'steps': [
          {'id': 's1', 'order': 1, 'text': 'Nấu nước me, lọc lấy nước chua.', 'isPlaceholder': false},
          {'id': 's2', 'order': 2, 'text': 'Cho cá vào nấu chín, thêm rau.', 'isPlaceholder': false},
        ],
        'schemaVersion': 1,
        ...over,
      });

  Future<void> tapShare(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('share_recipe')));
    await tester.tap(find.byKey(const Key('share_recipe')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('share_confirm')));
    await settle(tester);
  }

  testWidgets('chia sẻ từ chi tiết công thức: bài đạt thì lên cộng đồng', (tester) async {
    await seedRecipe('cc', {});
    await pump(tester, const RecipeDetailScreen(recipeId: 'cc'));
    await tapShare(tester);
    expect(find.text('Đã chia sẻ lên cộng đồng'), findsOneWidget);
    expect(community.posts['alice_cc']!.title, 'Canh chua cá lóc');
  });

  testWidgets('chia sẻ bài linh tinh: báo từng lý do, không gửi lên', (tester) async {
    await seedRecipe('bad', {
      'title': 'ngonnnnnn',
      'note': 'Mua tại shop.vn',
      'steps': [
        {'id': 's1', 'order': 1, 'text': 'nấu', 'isPlaceholder': false},
      ],
    });
    await pump(tester, const RecipeDetailScreen(recipeId: 'bad'));
    await tapShare(tester);
    expect(find.byKey(const Key('share_issues')), findsOneWidget);
    expect(find.text('Không được chèn đường link hay tên miền.'), findsOneWidget);
    expect(find.text('Cần ít nhất 2 bước nấu.'), findsOneWidget);
    expect(find.textContaining('gõ lặp'), findsOneWidget);
    expect(community.posts.containsKey('alice_bad'), isFalse);
  });

  testWidgets('chia sẻ dồn dập: báo phải chờ', (tester) async {
    community.tooSoon = const Duration(seconds: 75);
    await seedRecipe('cc', {});
    await pump(tester, const RecipeDetailScreen(recipeId: 'cc'));
    await tapShare(tester);
    expect(find.text('Bạn vừa đăng bài. Hãy đợi 75 giây rồi thử lại.'), findsOneWidget);
  });

  testWidgets('quản trị: số liệu, hàng chờ duyệt có lý do báo cáo, khôi phục bài', (tester) async {
    community.posts['binh_tc'] = CommunityPost.fromMap('binh_tc', _post('binh', 'Trứng chiên hành', status: 'hidden', reports: 3));
    community.reports['binh_tc'] = const [PostReport(reporterId: 'x', reason: ReportReason.spam)];
    community.posts['binh_old'] = CommunityPost.fromMap('binh_old', _post('binh', 'Bài cũ', status: 'removed', reports: 4));
    await pump(tester, Scaffold(body: AdminCommunityTab(now: () => DateTime(2026, 11, 14, 12))));
    String stat(String key) => tester.widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).first.data!;
    expect(stat('c_visible'), '2');
    expect(stat('c_hidden'), '1');
    expect(stat('c_removed'), '1');
    expect(stat('c_reports'), '7');
    expect(find.text('Lý do: Quảng cáo, spam'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('restore_binh_tc')));
    await tester.tap(find.byKey(const Key('restore_binh_tc')));
    await settle(tester);
    expect(community.posts['binh_tc']!.status, PostStatus.visible);
    expect(community.posts['binh_tc']!.reportCount, 0);
    expect(find.text('Không có bài nào chờ duyệt.'), findsOneWidget);
  });

  group('spec 007', () {
    int likes(String id) => community.posts[id]!.likeCount;

    testWidgets('thích bài người khác trên thẻ; bài của mình không thích được', (tester) async {
      await pump(tester, const CommunityScreen());
      await tester.tap(find.byKey(const Key('like_binh_tc')));
      await settle(tester);
      expect(community.posts['binh_tc']!.isLikedBy('alice'), isTrue);
      expect(find.descendant(of: find.byKey(const Key('like_binh_tc')), matching: find.text('1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('like_binh_tc')));
      await settle(tester);
      expect(likes('binh_tc'), 0);
      await tester.tap(find.byKey(const Key('like_alice_tk')));
      await settle(tester);
      expect(likes('alice_tk'), 0);
    });

    testWidgets('xếp theo lượt thích; lọc theo thẻ; dải Nổi bật', (tester) async {
      community.posts['binh_ph'] = community.posts['binh_ph']!.copyWith(likedBy: ['x', 'y'], featured: true);
      community.posts['binh_tc'] = CommunityPost.fromMap('binh_tc', {
        ..._post('binh', 'Trứng chiên hành'),
        'tags': ['sáng']
      });
      await pump(tester, const CommunityScreen());
      expect(find.byKey(const Key('featured_binh_ph')), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.byKey(Key('post_$t'))).dy;
      expect(y('binh_tc') < y('binh_ph'), isTrue);
      await tester.tap(find.byKey(const Key('sort_popular')));
      await settle(tester);
      expect(y('binh_ph') < y('binh_tc'), isTrue);
      await tester.tap(find.byKey(const Key('tag_sáng')));
      await settle(tester);
      expect(find.byKey(const Key('post_binh_tc')), findsOneWidget);
      expect(find.byKey(const Key('post_binh_ph')), findsNothing);
      expect(find.byKey(const Key('featured_strip')), findsNothing, reason: 'đang lọc thì ẩn dải nổi bật');
    });

    testWidgets('thông báo chung hiện ở Cộng đồng, ẩn được trên máy', (tester) async {
      community.announcement = 'Tuần này: món chay';
      await pump(tester, const CommunityScreen());
      expect(find.text('Tuần này: món chay'), findsOneWidget);
      await tester.tap(find.byKey(const Key('announcement_close')));
      await settle(tester);
      expect(find.text('Tuần này: món chay'), findsNothing);
      await community.setAnnouncement('Thông báo mới');
      await settle(tester);
      expect(find.text('Thông báo mới'), findsOneWidget, reason: 'nội dung mới thì hiện lại');
    });

    testWidgets('người thường không thấy công cụ quản trị', (tester) async {
      await pump(tester, const CommunityScreen());
      await tester.tap(find.text('Trứng chiên hành'));
      await settle(tester);
      expect(find.byKey(const Key('admin_post_tools')), findsNothing);
    });

    testWidgets('quản trị viên ghim nổi bật rồi ẩn bài từ màn xem bài', (tester) async {
      await pump(tester, const CommunityScreen(), admin: true);
      await tester.tap(find.text('Trứng chiên hành'));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('admin_feature')));
      await tester.tap(find.byKey(const Key('admin_feature')));
      await settle(tester);
      expect(community.posts['binh_tc']!.featured, isTrue);
      expect(find.text('Nổi bật'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('admin_hide')));
      await tester.tap(find.byKey(const Key('admin_hide')));
      await settle(tester);
      expect(community.posts['binh_tc']!.status, PostStatus.hidden);
      expect(find.byKey(const Key('post_binh_tc')), findsNothing);
    });

    testWidgets('thẻ Bảng quản trị: chỉ quản trị viên thấy, có số bài chờ duyệt', (tester) async {
      community.posts['binh_tc'] = community.posts['binh_tc']!.copyWith(status: PostStatus.hidden);
      await pump(tester, const Scaffold(body: AdminHomeCard()), admin: true);
      expect(find.byKey(const Key('admin_home_card')), findsOneWidget);
      expect(find.text('1 bài chờ duyệt · 2 bài đang hiện'), findsOneWidget);
    });

    testWidgets('thẻ Bảng quản trị ẩn với người thường', (tester) async {
      await pump(tester, const Scaffold(body: AdminHomeCard()));
      expect(find.byKey(const Key('admin_home_card')), findsNothing);
    });
  });
}
