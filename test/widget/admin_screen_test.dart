import 'dart:async';

import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:btl_ltdd/features/community/data/community_repository.dart';
import 'package:btl_ltdd/features/community/models/community_post.dart';
import 'package:btl_ltdd/features/community/providers/announcement_provider.dart';
import 'package:btl_ltdd/features/admin/models/admin_user.dart';
import 'package:btl_ltdd/features/admin/view/admin_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/community_fakes.dart';

class FakeAdminRepository implements AdminRepository {
  FakeAdminRepository(this.users);

  List<AdminUser> users;
  final _controller = StreamController<List<AdminUser>>.broadcast();
  final calls = <String>[];
  bool failNext = false;

  @override
  String? get currentUid => 'boss';

  @override
  Future<bool> isCurrentUserAdmin() async => true;

  @override
  Stream<bool> watchIsAdmin() => Stream.value(true);

  @override
  Stream<List<AdminUser>> watchUsers() async* {
    yield users;
    yield* _controller.stream;
  }

  @override
  Future<void> setLocked(String uid, bool locked) async {
    calls.add('$uid:$locked');
    if (failNext) throw Exception('permission-denied');
    users = [
      for (final u in users)
        u.id == uid ? AdminUser(id: u.id, name: u.name, email: u.email, createdAt: u.createdAt, isLocked: locked) : u,
    ];
    _controller.add(users);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final now = DateTime(2026, 11, 14);
  late FakeAdminRepository repo;
  late FakeCommunityRepository community;

  setUp(() {
    community = FakeCommunityRepository(uid: 'boss', now: () => now);
    repo = FakeAdminRepository([
      AdminUser(id: 'boss', name: 'Quản trị', email: 'boss@example.com', createdAt: DateTime(2026, 1, 1)),
      AdminUser(id: 'an', name: 'An', email: 'an@example.com', createdAt: DateTime(2026, 11, 12)),
      AdminUser(id: 'chi', name: 'Chi', email: 'chi@example.com', createdAt: DateTime(2026, 5, 1), isLocked: true),
    ]);
  });

  Future<void> pump(WidgetTester tester, {String? tab = 'admin_tab_users'}) async {
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
                Provider<AdminRepository>.value(value: repo),
                Provider<CommunityRepository>.value(value: community),
                ChangeNotifierProvider(create: (_) => AnnouncementProvider(repository: community)),
              ],
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: AdminScreen(now: () => now),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    if (tab != null) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
    }
  }

  String statText(WidgetTester tester, String key) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)))
      .first
      .data!;

  testWidgets('hiện thống kê và danh sách tài khoản', (tester) async {
    await pump(tester);
    expect(find.text('Quản trị'), findsWidgets);
    expect(statText(tester, 'stat_total'), '3');
    expect(statText(tester, 'stat_locked'), '1');
    expect(statText(tester, 'stat_new'), '1');
    expect(find.text('An'), findsOneWidget);
    expect(find.text('Quản trị viên không xem được công thức của người dùng.'), findsOneWidget);
  });

  testWidgets('dòng của chính mình không có nút khoá', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('lock_boss')), findsNothing);
    expect(find.text('Bạn'), findsOneWidget);
  });

  testWidgets('khoá có xác nhận; huỷ thì không làm gì', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('lock_an')));
    await tester.pumpAndSettle();
    expect(find.text('Khoá tài khoản?'), findsOneWidget);
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(find.byKey(const Key('lock_an')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['an:true']);
    expect(find.byKey(const Key('unlock_an')), findsOneWidget);
    expect(statText(tester, 'stat_locked'), '2');
  });

  testWidgets('mở khoá tài khoản đang bị khoá', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('unlock_chi')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['chi:false']);
    expect(find.byKey(const Key('lock_chi')), findsOneWidget);
  });

  testWidgets('lỗi khi cập nhật: báo lỗi, không đổi trạng thái', (tester) async {
    repo.failNext = true;
    await pump(tester);
    await tester.tap(find.byKey(const Key('lock_an')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('admin_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Không cập nhật được, hãy thử lại.'), findsOneWidget);
    expect(find.byKey(const Key('lock_an')), findsOneWidget);
  });

  testWidgets('tìm kiếm không dấu theo tên', (tester) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('admin_search')), 'chi');
    await tester.pumpAndSettle();
    expect(find.text('Chi'), findsOneWidget);
    expect(find.text('An'), findsNothing);
  });

  testWidgets('Tổng quan (spec 007): số liệu chung và đăng thông báo chung', (tester) async {
    community.posts['an_r1'] = CommunityPost.fromMap('an_r1', {
      'authorId': 'an',
      'authorName': 'An',
      'title': 'Phở gà',
      'status': 'visible',
      'likedBy': ['x', 'y'],
      'featured': true,
    });
    community.posts['an_r2'] =
        CommunityPost.fromMap('an_r2', {'authorId': 'an', 'authorName': 'An', 'title': 'Bún chả', 'status': 'hidden'});
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, tab: null);
    expect(statText(tester, 'o_users'), '3');
    expect(statText(tester, 'o_locked'), '1');
    expect(statText(tester, 'o_visible'), '1');
    expect(statText(tester, 'o_pending'), '1');
    expect(statText(tester, 'o_likes'), '2');
    expect(statText(tester, 'o_featured'), '1');
    expect(find.byKey(const Key('top_an_r1')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('announcement_field')));
    await tester.enterText(find.byKey(const Key('announcement_field')), 'Xem shop.vn nhé');
    await tester.tap(find.byKey(const Key('announcement_save')));
    await tester.pumpAndSettle();
    expect(community.announcement, '', reason: 'có link thì không gửi');
    await tester.enterText(find.byKey(const Key('announcement_field')), 'Tuần này: món chay!');
    await tester.tap(find.byKey(const Key('announcement_save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(community.announcement, 'Tuần này: món chay!');
  });
}
