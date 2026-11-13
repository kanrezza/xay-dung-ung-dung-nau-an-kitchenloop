import 'package:flutter/material.dart';

import '../../../recipes/domain/text_normalizer.dart';
import '../../../recipes/view/widgets/recipe_image.dart';

/// Loại món, đoán từ tên để chọn ảnh minh hoạ khi công thức chưa có ảnh.
class DishStyle {
  const DishStyle(this.icon, this.colors);

  final IconData icon;
  final List<Color> colors;
}

const _styles = <String, DishStyle>{
  'soup': DishStyle(Icons.soup_kitchen, [Color(0xFFFF8A65), Color(0xFFE64A19)]),
  'noodle': DishStyle(Icons.ramen_dining, [Color(0xFFFFCA28), Color(0xFFF57C00)]),
  'egg': DishStyle(Icons.egg_alt, [Color(0xFFFFF176), Color(0xFFFBC02D)]),
  'fish': DishStyle(Icons.set_meal, [Color(0xFF4FC3F7), Color(0xFF0277BD)]),
  'chicken': DishStyle(Icons.kebab_dining, [Color(0xFFFFB74D), Color(0xFFE65100)]),
  'meat': DishStyle(Icons.outdoor_grill, [Color(0xFFE57373), Color(0xFFB71C1C)]),
  'salad': DishStyle(Icons.eco, [Color(0xFFAED581), Color(0xFF388E3C)]),
  'rice': DishStyle(Icons.rice_bowl, [Color(0xFFBCAAA4), Color(0xFF6D4C41)]),
  'dessert': DishStyle(Icons.cake, [Color(0xFFF48FB1), Color(0xFFC2185B)]),
  'pasta': DishStyle(Icons.dinner_dining, [Color(0xFFFFD54F), Color(0xFFEF6C00)]),
  'drink': DishStyle(Icons.local_cafe, [Color(0xFFA1887F), Color(0xFF4E342E)]),
  'default': DishStyle(Icons.restaurant, [Color(0xFFFFB74D), Color(0xFFEF6C00)]),
};

/// Từ khoá (đã bỏ dấu) → loại món.
const _keywords = <String, String>{
  'canh': 'soup', 'sup': 'soup', 'lau': 'soup', 'chao': 'soup', 'soup': 'soup',
  'pho': 'noodle', 'bun': 'noodle', 'mi': 'noodle', 'mien': 'noodle', 'hu tieu': 'noodle', 'banh canh': 'noodle', 'ramen': 'noodle', 'noodle': 'noodle',
  'trung': 'egg', 'egg': 'egg', 'omelet': 'egg',
  'ca': 'fish', 'tom': 'fish', 'muc': 'fish', 'cua': 'fish', 'hai san': 'fish', 'oc': 'fish', 'fish': 'fish', 'shrimp': 'fish',
  'ga': 'chicken', 'vit': 'chicken', 'chicken': 'chicken',
  'thit': 'meat', 'bo': 'meat', 'heo': 'meat', 'lon': 'meat', 'suon': 'meat', 'beef': 'meat', 'pork': 'meat', 'steak': 'meat',
  'salad': 'salad', 'rau': 'salad', 'goi': 'salad', 'chay': 'salad', 'nom': 'salad',
  'com': 'rice', 'xoi': 'rice', 'rice': 'rice',
  'banh': 'dessert', 'che': 'dessert', 'kem': 'dessert', 'cake': 'dessert', 'flan': 'dessert',
  'mi y': 'pasta', 'spaghetti': 'pasta', 'pasta': 'pasta', 'nui': 'pasta',
  'tra': 'drink', 'nuoc ep': 'drink', 'sinh to': 'drink', 'ca phe': 'drink', 'smoothie': 'drink',
};

/// Chọn loại món theo từ khoá xuất hiện SỚM NHẤT trong tên ("Thịt kho trứng" → thịt,
/// "Trứng chiên hành" → trứng). Từ khoá dài thắng khi cùng vị trí ("mì ý" hơn "mì").
DishStyle dishStyleFor(String title) {
  final text = ' ${normalizeForSearch(title)} ';
  var best = 'default';
  var bestPos = 1 << 30;
  var bestLen = 0;
  _keywords.forEach((kw, kind) {
    final pos = text.indexOf(' $kw ');
    if (pos < 0) return;
    if (pos < bestPos || (pos == bestPos && kw.length > bestLen)) {
      best = kind;
      bestPos = pos;
      bestLen = kw.length;
    }
  });
  return _styles[best]!;
}

/// Ảnh bìa công thức: ảnh thật nếu có, nếu không thì nền chuyển màu + biểu tượng theo loại món.
class RecipeCover extends StatelessWidget {
  const RecipeCover({
    super.key,
    required this.title,
    required this.imageUrl,
    this.height,
    this.width,
    this.borderRadius = 0,
    this.iconSize = 48,
  });

  final String title;
  final String imageUrl;
  final double? height;
  final double? width;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final style = dishStyleFor(title);
    final illustration = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        key: const Key('recipe_cover_illustration'),
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: style.colors),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -iconSize * 0.35,
              bottom: -iconSize * 0.35,
              child: Icon(style.icon, size: iconSize * 2.2, color: Colors.white.withValues(alpha: 0.18)),
            ),
            Center(child: Icon(style.icon, size: iconSize, color: Colors.white)),
          ],
        ),
      ),
    );
    if (imageUrl.isEmpty) return illustration;
    return RecipeImage(url: imageUrl, width: width, height: height, borderRadius: borderRadius, fallback: illustration);
  }
}
