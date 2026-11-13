import 'dart:async';

import 'package:btl_ltdd/features/admin/data/admin_repository.dart';
import 'package:btl_ltdd/features/admin/models/admin_user.dart';
import 'package:btl_ltdd/features/admin/view/admin_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  setUp(() {
    repo = FakeAdminRepository([
      AdminUser(id: 'boss', name: 'Quản trị', email: 'boss@example.com', createdAt: DateTime(2026, 1, 1)),
      AdminUser(id: 'an', name: 'An', email: 'an@example.com', createdAt: DateTime(2026, 11, 12)),
      AdminUser(id: 'chi', name: 'Chi', email: 'chi@example.com', createdAt: DateTime(2026, 5, 1), isLocked: true),
    ]);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path: 'assets/langs',
          fallbackLocale: const Locale('vi'),
          startLocale: const Locale('vi'),
          saveLocale: false,
          child: Builder(
            builder: (context) => Provider<AdminRepository>.value(
              value: repo,
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
}
