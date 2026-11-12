import 'package:btl_ltdd/features/recipes/view/widgets/servings_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final changes = <int>[];

  setUp(changes.clear);

  /// Bao [ServingsStepper] trong một trang giữ trạng thái như màn hình thật.
  Future<void> pumpStepper(WidgetTester tester, {int initial = 2, int min = 1, int max = 100}) async {
    var value = initial;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ServingsStepper(
              value: value,
              min: min,
              max: max,
              onChanged: (v) {
                changes.add(v);
                setState(() => value = v);
              },
            ),
          ),
        ),
      ),
    );
  }

  Finder field() => find.byType(TextField);
  String fieldText(WidgetTester tester) => tester.widget<TextField>(field()).controller!.text;

  Future<void> typeAndSubmit(WidgetTester tester, String text) async {
    await tester.enterText(field(), text);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  testWidgets('hiện giá trị hiện tại', (tester) async {
    await pumpStepper(tester, initial: 4);
    expect(fieldText(tester), '4');
  });

  testWidgets('bấm + tăng 1, bấm − giảm 1', (tester) async {
    await pumpStepper(tester, initial: 2);
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    expect(fieldText(tester), '3');
    expect(changes, [3]);

    await tester.tap(find.byKey(const Key('servings_minus')));
    await tester.pump(); // mỗi lần bấm ngoài đời đều có một khung hình xen giữa
    await tester.tap(find.byKey(const Key('servings_minus')));
    await tester.pump();
    expect(fieldText(tester), '1');
    expect(changes, [3, 2, 1]);
  });

  testWidgets('nút − bị vô hiệu ở mức tối thiểu 1', (tester) async {
    await pumpStepper(tester, initial: 1);
    expect(tester.widget<IconButton>(find.byKey(const Key('servings_minus'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('servings_plus'))).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('servings_minus')), warnIfMissed: false);
    expect(changes, isEmpty);
  });

  testWidgets('nút + bị vô hiệu ở mức tối đa 100', (tester) async {
    await pumpStepper(tester, initial: 100);
    expect(tester.widget<IconButton>(find.byKey(const Key('servings_plus'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('servings_minus'))).onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('servings_plus')), warnIfMissed: false);
    expect(changes, isEmpty);
  });

  testWidgets('nhập số hợp lệ trong 1–100 được nhận ngay', (tester) async {
    await pumpStepper(tester, initial: 2);
    await typeAndSubmit(tester, '7');
    expect(changes, [7]);
    await typeAndSubmit(tester, '100');
    expect(changes, [7, 100]);
    await typeAndSubmit(tester, '1');
    expect(changes, [7, 100, 1]);
  });

  testWidgets('nhập 0 bị từ chối, báo lỗi, rồi trả về giá trị cũ khi xác nhận', (tester) async {
    await pumpStepper(tester, initial: 3);
    await typeAndSubmit(tester, '0');
    expect(changes, isEmpty);
    expect(find.text('recipes.err_servings_invalid'), findsOneWidget);

    await submit(tester);
    expect(fieldText(tester), '3');
    expect(find.text('recipes.err_servings_invalid'), findsNothing);
    expect(changes, isEmpty);
  });

  testWidgets('nhập số âm bị từ chối và giữ giá trị cũ', (tester) async {
    await pumpStepper(tester, initial: 4);
    await typeAndSubmit(tester, '-3');
    expect(changes, isEmpty);
    expect(find.text('recipes.err_servings_invalid'), findsOneWidget);
    await submit(tester);
    expect(fieldText(tester), '4');
  });

  testWidgets('nhập quá 100 bị từ chối và giữ giá trị cũ', (tester) async {
    await pumpStepper(tester, initial: 5);
    await typeAndSubmit(tester, '101');
    expect(changes, isEmpty);
    await submit(tester);
    expect(fieldText(tester), '5');
  });

  testWidgets('xoá trống rồi xác nhận: trả về giá trị cũ', (tester) async {
    await pumpStepper(tester, initial: 6);
    await typeAndSubmit(tester, '');
    expect(changes, isEmpty);
    await submit(tester);
    expect(fieldText(tester), '6');
  });

  testWidgets('ký tự không phải số bị loại ngay khi gõ', (tester) async {
    await pumpStepper(tester, initial: 2);
    await tester.enterText(field(), 'ab3c');
    await tester.pump();
    expect(fieldText(tester), '3');
    expect(changes, [3]);
  });

  testWidgets('sau khi nhập sai, bấm + vẫn tính từ giá trị cũ', (tester) async {
    await pumpStepper(tester, initial: 2);
    await typeAndSubmit(tester, '0');
    await tester.tap(find.byKey(const Key('servings_plus')));
    await tester.pump();
    expect(changes, [3]);
    expect(fieldText(tester), '3');
  });

  testWidgets('giá trị đổi từ bên ngoài được cập nhật vào ô', (tester) async {
    var value = 2;
    late StateSetter outer;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              outer = setState;
              return ServingsStepper(value: value, onChanged: (_) {});
            },
          ),
        ),
      ),
    );
    outer(() => value = 8);
    await tester.pump();
    expect(fieldText(tester), '8');
  });

  testWidgets('giới hạn tuỳ chỉnh được tôn trọng', (tester) async {
    await pumpStepper(tester, initial: 5, min: 2, max: 6);
    await typeAndSubmit(tester, '1');
    expect(changes, isEmpty);
    await typeAndSubmit(tester, '7');
    expect(changes, isEmpty);
    await typeAndSubmit(tester, '6');
    expect(changes, [6]);
    expect(tester.widget<IconButton>(find.byKey(const Key('servings_plus'))).onPressed, isNull);
  });

  testWidgets('bàn phím số nhận dạng số nguyên', (tester) async {
    await pumpStepper(tester);
    final tf = tester.widget<TextField>(field());
    expect(tf.keyboardType, TextInputType.number);
    expect(tf.inputFormatters, isNotEmpty);
    expect(tf.inputFormatters!.first, isA<FilteringTextInputFormatter>());
  });
}
