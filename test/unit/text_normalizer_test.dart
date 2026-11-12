import 'package:btl_ltdd/features/recipes/domain/text_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeForSearch', () {
    test('chuyển về chữ thường', () => expect(normalizeForSearch('PHỞ BÒ'), 'pho bo'));

    test('bỏ dấu tiếng Việt', () {
      expect(normalizeForSearch('Gà rán'), 'ga ran');
      expect(normalizeForSearch('thịt kho tàu'), 'thit kho tau');
      expect(normalizeForSearch('Bún riêu cua'), 'bun rieu cua');
      expect(normalizeForSearch('cá lóc kho tộ'), 'ca loc kho to');
    });

    test('đ và Đ thành d', () {
      expect(normalizeForSearch('đậu hũ'), 'dau hu');
      expect(normalizeForSearch('ĐẬU PHỤ'), 'dau phu');
      expect(normalizeForSearch('Đường'), 'duong');
    });

    test('đủ mọi nguyên âm có dấu', () {
      expect(normalizeForSearch('àáạảãâầấậẩẫăằắặẳẵ'), 'aaaaaaaaaaaaaaaaa');
      expect(normalizeForSearch('èéẹẻẽêềếệểễ'), 'eeeeeeeeeee');
      expect(normalizeForSearch('ìíịỉĩ'), 'iiiii');
      expect(normalizeForSearch('òóọỏõôồốộổỗơờớợởỡ'), 'ooooooooooooooooo');
      expect(normalizeForSearch('ùúụủũưừứựửữ'), 'uuuuuuuuuuu');
      expect(normalizeForSearch('ỳýỵỷỹ'), 'yyyyy');
    });

    test('chữ hoa có dấu', () {
      expect(normalizeForSearch('ẾỆỂỀỄ'), 'eeeee');
      expect(normalizeForSearch('ỨỰỬỪỮ'), 'uuuuu');
    });

    test('dấu ở dạng tổ hợp (NFD) cũng được bỏ', () {
      // "ế" = e + dấu mũ + dấu sắc; "ờ" = o + dấu móc + dấu huyền
      expect(normalizeForSearch('ế'), 'e');
      expect(normalizeForSearch('Cà phê'), 'ca phe');
      expect(normalizeForSearch('mòn'), 'mon');
    });

    test('gộp nhiều khoảng trắng thành một và cắt hai đầu', () {
      expect(normalizeForSearch('  nhiều   khoảng \t trắng\n'), 'nhieu khoang trang');
    });

    test('khoảng trắng đặc biệt (nbsp) cũng được gộp', () {
      expect(normalizeForSearch('a  b'), 'a b');
    });

    test('chuỗi rỗng và chỉ có khoảng trắng', () {
      expect(normalizeForSearch(''), '');
      expect(normalizeForSearch('   \t  '), '');
    });

    test('số được giữ nguyên', () => expect(normalizeForSearch('Món 30k'), 'mon 30k'));

    test('ký tự đặc biệt không gây lỗi và được giữ nguyên', () {
      expect(normalizeForSearch('(*[+?\\^\$|.){'), '(*[+?\\^\$|.){');
      expect(normalizeForSearch('a/b - c&d'), 'a/b - c&d');
      expect(normalizeForSearch('🍜 phở'), '🍜 pho');
    });

    test('chữ không phải tiếng Việt được giữ lại (chỉ hạ chữ thường)', () {
      expect(normalizeForSearch('Ramen'), 'ramen');
      expect(normalizeForSearch('寿司'), '寿司');
    });

    test('hàm lặp lại cho cùng kết quả (ổn định)', () {
      final once = normalizeForSearch('Gà Rán  Đậu');
      expect(normalizeForSearch(once), once);
    });

    test('hai cách viết cùng một thẻ cho cùng khoá', () {
      expect(normalizeForSearch('Món Sinh Viên'), normalizeForSearch('mon sinh vien'));
      expect(normalizeForSearch('MÓN  SINH VIÊN'), normalizeForSearch('món sinh viên'));
    });
  });
}
