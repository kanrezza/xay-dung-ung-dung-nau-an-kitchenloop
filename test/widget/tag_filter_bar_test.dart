import 'package:btl_ltdd/features/recipes/domain/recipe_filter.dart';
import 'package:btl_ltdd/features/recipes/view/widgets/tag_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tags = [
    TagCount(key: 'mon sinh vien', label: 'Món sinh viên', count: 3),
    TagCount(key: 'nhanh', label: 'nhanh', count: 2),
    TagCount(key: 'an kieng', label: 'ăn kiêng', count: 1),
  ];

  /// Bao thanh thẻ trong một trang giữ trạng thái chọn như màn hình thật.
  Future<List<String>> pumpBar(WidgetTester tester, {List<TagCount> items = tags, Set<String>? initial}) async {
    final toggled = <String>[];
    final selected = {...?initial};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TagFilterBar(
              tags: items,
              selected: selected,
              onToggle: (key) {
                toggled.add(key);
                setState(() => selected.contains(key) ? selected.remove(key) : selected.add(key));
              },
            ),
          ),
        ),
      ),
    );
    return toggled;
  }

  bool isSelected(WidgetTester tester, String key) =>
      tester.widget<FilterChip>(find.byKey(Key('tag_chip_$key'))).selected;

  testWidgets('không có thẻ thì không hiện gì', (tester) async {
    await pumpBar(tester, items: const []);
    expect(find.byType(FilterChip), findsNothing);
  });

  testWidgets('mỗi thẻ hiện kèm số công thức', (tester) async {
    await pumpBar(tester);
    expect(find.text('Món sinh viên (3)'), findsOneWidget);
    expect(find.text('nhanh (2)'), findsOneWidget);
    expect(find.text('ăn kiêng (1)'), findsOneWidget);
  });

  testWidgets('thẻ đang chọn được đánh dấu', (tester) async {
    await pumpBar(tester, initial: {'nhanh'});
    expect(isSelected(tester, 'nhanh'), isTrue);
    expect(isSelected(tester, 'mon sinh vien'), isFalse);
  });

  testWidgets('bấm một thẻ gọi onToggle với khoá chuẩn hoá của thẻ', (tester) async {
    final toggled = await pumpBar(tester);
    await tester.tap(find.byKey(const Key('tag_chip_mon sinh vien')));
    await tester.pump();
    expect(toggled, ['mon sinh vien']);
    expect(isSelected(tester, 'mon sinh vien'), isTrue);
  });

  testWidgets('chọn nhiều thẻ cùng lúc, bấm lại để bỏ chọn', (tester) async {
    await pumpBar(tester);
    await tester.tap(find.byKey(const Key('tag_chip_nhanh')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('tag_chip_an kieng')));
    await tester.pump();
    expect(isSelected(tester, 'nhanh'), isTrue);
    expect(isSelected(tester, 'an kieng'), isTrue);

    await tester.tap(find.byKey(const Key('tag_chip_nhanh')));
    await tester.pump();
    expect(isSelected(tester, 'nhanh'), isFalse);
    expect(isSelected(tester, 'an kieng'), isTrue);
  });

  testWidgets('nhiều thẻ thì cuộn ngang được', (tester) async {
    final many = [for (var i = 0; i < 30; i++) TagCount(key: 'the$i', label: 'thẻ số $i', count: 1)];
    await pumpBar(tester, items: many);
    expect(find.byKey(const Key('tag_chip_the29')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const Key('tag_chip_the29')), 300, scrollable: find.byType(Scrollable));
    expect(find.byKey(const Key('tag_chip_the29')), findsOneWidget);
  });
}
