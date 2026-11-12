import 'package:btl_ltdd/features/recipes/data/account_actions.dart';
import 'package:btl_ltdd/features/recipes/data/cooking_session_store.dart';
import 'package:btl_ltdd/features/recipes/data/legacy_migration_service.dart';
import 'package:btl_ltdd/features/recipes/data/screen_awake.dart';
import 'package:btl_ltdd/features/recipes/data/timer_notifier.dart';
import 'package:btl_ltdd/features/recipes/data/recipe_repository.dart';
import 'package:btl_ltdd/features/recipes/providers/recipe_list_provider.dart';
import 'package:btl_ltdd/features/recipes/view/recipe_list_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cooking_fakes.dart';

/// Luồng người dùng của US1: danh sách trống → tạo công thức → xem → sửa → xoá.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late FirestoreRecipeRepository repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreRecipeRepository(
      firestore: db,
      auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice', email: 'alice@test.dev')),
    );
  });

  /// Nút "Thêm công thức": nút nổi khi đã có công thức, nút giữa màn hình khi danh
  /// sách trống (lúc đó nút nổi bị ẩn để không có hai nút giống nhau).
  Future<void> tapAddRecipe(WidgetTester tester) async {
    final fab = find.byKey(const Key('add_recipe'));
    await tester.tap(fab.evaluate().isNotEmpty ? fab : find.byKey(const Key('empty_add_recipe')));
  }

  Future<void> pumpApp(WidgetTester tester, {bool migrate = false}) async {
    // Màn hình đủ cao để mọi ô nhập của form được dựng sẵn.
    tester.view.physicalSize = const Size(900, 4000);
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
                Provider<RecipeRepository>.value(value: repo),
                ChangeNotifierProvider(
                  create: (_) => RecipeListProvider(
                    repository: repo,
                    migrationRunner: migrate
                        ? LegacyMigrationService(
                            firestore: db,
                            auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'alice')),
                          ).migrateIfNeeded
                        : null,
                  ),
                ),
                Provider<CookingSessionStore>.value(value: CookingSessionStore(uidGetter: () => 'alice')),
                Provider<TimerNotifier>.value(value: FakeTimerNotifier()),
                Provider<ScreenAwake>.value(value: FakeScreenAwake()),
                Provider<AccountActions>.value(
                  value: AccountActions(emailGetter: () => 'alice@test.dev', signOutCallback: () async {}),
                ),
              ],
              child: MaterialApp(
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                home: RecipeListScreen(loginBuilder: (_) => const Scaffold(body: Text('LOGIN'))),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  /// Chờ các luồng của fake Firestore phát dữ liệu: xen kẽ thời gian thực (cho
  /// luồng chạy) và đồng hồ giả (cho khung hình/animation). Không dùng
  /// pumpAndSettle vì vòng quay tải chạy mãi khi chưa có dữ liệu.
  ///
  /// Khung hình đầu tiên được dựng trong runAsync để các màn hình vừa mở đăng ký
  /// luồng dữ liệu ở vùng async thật (trong vùng đồng hồ giả, luồng của fake
  /// Firestore không phát được).
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => tester.pump());
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  Future<void> fillValidRecipe(WidgetTester tester) async {
    await tester.enterText(field('Tên món'), 'Trứng chiên');
    await tester.enterText(field('Tên nguyên liệu'), 'trứng');
    await tester.enterText(field('Số lượng'), '2');
    await tester.enterText(field('Đơn vị'), 'quả');
    await tester.enterText(field('Nội dung bước'), 'Chiên trứng');
    await tester.pump();
  }

  testWidgets('danh sách trống hiện lời nhắn và nút tạo công thức đầu tiên', (tester) async {
    await pumpApp(tester);
    expect(find.text('Chưa có công thức nào. Hãy tạo công thức đầu tiên của bạn!'), findsOneWidget);
    expect(find.byKey(const Key('empty_add_recipe')), findsOneWidget);
    expect(find.byKey(const Key('add_recipe')), findsNothing, reason: 'danh sách trống chỉ có một nút thêm');
  });

  testWidgets('tạo công thức → hiện trong danh sách → xem chi tiết đúng nội dung', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('empty_add_recipe')));
    await tester.pumpAndSettle();
    expect(find.text('Công thức mới'), findsOneWidget);

    await fillValidRecipe(tester);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    // Quay lại danh sách, có thẻ công thức mới.
    expect(find.text('Công thức mới'), findsNothing);
    expect(find.text('Trứng chiên'), findsOneWidget);
    expect(find.text('1 nguyên liệu · 1 bước'), findsOneWidget);

    await tester.tap(find.text('Trứng chiên'));
    await settle(tester);
    expect(find.text('2 quả trứng'), findsOneWidget);
    expect(find.text('Chiên trứng'), findsOneWidget);
    expect(find.text('Số người ăn'), findsOneWidget);

    // Dữ liệu thật sự nằm trong Firestore, thuộc về alice.
    final docs = (await db.collection('recipes').get()).docs;
    expect(docs, hasLength(1));
    expect(docs.single.data()['ownerId'], 'alice');
  });

  testWidgets('lưu thiếu dữ liệu: báo lỗi tại chỗ và giữ nguyên những gì đã nhập', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();

    await tester.enterText(field('Tên nguyên liệu'), 'trứng');
    await tester.tap(find.byKey(const Key('save_recipe')));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập tên món'), findsOneWidget);
    expect(find.text('Vui lòng sửa các lỗi được đánh dấu'), findsOneWidget);
    expect(find.text('trứng'), findsOneWidget); // dữ liệu đã nhập không mất
    expect((await db.collection('recipes').get()).docs, isEmpty);
  });

  testWidgets('số lượng sai định dạng hiện lỗi ngay và chặn lưu', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();

    await fillValidRecipe(tester);
    await tester.enterText(field('Số lượng'), 'abc');
    await tester.pump();
    expect(find.textContaining('Số lượng không hợp lệ'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_recipe')));
    await tester.pumpAndSettle();
    expect((await db.collection('recipes').get()).docs, isEmpty);

    await tester.enterText(field('Số lượng'), '1/2');
    await tester.pump();
    expect(find.textContaining('Số lượng không hợp lệ'), findsNothing);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);
    final saved = (await db.collection('recipes').get()).docs.single.data();
    expect((saved['ingredients'] as List).first['quantity'], 0.5);
  });

  testWidgets('thoát khi có thay đổi chưa lưu thì hỏi xác nhận', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await tester.enterText(field('Tên món'), 'Dở dang');
    await tester.pump();

    await goBack(tester);
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Công thức mới'), findsOneWidget);

    await goBack(tester);
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Công thức mới'), findsNothing);
    expect((await db.collection('recipes').get()).docs, isEmpty);
  });

  testWidgets('thoát khi chưa thay đổi gì thì không hỏi', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await goBack(tester);
    expect(find.text('Bỏ thay đổi?'), findsNothing);
    expect(find.text('Công thức mới'), findsNothing);
  });

  testWidgets('sửa công thức: đổi tên và lưu', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await fillValidRecipe(tester);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    await tester.tap(find.text('Trứng chiên'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('edit_recipe')));
    await tester.pumpAndSettle();
    expect(find.text('Sửa công thức'), findsOneWidget);

    await tester.enterText(field('Tên món'), 'Trứng rán');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    final docs = (await db.collection('recipes').get()).docs;
    expect(docs, hasLength(1)); // sửa, không tạo bản sao
    expect(docs.single.data()['title'], 'Trứng rán');
    expect(find.text('Trứng rán'), findsWidgets);
  });

  testWidgets('xoá công thức từ danh sách có xác nhận', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await fillValidRecipe(tester);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá').last);
    await tester.pumpAndSettle();
    expect(find.text('Xoá công thức?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
    await settle(tester);
    expect((await db.collection('recipes').get()).docs, isEmpty);
    expect(find.text('Chưa có công thức nào. Hãy tạo công thức đầu tiên của bạn!'), findsOneWidget);
  });

  testWidgets('đổi khẩu phần ở chi tiết: quy đổi để xem, KHÔNG ghi vào công thức, mang sang chế độ nấu', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await fillValidRecipe(tester); // 2 quả trứng cho 2 người
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);
    await tester.tap(find.text('Trứng chiên'));
    await settle(tester);
    expect(find.text('2 quả trứng'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const Key('servings_plus')));
      await tester.pump();
    }
    expect(find.text('5 quả trứng'), findsOneWidget); // 2 → 5 người
    expect(find.text('Công thức gốc cho 2 người'), findsOneWidget);

    // Công thức gốc không bị thay đổi.
    final data = (await db.collection('recipes').get()).docs.single.data();
    expect(data['baseServings'], 2);
    expect((data['ingredients'] as List).first['quantity'], 2);

    // Bắt đầu nấu với đúng khẩu phần đã chọn.
    await tester.tap(find.byKey(const Key('start_cooking')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open_ingredients')));
    await tester.pumpAndSettle();
    expect(find.text('5 quả trứng'), findsOneWidget);

    await tester.tapAt(const Offset(10, 300)); // đóng ngăn kéo
    await tester.pumpAndSettle();
    await goBack(tester);
  });

  testWidgets('nguyên liệu không có số lượng không bị nhân khi đổi khẩu phần', (tester) async {
    await db.collection('recipes').doc('salt1').set({
      'ownerId': 'alice',
      'title': 'Canh',
      'baseServings': 2,
      'ingredients': [
        {'id': 'i1', 'name': 'muối', 'isPlaceholder': false},
        {'id': 'i2', 'name': 'rau', 'quantity': 100, 'unit': 'g', 'isPlaceholder': false},
      ],
      'steps': [
        {'id': 's1', 'order': 1, 'text': 'Nấu', 'isPlaceholder': false},
      ],
      'schemaVersion': 1,
    });
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Canh'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    expect(find.text('150 g rau'), findsOneWidget); // 2 → 3 người
    expect(find.text('muối'), findsOneWidget); // giữ nguyên
  });

  testWidgets('từ danh sách chỉ cần 2 chạm để vào chế độ nấu', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await fillValidRecipe(tester);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    await tester.tap(find.text('Trứng chiên')); // chạm 1: chọn món
    await settle(tester);
    await tester.tap(find.byKey(const Key('start_cooking'))); // chạm 2: bắt đầu nấu
    await settle(tester);

    expect(find.text('Bước 1 / 1'), findsOneWidget);
    expect(find.text('Chiên trứng'), findsOneWidget);

    await goBack(tester); // thoát để dừng bộ đếm trước khi kết thúc test
  });

  testWidgets('biểu tượng tài khoản mở màn hình tài khoản', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('open_account')));
    await tester.pumpAndSettle();
    expect(find.text('alice@test.dev'), findsOneWidget);
  });

  testWidgets('công thức chuyển từ dữ liệu cũ: hiện mục "Nội dung gốc" và chuỗi giữ chỗ được dịch', (tester) async {
    await db.collection('recipes').doc('legacy1').set({
      'ownerId': 'alice',
      'title': '(Món chưa đặt tên)',
      'baseServings': 2,
      'ingredients': [
        {'id': 'i1', 'name': '(Chưa có nguyên liệu)', 'isPlaceholder': true},
      ],
      'steps': [
        {'id': 's1', 'order': 1, 'text': '(Chưa có hướng dẫn)', 'isPlaceholder': true},
      ],
      'legacy': {
        'title': '',
        'ingredients': ['2 quả trứng cũ'],
        'instructions': 'Hướng dẫn cũ nguyên văn',
        'sourceCollection': 'foods',
      },
      'schemaVersion': 1,
    });
    await pumpApp(tester);
    await settle(tester);

    expect(find.text('(Món chưa đặt tên)'), findsOneWidget);
    await tester.tap(find.text('(Món chưa đặt tên)'));
    await settle(tester);
    expect(find.text('(Chưa có nguyên liệu)'), findsOneWidget);
    expect(find.text('(Chưa có hướng dẫn)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('legacy_section')),
      200,
      // Chỉ định vùng cuộn của trang (ô nhập khẩu phần cũng chứa một Scrollable).
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(find.byKey(const Key('legacy_section')));
    await tester.pumpAndSettle();
    expect(find.text('• 2 quả trứng cũ'), findsOneWidget);
    expect(find.text('Hướng dẫn cũ nguyên văn'), findsOneWidget);
  });

  // ---------------------------------------------------------------- US4: thẻ, tìm, lọc

  Future<void> seed(String id, String title, {List<String> tags = const [], List<String> ingredients = const ['nguyên liệu']}) {
    return db.collection('recipes').doc(id).set({
      'ownerId': 'alice',
      'title': title,
      'baseServings': 2,
      'ingredients': [
        for (var i = 0; i < ingredients.length; i++) {'id': '$id-i$i', 'name': ingredients[i], 'isPlaceholder': false},
      ],
      'steps': [
        {'id': '$id-s', 'order': 1, 'text': 'Nấu', 'isPlaceholder': false},
      ],
      'tags': tags,
      'schemaVersion': 1,
    });
  }

  Future<void> seedThree() async {
    await seed('a', 'Gà rán', tags: ['món sinh viên', 'nhanh'], ingredients: ['đùi gà']);
    await seed('b', 'Thịt kho', tags: ['món sinh viên'], ingredients: ['thịt ba chỉ']);
    await seed('c', 'Canh chua', tags: ['ăn kiêng'], ingredients: ['cá lóc']);
  }

  Finder search() => find.byKey(const Key('search_field'));

  testWidgets('có công thức thì hiện ô tìm kiếm; danh sách trống thì không', (tester) async {
    await pumpApp(tester);
    expect(search(), findsNothing);
    await seed('a', 'Gà rán');
    await settle(tester);
    expect(search(), findsOneWidget);
  });

  testWidgets('tìm không dấu: gõ "ga" ra món có chữ "gà"', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Thịt kho'), findsOneWidget);

    await tester.enterText(search(), 'ga');
    await tester.pump();
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Thịt kho'), findsNothing);
    expect(find.text('Canh chua'), findsNothing);
  });

  testWidgets('tìm theo tên nguyên liệu', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.enterText(search(), 'ba chi');
    await tester.pump();
    expect(find.text('Thịt kho'), findsOneWidget);
    expect(find.text('Gà rán'), findsNothing);
  });

  testWidgets('nút × trong ô tìm kiếm xoá từ khoá và hiện lại toàn bộ', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.enterText(search(), 'canh');
    await tester.pump();
    expect(find.text('Gà rán'), findsNothing);

    await tester.tap(find.byKey(const Key('clear_search')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Canh chua'), findsOneWidget);
    expect(tester.widget<TextField>(search()).controller!.text, '');
  });

  testWidgets('thanh thẻ hiện số công thức; bấm thẻ để lọc, bấm lại để bỏ lọc', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    expect(find.text('món sinh viên (2)'), findsOneWidget);
    expect(find.text('nhanh (1)'), findsOneWidget);
    expect(find.text('ăn kiêng (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await tester.pump();
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Thịt kho'), findsOneWidget);
    expect(find.text('Canh chua'), findsNothing);

    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await tester.pump();
    expect(find.text('Canh chua'), findsOneWidget);
  });

  testWidgets('chọn nhiều thẻ: chỉ còn món có đủ các thẻ', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tag_chip_nhanh')));
    await tester.pump();
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Thịt kho'), findsNothing);
  });

  testWidgets('kết hợp từ khoá và thẻ', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await tester.pump();
    await tester.enterText(search(), 'thit');
    await tester.pump();
    expect(find.text('Thịt kho'), findsOneWidget);
    expect(find.text('Gà rán'), findsNothing);
  });

  testWidgets('không có kết quả: lời nhắn thân thiện kèm nút xoá bộ lọc', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.enterText(search(), 'sushi');
    await tester.pump();

    expect(find.text('Không tìm thấy công thức phù hợp. Thử xoá bộ lọc nhé.'), findsOneWidget);
    expect(find.byKey(const Key('clear_filters')), findsOneWidget);
    expect(find.text('Gà rán'), findsNothing);
    expect(search(), findsOneWidget); // vẫn sửa được từ khoá

    await tester.tap(find.byKey(const Key('clear_filters')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Gà rán'), findsOneWidget);
    expect(find.text('Thịt kho'), findsOneWidget);
    expect(find.byKey(const Key('clear_filters')), findsNothing);
    expect(tester.widget<TextField>(search()).controller!.text, '');
  });

  testWidgets('nút xoá bộ lọc cũng bỏ chọn các thẻ', (tester) async {
    await seedThree();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byKey(const Key('tag_chip_an kieng')));
    await tester.pump();
    await tester.enterText(search(), 'ga'); // ăn kiêng + "ga" → không có món nào
    await tester.pump();
    expect(find.byKey(const Key('clear_filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear_filters')));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<FilterChip>(find.byKey(const Key('tag_chip_an kieng'))).selected, isFalse);
    expect(find.text('Gà rán'), findsOneWidget);
  });

  testWidgets('soạn thảo: nhập thẻ rồi Enter, loại trùng không phân biệt hoa thường và dấu', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tag_input')), 'Món Sinh Viên');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byKey(const Key('tag_mon sinh vien')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('tag_input')), 'MON SINH VIEN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(InputChip), findsOneWidget); // không thêm bản trùng
    expect(find.text('Thẻ này đã có'), findsOneWidget);
  });

  testWidgets('soạn thảo: dấu phẩy thêm nhiều thẻ một lúc; thẻ quá 30 ký tự bị từ chối', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('tag_input')), 'nhanh, ăn kiêng,');
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('tag_input')), 'a' * 31);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('Mỗi thẻ có từ 1 đến 30 ký tự'), findsOneWidget);
  });

  testWidgets('soạn thảo: xoá thẻ bằng dấu ×', (tester) async {
    await pumpApp(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tag_input')), 'nhanh');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(InputChip), findsOneWidget);

    // Nút xoá là biểu tượng duy nhất bên trong InputChip.
    await tester.tap(find.descendant(of: find.byType(InputChip), matching: find.byType(Icon)));
    await tester.pump();
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('soạn thảo: gợi ý từ thẻ ở công thức khác, bấm để thêm, lưu cùng công thức', (tester) async {
    await seed('a', 'Gà rán', tags: ['món sinh viên', 'nhanh']);
    await pumpApp(tester);
    await settle(tester);
    await tapAddRecipe(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('suggest_nhanh')), findsOneWidget);
    await tester.tap(find.byKey(const Key('suggest_nhanh')));
    await tester.pump();
    expect(find.byKey(const Key('tag_nhanh')), findsOneWidget);
    expect(find.byKey(const Key('suggest_nhanh')), findsNothing); // đã thêm thì hết gợi ý

    await fillValidRecipe(tester);
    await tester.tap(find.byKey(const Key('save_recipe')));
    await settle(tester);

    final docs = (await db.collection('recipes').get()).docs;
    final created = docs.firstWhere((d) => d.id != 'a').data();
    expect(created['tags'], ['nhanh']);
    // Thẻ mới tạo xuất hiện ngay trên thanh lọc (nhanh có 2 công thức).
    expect(find.text('nhanh (2)'), findsOneWidget);
  });

  testWidgets('sửa công thức có sẵn: thẻ cũ được giữ và hiện trong ô nhập', (tester) async {
    await seed('a', 'Gà rán', tags: ['món sinh viên']);
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tag_mon sinh vien')), findsOneWidget);
  });

  // ------------------------------------------------------- US5: chuyển dữ liệu cũ khi mở app

  Future<void> seedLegacyFood(String id, {String title = 'Thịt kho cũ', Object ingredients = const ['500g thịt ba chỉ', 'nước mắm vừa đủ'], String instructions = '1. Luộc trứng\n2. Kho thịt'}) {
    return db.collection('foods').doc(id).set({
      'authorId': 'alice',
      'title': title,
      'ingredients': ingredients,
      'instructions': instructions,
      'servings': '4 người',
      'tags': ['món cũ'],
      'isShared': true,
      'likedBy': ['bob'],
    });
  }

  testWidgets('mở app: công thức cũ tự được chuyển, hiện trong danh sách và có thông báo kết quả', (tester) async {
    await seedLegacyFood('old1');
    await pumpApp(tester, migrate: true);
    await settle(tester);

    expect(find.text('Thịt kho cũ'), findsOneWidget);
    expect(find.text('2 nguyên liệu · 2 bước'), findsOneWidget);
    // 1 công thức đã chuyển, 1 dòng nguyên liệu giữ nguyên văn ("nước mắm vừa đủ").
    expect(find.text('Đã chuyển 1 công thức; 1 dòng nguyên liệu được giữ nguyên văn'), findsOneWidget);

    // Dữ liệu cũ còn nguyên, bản mới có đủ thông tin.
    expect((await db.collection('foods').doc('old1').get()).exists, isTrue);
    final data = (await db.collection('recipes').doc('old1').get()).data()!;
    expect(data['baseServings'], 4);
    expect((data['legacy'] as Map)['instructions'], '1. Luộc trứng\n2. Kho thịt');
  });

  testWidgets('chỉ báo kết quả một lần; mở lại không chuyển lần nữa', (tester) async {
    await seedLegacyFood('old1');
    await pumpApp(tester, migrate: true);
    await settle(tester);
    expect(find.textContaining('Đã chuyển 1 công thức'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // thông báo tự tắt
    await tester.pump();

    await pumpApp(tester, migrate: true);
    await settle(tester);
    expect(find.textContaining('Đã chuyển'), findsNothing);
    expect((await db.collection('recipes').get()).docs, hasLength(1));
  });

  testWidgets('món cũ thiếu nguyên liệu và hướng dẫn: vẫn có trong danh sách, hiện chuỗi giữ chỗ đã dịch', (tester) async {
    await seedLegacyFood('empty1', title: '', ingredients: <String>[], instructions: '');
    await pumpApp(tester, migrate: true);
    await settle(tester);

    expect(find.text('(Món chưa đặt tên)'), findsOneWidget);
    await tester.tap(find.text('(Món chưa đặt tên)'));
    await settle(tester);
    expect(find.text('(Chưa có nguyên liệu)'), findsOneWidget);
    expect(find.text('(Chưa có hướng dẫn)'), findsOneWidget);
  });

  testWidgets('tài khoản không có dữ liệu cũ: không có thông báo nào', (tester) async {
    await pumpApp(tester, migrate: true);
    await settle(tester);
    expect(find.textContaining('Đã chuyển'), findsNothing);
    expect(find.text('Chưa có công thức nào. Hãy tạo công thức đầu tiên của bạn!'), findsOneWidget);
  });

  // ------------------------------------------------ công thức lớn: 50 nguyên liệu + 50 bước

  Future<void> seedBig() {
    return db.collection('recipes').doc('big').set({
      'ownerId': 'alice',
      'title': 'Tiệc lớn',
      'baseServings': 10,
      'ingredients': [
        for (var i = 0; i < 50; i++) {'id': 'i$i', 'name': 'nguyên liệu $i', 'quantity': i + 1, 'unit': 'g', 'isPlaceholder': false},
      ],
      'steps': [
        for (var i = 0; i < 50; i++) {'id': 's$i', 'order': i + 1, 'text': 'Bước nấu số $i', 'isPlaceholder': false},
      ],
      'tags': ['tiệc'],
      'schemaVersion': 1,
    });
  }

  Finder pageScrollable() => find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first;

  testWidgets('công thức 50 nguyên liệu + 50 bước: xem chi tiết cuộn tới cuối không lỗi', (tester) async {
    await seedBig();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Tiệc lớn'));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Bước nấu số 49'), 400, scrollable: pageScrollable(), maxScrolls: 200);
    expect(find.text('Bước nấu số 49'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('công thức 50 nguyên liệu + 50 bước: đổi khẩu phần quy đổi đúng và không lỗi', (tester) async {
    await seedBig();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Tiệc lớn'));
    await settle(tester);
    expect(find.text('1 g nguyên liệu 0'), findsOneWidget); // 10 người
    await tester.tap(find.byKey(const Key('servings_plus'))); // 11 người
    await tester.pump();
    expect(find.text('1,1 g nguyên liệu 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('công thức 50 nguyên liệu + 50 bước: mở màn hình sửa và cuộn tới cuối không lỗi', (tester) async {
    await seedBig();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(const Key('save_recipe')), -300, scrollable: pageScrollable(), maxScrolls: 5);
    final scrollable = pageScrollable();
    for (var i = 0; i < 40; i++) {
      await tester.drag(scrollable, const Offset(0, -1500));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Bước 50'), findsWidgets);
  });

  testWidgets('công thức 50 bước: chế độ nấu đi qua đủ 50 bước', (tester) async {
    await seedBig();
    await pumpApp(tester);
    await settle(tester);
    await tester.tap(find.text('Tiệc lớn'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('start_cooking')));
    await settle(tester);
    expect(find.text('Bước 1 / 50'), findsOneWidget);

    for (var i = 0; i < 49; i++) {
      await tester.tap(find.byKey(const Key('cook_next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Bước 50 / 50'), findsOneWidget);
    expect(find.text('Bước nấu số 49'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cook_next')), matching: find.text('Hoàn thành')), findsOneWidget);

    await goBack(tester);
  });
}
