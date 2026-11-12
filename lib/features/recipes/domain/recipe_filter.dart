import '../models/recipe.dart';
import 'text_normalizer.dart';

/// Một thẻ dùng để lọc: [key] là dạng đã chuẩn hoá (so khớp), [label] là cách
/// viết gặp đầu tiên (hiển thị), [count] là số công thức có thẻ này.
class TagCount {
  const TagCount({required this.key, required this.label, required this.count});

  final String key;
  final String label;
  final int count;
}

/// Lọc [recipes] theo từ khoá và các thẻ đã chọn. Giữ nguyên thứ tự đầu vào.
///
/// - Từ khoá: tách thành các từ; **mọi** từ phải xuất hiện (thứ tự bất kỳ) trong
///   tên món, tên nguyên liệu hoặc thẻ. Không phân biệt hoa thường và dấu tiếng
///   Việt. So khớp bằng `contains`, không dùng biểu thức chính quy nên ký tự đặc
///   biệt không gây lỗi.
/// - Thẻ: công thức phải có **đủ** mọi thẻ đã chọn (cũng không phân biệt hoa
///   thường và dấu).
/// - Từ khoá rỗng và không chọn thẻ nào: trả về toàn bộ.
List<Recipe> filterRecipes(List<Recipe> recipes, String query, Set<String> selectedTags) {
  final tokens = normalizeForSearch(query).split(' ').where((t) => t.isNotEmpty).toList();
  final wanted = selectedTags.map(normalizeForSearch).where((t) => t.isNotEmpty).toSet();
  if (tokens.isEmpty && wanted.isEmpty) return List.of(recipes);

  return recipes.where((recipe) {
    if (wanted.isNotEmpty) {
      final have = recipe.tags.map(normalizeForSearch).toSet();
      if (!have.containsAll(wanted)) return false;
    }
    if (tokens.isEmpty) return true;
    final haystack = _searchText(recipe);
    return tokens.every(haystack.contains);
  }).toList();
}

String _searchText(Recipe recipe) => normalizeForSearch([
      recipe.title,
      ...recipe.ingredients.map((i) => i.name),
      ...recipe.tags,
    ].join(' '));

/// Thống kê các thẻ đang dùng, nhiều công thức nhất trước, cùng số lượng thì
/// theo tên. Các cách viết khác nhau của một thẻ ("Nhanh", "nhanh") được gộp
/// làm một; mỗi công thức chỉ được đếm một lần cho mỗi thẻ.
List<TagCount> collectTags(List<Recipe> recipes) {
  final labels = <String, String>{};
  final counts = <String, int>{};
  for (final recipe in recipes) {
    final seen = <String>{};
    for (final tag in recipe.tags) {
      final key = normalizeForSearch(tag);
      if (key.isEmpty) continue;
      labels.putIfAbsent(key, () => tag.trim());
      if (seen.add(key)) counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  final result = [
    for (final entry in counts.entries) TagCount(key: entry.key, label: labels[entry.key]!, count: entry.value),
  ];
  result.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    return byCount != 0 ? byCount : a.key.compareTo(b.key);
  });
  return result;
}
