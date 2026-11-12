/// Bảng bỏ dấu tiếng Việt: chữ thường có dấu → chữ cái gốc.
final Map<int, String> _fold = () {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final map = <int, String>{};
  groups.forEach((base, accented) {
    for (final rune in accented.runes) {
      map[rune] = base;
    }
  });
  return map;
}();

bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

bool _isSpace(int rune) => String.fromCharCode(rune).trim().isEmpty;

/// Chuẩn hoá chuỗi để so khớp khi tìm kiếm: chữ thường, bỏ dấu tiếng Việt
/// (`đ` → `d`), gộp mọi khoảng trắng liên tiếp thành một dấu cách và cắt hai
/// đầu. Dấu ở dạng tổ hợp (NFD) cũng được bỏ. Ký tự đặc biệt, số và chữ không
/// phải tiếng Việt được giữ nguyên.
String normalizeForSearch(String input) {
  final out = StringBuffer();
  var pendingSpace = false;
  for (final rune in input.toLowerCase().runes) {
    if (_isCombiningMark(rune)) continue;
    if (_isSpace(rune)) {
      pendingSpace = out.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      out.write(' ');
      pendingSpace = false;
    }
    out.write(_fold[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}
