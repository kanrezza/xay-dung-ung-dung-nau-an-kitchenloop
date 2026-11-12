import 'package:btl_ltdd/features/recipes/domain/quantity_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseQuantity', () {
    test('số nguyên', () => expect(parseQuantity('2'), 2));
    test('thập phân dấu phẩy', () => expect(parseQuantity('0,5'), 0.5));
    test('thập phân dấu chấm', () => expect(parseQuantity('0.5'), 0.5));
    test('phân số', () => expect(parseQuantity('1/2'), 0.5));
    test('phân số có khoảng trắng', () => expect(parseQuantity(' 1 / 4 '), 0.25));
    test('hỗn số', () => expect(parseQuantity('1 1/2'), 1.5));
    test('bắt đầu bằng dấu thập phân', () => expect(parseQuantity(',5'), 0.5));
    test('chuỗi rác', () => expect(parseQuantity('abc'), isNull));
    test('chuỗi rỗng', () => expect(parseQuantity(''), isNull));
    test('chỉ khoảng trắng', () => expect(parseQuantity('   '), isNull));
    test('chia cho 0', () => expect(parseQuantity('1/0'), isNull));
    test('số âm không hợp lệ', () => expect(parseQuantity('-2'), isNull));
    test('hai dấu thập phân', () => expect(parseQuantity('1,2,3'), isNull));
    test('số kèm chữ', () => expect(parseQuantity('2g'), isNull));
  });

  group('formatQuantity', () {
    test('null → chuỗi rỗng', () => expect(formatQuantity(null), ''));
    test('số nguyên bỏ phần thập phân', () {
      expect(formatQuantity(2.0, languageCode: 'vi'), '2');
      expect(formatQuantity(2.0, languageCode: 'en'), '2');
    });
    test('dấu thập phân theo ngôn ngữ', () {
      expect(formatQuantity(1.25, languageCode: 'vi'), '1,25');
      expect(formatQuantity(1.25, languageCode: 'en'), '1.25');
    });
    test('mặc định là tiếng Việt', () => expect(formatQuantity(0.5), '0,5'));
    test('làm tròn tối đa 2 chữ số', () {
      expect(formatQuantity(2 / 3, languageCode: 'vi'), '0,67');
      expect(formatQuantity(1.999, languageCode: 'vi'), '2');
      expect(formatQuantity(0.004, languageCode: 'vi'), '0');
    });
    test('bỏ số 0 thừa', () => expect(formatQuantity(1.5, languageCode: 'en'), '1.5'));
    test('số lớn', () => expect(formatQuantity(1250, languageCode: 'en'), '1250'));
  });
}
