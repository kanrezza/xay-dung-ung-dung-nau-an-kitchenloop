final RegExp _mixedNumber = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$');
final RegExp _fraction = RegExp(r'^(\d+)\s*/\s*(\d+)$');
final RegExp _decimal = RegExp(r'^(\d+[.,]?\d*|[.,]\d+)$');

/// Đọc số lượng người dùng nhập. Nhận "2", "0,5", "0.5", "1/2", "1 1/2".
/// Trả về `null` nếu không hợp lệ, là số âm, hoặc chia cho 0.
double? parseQuantity(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;

  final mixed = _mixedNumber.firstMatch(s);
  if (mixed != null) {
    final whole = int.parse(mixed.group(1)!);
    final numerator = int.parse(mixed.group(2)!);
    final denominator = int.parse(mixed.group(3)!);
    if (denominator == 0) return null;
    return whole + numerator / denominator;
  }

  final fraction = _fraction.firstMatch(s);
  if (fraction != null) {
    final numerator = int.parse(fraction.group(1)!);
    final denominator = int.parse(fraction.group(2)!);
    if (denominator == 0) return null;
    return numerator / denominator;
  }

  if (_decimal.hasMatch(s)) {
    return double.tryParse(s.replaceAll(',', '.'));
  }
  return null;
}

/// Định dạng số lượng để hiển thị: làm tròn tối đa 2 chữ số thập phân, bỏ số 0
/// thừa; dấu thập phân là ',' với tiếng Việt và '.' với các ngôn ngữ khác.
String formatQuantity(double? quantity, {String languageCode = 'vi'}) {
  if (quantity == null) return '';
  final rounded = (quantity * 100).round() / 100;
  String text;
  if (rounded == rounded.truncateToDouble()) {
    text = rounded.toInt().toString();
  } else {
    text = rounded.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  }
  return languageCode == 'vi' ? text.replaceAll('.', ',') : text;
}
