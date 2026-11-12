import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';
import 'quantity_parser.dart';
import 'text_normalizer.dart';

/// Giá trị dự phòng lưu trong dữ liệu để bản chuyển vẫn hợp lệ khi món cũ thiếu
/// nguyên liệu, hướng dẫn hoặc tên. Giao diện không hiện các chuỗi này mà hiện
/// khoá dịch tương ứng (dựa vào `isPlaceholder` hoặc `legacy.title` rỗng).
const String legacyPlaceholderIngredient = '(Chưa có nguyên liệu)';
const String legacyPlaceholderStep = '(Chưa có hướng dẫn)';
const String legacyPlaceholderTitle = '(Món chưa đặt tên)';

// ------------------------------------------------------------------ nguyên liệu

/// Kết quả tách một dòng nguyên liệu cũ dạng chuỗi tự do.
class ParsedIngredient {
  const ParsedIngredient({this.quantity, this.unit, required this.name});

  final double? quantity;
  final String? unit;

  /// Nếu không tách được thì là **nguyên văn** của dòng (đã gộp khoảng trắng).
  final String name;

  /// Tách được số lượng.
  bool get isStructured => quantity != null;
}

/// Các đơn vị thường gặp (tiếng Việt và tiếng Anh). Đơn vị nhiều từ phải được
/// thử trước đơn vị ngắn hơn ("muỗng canh" trước "muỗng").
const List<String> _units = [
  'g', 'gr', 'gram', 'kg', 'mg', 'ml', 'l', 'lít', 'lit',
  'quả', 'trái', 'củ', 'tép', 'nhánh', 'lá', 'miếng', 'lát', 'khúc', 'cục', 'cọng', 'đoạn', 'bắp', 'tờ', 'ổ',
  'muỗng canh', 'muỗng cà phê', 'muỗng nhỏ', 'muỗng', 'thìa canh', 'thìa cà phê', 'thìa nhỏ', 'thìa',
  'chén', 'bát', 'tô', 'cốc', 'ly', 'lon', 'hộp', 'gói', 'bịch', 'chai', 'lọ', 'bó', 'con', 'cây', 'hạt',
  'nhúm', 'chút', 'cái', 'phần',
  'cup', 'cups', 'tbsp', 'tsp', 'oz', 'lb',
];

final RegExp _unitPattern = () {
  final sorted = [..._units]..sort((a, b) => b.length.compareTo(a.length));
  return RegExp(
    '^(?:${sorted.map(RegExp.escape).join('|')})(?![\\p{L}\\p{N}])',
    unicode: true,
  );
}();

const Map<String, double> _vulgar = {'½': 0.5, '¼': 0.25, '¾': 0.75, '⅓': 1 / 3, '⅔': 2 / 3};

final RegExp _leadingNumber = RegExp(
  r'^(?:\d+\s+\d+\s*/\s*\d+|\d+\s*/\s*\d+|\d+(?:[.,]\d+)?[½¼¾⅓⅔]?|[½¼¾⅓⅔])',
);
final RegExp _rangeAfterNumber = RegExp(r'^\s*[-–~]\s*\d');
final RegExp _bulletPrefix = RegExp(r'^[-•*·]\s+');
final RegExp _whitespaceRuns = RegExp(r'\s+');

double? _quantityOf(String numText) {
  final last = numText.isEmpty ? '' : numText[numText.length - 1];
  final fraction = _vulgar[last];
  if (fraction != null) {
    final whole = numText.substring(0, numText.length - 1).trim();
    if (whole.isEmpty) return fraction;
    final w = parseQuantity(whole);
    return w == null ? null : w + fraction;
  }
  return parseQuantity(numText);
}

/// Tách một dòng nguyên liệu cũ thành số lượng, đơn vị và tên.
///
/// Nhận "200g thịt bò", "2 quả trứng", "1/2 củ hành", "1 1/2 chén bột",
/// "0,5 lít sữa", "½ củ hành", "3 trứng" (không đơn vị). Không tách được (ví dụ
/// "muối vừa đủ", "2-3 quả ớt", "một ít hành") thì trả về `quantity = null` và
/// `name` là nguyên văn dòng đó. Dòng rỗng cho `name` rỗng; người gọi nên bỏ qua.
ParsedIngredient parseLegacyIngredient(String line) {
  var text = line.replaceAll(_whitespaceRuns, ' ').trim().replaceFirst(_bulletPrefix, '').trim();
  if (text.isEmpty) return const ParsedIngredient(name: '');
  final raw = text;

  final match = _leadingNumber.firstMatch(text);
  if (match == null) return ParsedIngredient(name: raw);

  final rest = text.substring(match.end);
  if (_rangeAfterNumber.hasMatch(rest)) return ParsedIngredient(name: raw); // "2-3 quả ớt"
  final quantity = _quantityOf(match.group(0)!);
  text = rest.trim();
  if (quantity == null || text.isEmpty) return ParsedIngredient(name: raw);

  String? unit;
  var name = text;
  final unitMatch = _unitPattern.firstMatch(text.toLowerCase());
  if (unitMatch != null) {
    unit = unitMatch.group(0);
    name = text.substring(unitMatch.end).trim();
  }
  if (name.isEmpty) {
    // Chỉ có số và đơn vị ("2 quả"): coi từ đó là tên.
    name = unit ?? text;
    unit = null;
  }
  return ParsedIngredient(quantity: quantity, unit: unit, name: name);
}

