import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/view/widgets/recipe_card.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Recipe recipe({bool isSyncing = false, int ingredients = 1, int steps = 1}) => Recipe(
        id: 'r1',
        ownerId: 'u',
        title: 'Thịt kho',
        imageUrl: '',
        baseServings: 2,
        ingredients: [for (var i = 0; i < ingredients; i++) Ingredient(id: 'i$i', name: 'thịt')],
        steps: [for (var i = 0; i < steps; i++) RecipeStep(id: 's$i', order: i + 1, text: 'Kho')],
        isSyncing: isSyncing,
      );

  Future<void> pumpCard(WidgetTester tester, Recipe r, {String locale = 'vi'}) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('vi'), Locale('en')],
          path: 'assets/langs',
          fallbackLocale: const Locale('vi'),
          startLocale: Locale(locale),
          saveLocale: false,
          child: Builder(
            builder: (context) => MaterialApp(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              home: Scaffold(
                body: RecipeCard(recipe: r, onTap: () {}, onEdit: () {}, onDelete: () {}),
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

  testWidgets('công thức đã đồng bộ: không hiện nhãn đang đồng bộ', (tester) async {
    await pumpCard(tester, recipe());
    expect(find.byKey(const Key('syncing_r1')), findsNothing);
    expect(find.text('Đang đồng bộ'), findsNothing);
  });

  testWidgets('công thức có thay đổi chưa gửi lên máy chủ: hiện biểu tượng và nhãn đang đồng bộ', (tester) async {
    await pumpCard(tester, recipe(isSyncing: true));
    expect(find.byKey(const Key('syncing_r1')), findsOneWidget);
    expect(find.text('Đang đồng bộ'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });

  testWidgets('vẫn hiện tên và số nguyên liệu/bước khi đang đồng bộ', (tester) async {
    await pumpCard(tester, recipe(isSyncing: true, ingredients: 3, steps: 2));
    expect(find.text('Thịt kho'), findsOneWidget);
    expect(find.text('3 nguyên liệu · 2 bước'), findsOneWidget);
  });

  testWidgets('tiếng Anh: số ít / số nhiều đúng ("1 step", không phải "1 steps")', (tester) async {
    await pumpCard(tester, recipe(), locale: 'en');
    expect(find.text('1 ingredient · 1 step'), findsOneWidget);
  });

  testWidgets('tiếng Anh: nhiều nguyên liệu, nhiều bước', (tester) async {
    await pumpCard(tester, recipe(ingredients: 7, steps: 5), locale: 'en');
    expect(find.text('7 ingredients · 5 steps'), findsOneWidget);
  });
}
