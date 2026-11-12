import 'dart:convert';
import 'dart:io';

import 'package:btl_ltdd/features/recipes/domain/legacy_converter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLegacyIngredient: số + đơn vị + tên', () {
    void expectParsed(String line, double? quantity, String? unit, String name) {
      final p = parseLegacyIngredient(line);
      expect(p.quantity, quantity, reason: 'số lượng của "$line"');
      expect(p.unit, unit, reason: 'đơn vị của "$line"');
      expect(p.name, name, reason: 'tên của "$line"');
    }

    test('"200g thịt bò" (số dính liền đơn vị)', () => expectParsed('200g thịt bò', 200, 'g', 'thịt bò'));
    test('"2 quả trứng"', () => expectParsed('2 quả trứng', 2, 'quả', 'trứng'));
    test('phân số "1/2 củ hành"', () => expectParsed('1/2 củ hành', 0.5, 'củ', 'hành'));
    test('hỗn số "1 1/2 chén bột mì"', () => expectParsed('1 1/2 chén bột mì', 1.5, 'chén', 'bột mì'));
    test('dấu phẩy thập phân "0,5 lít sữa tươi"', () => expectParsed('0,5 lít sữa tươi', 0.5, 'lít', 'sữa tươi'));
    test('dấu chấm thập phân "1.5kg thịt"', () => expectParsed('1.5kg thịt', 1.5, 'kg', 'thịt'));
    test('đơn vị nhiều từ "2 muỗng canh nước mắm"', () => expectParsed('2 muỗng canh nước mắm', 2, 'muỗng canh', 'nước mắm'));
    test('đơn vị "thìa cà phê"', () => expectParsed('1 thìa cà phê muối', 1, 'thìa cà phê', 'muối'));
    test('không có đơn vị "3 trứng"', () => expectParsed('3 trứng', 3, null, 'trứng'));
    test('"gói" không bị nhầm với đơn vị "g"', () => expectParsed('2 gói mì', 2, 'gói', 'mì'));
    test('"gram" không bị cắt thành "g"', () => expectParsed('300 gram thịt xay', 300, 'gram', 'thịt xay'));
    test('đơn vị viết hoa được hạ chữ thường', () => expectParsed('200G thịt', 200, 'g', 'thịt'));
    test('ký tự phân số "½ củ hành"', () => expectParsed('½ củ hành', 0.5, 'củ', 'hành'));
    test('số kèm ký tự phân số "1½ chén"', () => expectParsed('1½ chén bột', 1.5, 'chén', 'bột'));
    test('bỏ dấu gạch đầu dòng', () => expectParsed('  - 200g thịt  ', 200, 'g', 'thịt'));
    test('gộp khoảng trắng thừa', () => expectParsed('2   quả    trứng   gà', 2, 'quả', 'trứng gà'));
    test('phần ghi chú trong ngoặc giữ trong tên', () => expectParsed('1 con gà (1.5kg)', 1, 'con', 'gà (1.5kg)'));
    test('chỉ có số và đơn vị thì đơn vị làm tên', () => expectParsed('2 quả', 2, null, 'quả'));
    test('đơn vị tiếng Anh', () => expectParsed('2 tbsp sugar', 2, 'tbsp', 'sugar'));

    test('isStructured đúng khi có số lượng', () {
      expect(parseLegacyIngredient('2 quả trứng').isStructured, isTrue);
      expect(parseLegacyIngredient('muối').isStructured, isFalse);
    });
  });

  group('parseLegacyIngredient: dòng tự do giữ nguyên văn', () {
    void expectFree(String line, String name) {
      final p = parseLegacyIngredient(line);
      expect(p.quantity, isNull, reason: line);
      expect(p.unit, isNull, reason: line);
      expect(p.name, name, reason: line);
    }

    test('"muối vừa đủ"', () => expectFree('muối vừa đủ', 'muối vừa đủ'));
    test('"một ít hành lá" (số viết bằng chữ)', () => expectFree('một ít hành lá', 'một ít hành lá'));
    test('khoảng "2-3 quả ớt" không bị cắt sai', () => expectFree('2-3 quả ớt', '2-3 quả ớt'));
    test('khoảng "2 – 3 quả ớt"', () => expectFree('2 – 3 quả ớt', '2 – 3 quả ớt'));
    test('chỉ có một con số', () => expectFree('5', '5'));
    test('giữ nguyên dấu và ngoặc', () => expectFree('nước mắm, đường (tuỳ thích)', 'nước mắm, đường (tuỳ thích)'));
    test('chuỗi rỗng hoặc chỉ khoảng trắng cho tên rỗng', () {
      expect(parseLegacyIngredient('').name, '');
      expect(parseLegacyIngredient('   ').name, '');
    });
  });

  group('bộ dữ liệu mẫu nguyên liệu cũ (SC-007)', () {
    final rows = (json.decode(File('test/unit/fixtures/legacy_ingredients.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    test('có ít nhất 20 dòng mẫu, gồm cả dòng có cấu trúc và dòng tự do', () {
      expect(rows.length, greaterThanOrEqualTo(20));
      expect(rows.where((r) => r['structured'] == true), isNotEmpty);
      expect(rows.where((r) => r['structured'] == false), isNotEmpty);
    });

    test('từ 90% dòng dạng "số + đơn vị + tên" trở lên được tách đúng', () {
      final structured = rows.where((r) => r['structured'] == true).toList();
      final wrong = <String>[];
      for (final r in structured) {
        final p = parseLegacyIngredient(r['line'] as String);
        final ok = p.quantity == (r['quantity'] as num).toDouble() && p.unit == r['unit'] && p.name == r['name'];
        if (!ok) wrong.add('${r['line']} → ${p.quantity}|${p.unit}|${p.name}');
      }
      final rate = (structured.length - wrong.length) / structured.length;
      expect(rate, greaterThanOrEqualTo(0.9), reason: 'tách sai: $wrong');
    });

    test('mọi dòng tự do đều giữ nguyên văn làm tên, không mất chữ nào', () {
      for (final r in rows.where((r) => r['structured'] == false)) {
        final p = parseLegacyIngredient(r['line'] as String);
        expect(p.isStructured, isFalse, reason: r['line'] as String);
        expect(p.name, r['line'], reason: r['line'] as String);
      }
    });

    test('không dòng nào bị biến thành tên rỗng', () {
      for (final r in rows) {
        expect(parseLegacyIngredient(r['line'] as String).name.trim(), isNotEmpty, reason: r['line'] as String);
      }
    });
  });

  group('splitLegacyInstructions', () {
    test('đánh số "1. ... 2. ..." nhiều dòng', () {
      expect(splitLegacyInstructions('1. Luộc trứng\n2. Kho thịt\n3. Bày ra đĩa'), ['Luộc trứng', 'Kho thịt', 'Bày ra đĩa']);
    });

    test('"Bước 1:" và "Bước 2." ', () {
      expect(splitLegacyInstructions('Bước 1: Luộc trứng\nBước 2. Kho thịt'), ['Luộc trứng', 'Kho thịt']);
    });

    test('"Bước 1" không có dấu và "bước" viết thường', () {
      expect(splitLegacyInstructions('bước 1 Luộc trứng\nBƯỚC 2 Kho thịt'), ['Luộc trứng', 'Kho thịt']);
    });

    test('"1)" và "1 -"', () {
      expect(splitLegacyInstructions('1) Luộc\n2 - Kho'), ['Luộc', 'Kho']);
    });

    test('gạch đầu dòng', () {
      expect(splitLegacyInstructions('- Luộc\n• Kho\n* Bày'), ['Luộc', 'Kho', 'Bày']);
    });

    test('không đánh số: mỗi dòng một bước', () {
      expect(splitLegacyInstructions('Luộc trứng\nKho thịt'), ['Luộc trứng', 'Kho thịt']);
    });

    test('bỏ dòng rỗng và khoảng trắng thừa', () {
      expect(splitLegacyInstructions('\n  1. Luộc  \n\n   \n2. Kho\n'), ['Luộc', 'Kho']);
    });

    test('xuống dòng kiểu Windows', () {
      expect(splitLegacyInstructions('1. Luộc\r\n2. Kho\r\n'), ['Luộc', 'Kho']);
    });

    test('dòng bắt đầu bằng số nhưng không phải số thứ tự được giữ nguyên', () {
      expect(splitLegacyInstructions('2 quả trứng luộc xong thì bóc vỏ'), ['2 quả trứng luộc xong thì bóc vỏ']);
      expect(splitLegacyInstructions('10.5 độ C là nhiệt độ lý tưởng'), ['10.5 độ C là nhiệt độ lý tưởng']);
    });

    test('số thập phân trong câu không bị coi là số thứ tự', () {
      expect(splitLegacyInstructions('Nấu 1.5 giờ cho mềm'), ['Nấu 1.5 giờ cho mềm']);
    });

    test('một đoạn dài gồm nhiều câu được tách theo câu', () {
      const text = 'Luộc trứng trong mười phút rồi ngâm nước lạnh để dễ bóc vỏ. '
          'Thịt ba chỉ cắt miếng vừa ăn, ướp với nước mắm và đường. '
          'Bắc nồi lên bếp, thắng đường lấy màu rồi cho thịt vào đảo đều.';
      final steps = splitLegacyInstructions(text);
      expect(steps, hasLength(3));
      expect(steps.first, startsWith('Luộc trứng'));
      expect(steps[1], startsWith('Thịt ba chỉ'));
      expect(steps.last, endsWith('đảo đều.'));
    });

    test('câu ngắn trên một dòng không bị tách', () {
      expect(splitLegacyInstructions('Luộc trứng. Kho thịt.'), ['Luộc trứng. Kho thịt.']);
    });

    test('đoạn dài không có dấu câu giữ thành một bước', () {
      final text = List.filled(30, 'nấu').join(' ');
      expect(splitLegacyInstructions(text), [text]);
    });

    test('đánh số ngay trên cùng một dòng "1. ... 2. ..." được tách', () {
      expect(
        splitLegacyInstructions('1. Luộc trứng. 2. Kho thịt. 3. Bày ra đĩa.'),
        ['Luộc trứng.', 'Kho thịt.', 'Bày ra đĩa.'],
      );
    });

    test('giữ nguyên nội dung từng bước, chỉ bỏ tiền tố', () {
      expect(splitLegacyInstructions('1. Cho 2 muỗng đường (khoảng 30g) vào chảo!'), ['Cho 2 muỗng đường (khoảng 30g) vào chảo!']);
    });

    test('chuỗi rỗng hoặc chỉ khoảng trắng → rỗng', () {
      expect(splitLegacyInstructions(''), isEmpty);
      expect(splitLegacyInstructions('  \n \r\n  '), isEmpty);
    });

    test('không bao giờ trả về rỗng nếu đầu vào có chữ (kể cả chỉ có tiền tố)', () {
      expect(splitLegacyInstructions('1.'), isNotEmpty);
      expect(splitLegacyInstructions('Bước 1:'), isNotEmpty);
      for (final input in ['1.', 'Bước 3', '2)', 'a']) {
        expect(splitLegacyInstructions(input).join(), isNotEmpty, reason: input);
      }
    });
  });

  group('parseLegacyServings', () {
    test('lấy số đầu tiên trong chuỗi', () {
      expect(parseLegacyServings('4 người'), 4);
      expect(parseLegacyServings('2 serving'), 2);
      expect(parseLegacyServings('Cho 6 người ăn'), 6);
    });

    test('khoảng "4-5 người" lấy số đầu', () => expect(parseLegacyServings('4-5 người'), 4));

    test('không đọc được hoặc ngoài 1–100 thì mặc định 2', () {
      expect(parseLegacyServings(''), 2);
      expect(parseLegacyServings('một vài người'), 2);
      expect(parseLegacyServings('0 người'), 2);
      expect(parseLegacyServings('500'), 2);
      expect(parseLegacyServings(null), 2);
      expect(parseLegacyServings(7), 2); // không phải chuỗi
    });

    test('biên 1 và 100 được nhận', () {
      expect(parseLegacyServings('1 người'), 1);
      expect(parseLegacyServings('100 người'), 100);
    });
  });
}