// ----------------------------------------------------------------- hướng dẫn

final RegExp _stepPrefix = RegExp(
  r'^(?:(?:bước|buoc|step)\s*\d+\s*[:.)\-–]?|\d+[.)](?=\s)|\d+\s*[:\-–](?=\s)|[-•*·](?=\s))\s*',
  caseSensitive: false,
  unicode: true,
);
final RegExp _inlineNumbering = RegExp(r'(?:^|\s)\d+[.)]\s');
final RegExp _sentenceBreak = RegExp(r'(?<=[.!?…])\s+', unicode: true);

/// Một dòng dài hơn mức này mới được thử tách theo câu.
const int _longLine = 80;

/// Tách hướng dẫn cũ (một đoạn văn) thành các bước.
///
/// - Tách theo dòng, bỏ dòng rỗng và tiền tố đánh số ("1.", "1)", "1 -",
///   "Bước 1:", gạch đầu dòng). Số thập phân ("10.5 độ") không bị coi là số thứ tự.
/// - Nếu chỉ có một dòng: tách tại các số thứ tự nằm cùng dòng ("1. A 2. B"); nếu
///   không có thì một dòng dài (> 80 ký tự) được tách theo câu.
/// - Không bao giờ trả về rỗng nếu đầu vào có chữ.
List<String> splitLegacyInstructions(String text) {
  final lines = text
      .split(RegExp(r'\r\n|\r|\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.isEmpty) return const [];

  var parts = lines;
  if (lines.length == 1) {
    final line = lines.single;
    if (_inlineNumbering.allMatches(line).length >= 2) {
      parts = line.split(RegExp(r'\s+(?=\d+[.)]\s)'));
    }
  }

  var steps = parts.map((l) => l.replaceFirst(_stepPrefix, '').trim()).where((l) => l.isNotEmpty).toList();
  if (steps.isEmpty) return lines; // toàn tiền tố ("Bước 1:"): giữ nguyên, không để mất chữ

  if (steps.length == 1 && steps.single.length > _longLine) {
    final sentences = steps.single.split(_sentenceBreak).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (sentences.length >= 2) steps = sentences;
  }
  return steps;
}

/// Khẩu phần gốc suy ra từ chuỗi cũ như "4 người" hoặc "4-5 người": lấy số
/// nguyên đầu tiên. Không đọc được hoặc ngoài 1–100 thì mặc định 2.
int parseLegacyServings(Object? value) {
  const fallback = 2;
  if (value is! String) return fallback;
  final match = RegExp(r'\d+').firstMatch(value);
  if (match == null) return fallback;
  final n = int.tryParse(match.group(0)!);
  return (n != null && n >= Recipe.minServings && n <= Recipe.maxServings) ? n : fallback;
}

// -------------------------------------------------------------------- chuyển đổi

/// Kết quả chuyển một món cũ.
class LegacyConversion {
  const LegacyConversion(this.recipe, this.unparsedIngredientLines);

  final Recipe recipe;

  /// Số dòng nguyên liệu không tách được (giữ nguyên văn làm tên).
  final int unparsedIngredientLines;
}

String _asString(Object? value) => value is String ? value : '';

String _cut(String text, int max) => text.length <= max ? text : text.substring(0, max).trimRight();

/// Cắt văn bản thành các đoạn không quá [max] ký tự tại khoảng trắng, không mất chữ nào.
List<String> _chunk(String text, int max) {
  if (text.length <= max) return [text];
  final chunks = <String>[];
  var current = StringBuffer();
  void flush() {
    final s = current.toString();
    if (s.isNotEmpty) chunks.add(s);
    current = StringBuffer();
  }

  for (final word in text.split(' ')) {
    var w = word;
    while (w.length > max) {
      flush();
      chunks.add(w.substring(0, max));
      w = w.substring(max);
    }
    if (current.length + (current.isEmpty ? 0 : 1) + w.length > max) flush();
    if (current.isNotEmpty) current.write(' ');
    current.write(w);
  }
  flush();
  return chunks;
}

/// Chuyển dữ liệu một món `foods` (dạng cũ) thành [Recipe] có cấu trúc, đủ điều
/// kiện qua `Recipe.validate()` và rules. Nguyên văn nguyên liệu, hướng dẫn và tên
/// gốc luôn được giữ trong `legacy`. ID nguyên liệu/bước xác định theo [foodId] và
/// vị trí nên chạy lại cho cùng kết quả. Hàm thuần, không đụng tới Firestore: [data] là dữ liệu
/// đã được đổi `Timestamp` thành `DateTime` (xem `decodeFirestoreMap`).
///
/// Quy tắc bù (xem data-model.md): thiếu nguyên liệu/hướng dẫn/tên thì dùng dòng,
/// bước, tên giữ chỗ; quá dài thì cắt hoặc tách; quá nhiều mục thì giữ phần đầu.
LegacyConversion convertLegacyFood({
  required String foodId,
  required String ownerId,
  required Map<String, dynamic> data,
  required DateTime migratedAt,
}) {
  // Tên.
  final originalTitle = _asString(data['title']);
  final trimmedTitle = originalTitle.trim();
  final title = trimmedTitle.isEmpty ? legacyPlaceholderTitle : _cut(trimmedTitle, Recipe.maxTitleLength);

  // Nguyên liệu.
  final rawIngredients = data['ingredients'] is List
      ? [for (final e in data['ingredients'] as List) e is String ? e : (e?.toString() ?? '')]
      : <String>[];
  var unparsed = 0;
  final ingredients = <Ingredient>[];
  for (final line in rawIngredients) {
    if (line.trim().isEmpty) continue;
    final parsed = parseLegacyIngredient(line);
    if (!parsed.isStructured) unparsed++;
    if (ingredients.length >= Recipe.maxIngredients) continue; // phần còn lại nằm trong legacy
    ingredients.add(Ingredient(
      id: '${foodId}_i${ingredients.length}',
      name: _cut(parsed.name, Ingredient.maxNameLength),
      quantity: parsed.quantity,
      unit: parsed.unit,
    ));
  }
  if (ingredients.isEmpty) {
    ingredients.add(Ingredient(id: '${foodId}_i0', name: legacyPlaceholderIngredient, isPlaceholder: true));
  }

  // Các bước.
  final originalInstructions = _asString(data['instructions']);
  final stepTexts = [
    for (final s in splitLegacyInstructions(originalInstructions)) ..._chunk(s, RecipeStep.maxTextLength),
  ];
  final steps = <RecipeStep>[
    for (var i = 0; i < stepTexts.length && i < Recipe.maxSteps; i++)
      RecipeStep(id: '${foodId}_s$i', order: i + 1, text: stepTexts[i]),
  ];
  if (steps.isEmpty) {
    steps.add(RecipeStep(id: '${foodId}_s0', order: 1, text: legacyPlaceholderStep, isPlaceholder: true));
  }

  // Thẻ: tối đa 20, mỗi thẻ ≤ 30 ký tự, bỏ rỗng và trùng.
  final tags = <String>[];
  final seen = <String>{};
  if (data['tags'] is List) {
    for (final t in data['tags'] as List) {
      if (t is! String) continue;
      final tag = _cut(t.trim().replaceAll(_whitespaceRuns, ' '), Recipe.maxTagLength);
      if (tag.isEmpty || !seen.add(normalizeForSearch(tag))) continue;
      if (tags.length < Recipe.maxTags) tags.add(tag);
    }
  }

  // Ghi chú và các thông tin phụ không có chỗ trong mô hình mới.
  final originalNote = _asString(data['note']);
  final extra = <String, dynamic>{
    for (final key in const ['servings', 'time', 'difficulty', 'category', 'videoUrl'])
      if (_asString(data[key]).trim().isNotEmpty) key: data[key],
    if (originalNote.length > Recipe.maxNoteLength) 'note': originalNote,
  };

  final createdAt = data['createdAt'];
  final recipe = Recipe(
    id: foodId,
    ownerId: ownerId,
    title: title,
    imageUrl: _asString(data['imageUrl']),
    baseServings: parseLegacyServings(data['servings']),
    ingredients: ingredients,
    steps: steps,
    tags: tags,
    note: originalNote.length > Recipe.maxNoteLength ? originalNote.substring(0, Recipe.maxNoteLength) : originalNote,
    createdAt: createdAt is DateTime ? createdAt : migratedAt,
    legacy: RecipeLegacy(
      title: originalTitle,
      ingredients: rawIngredients,
      instructions: originalInstructions,
      migratedAt: migratedAt,
      extra: extra,
    ),
  );
  return LegacyConversion(recipe, unparsed);
}
