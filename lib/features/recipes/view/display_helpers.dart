import 'package:easy_localization/easy_localization.dart';

import '../domain/quantity_parser.dart';
import '../domain/serving_scaler.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';
import '../models/recipe_step.dart';

/// Mã lỗi (từ `validate()`) → khoá dịch. Mã lỗi có chỉ số như
/// `ingredients[2].name_invalid` phải được bỏ phần tiền tố trước khi gọi.
String recipeErrorKey(String code) {
  switch (code) {
    case 'ingredients_required':
      return 'recipes.err_no_ingredient';
    case 'steps_required':
      return 'recipes.err_no_step';
    default:
      return 'recipes.err_$code';
  }
}

/// Thông báo lỗi đã dịch cho một mã lỗi không có chỉ số.
String recipeErrorMessage(String code) => recipeErrorKey(code).tr();

/// Tên món để hiển thị: tên giữ chỗ được dịch theo ngôn ngữ đang chọn.
String recipeDisplayTitle(Recipe recipe) {
  final legacy = recipe.legacy;
  if (legacy != null && legacy.title.trim().isEmpty) return 'recipes.placeholder_title'.tr();
  return recipe.title;
}

/// Tên nguyên liệu để hiển thị (dòng giữ chỗ được dịch).
String ingredientDisplayName(Ingredient ingredient) =>
    ingredient.isPlaceholder ? 'recipes.placeholder_ingredient'.tr() : ingredient.name;

/// Nội dung bước để hiển thị (bước giữ chỗ được dịch).
String stepDisplayText(RecipeStep step) =>
    step.isPlaceholder ? 'recipes.placeholder_step'.tr() : step.text;

/// "200 g thịt bò", "2 quả trứng"; nguyên liệu không có số lượng chỉ hiện tên.
String ingredientLine(Ingredient ingredient, String languageCode) {
  final name = ingredientDisplayName(ingredient);
  if (ingredient.isPlaceholder) return name;
  final qty = formatQuantity(ingredient.quantity, languageCode: languageCode);
  final unit = (ingredient.unit ?? '').trim();
  return [qty, unit, name].where((s) => s.isNotEmpty).join(' ');
}

/// "1 giờ 5 phút 30 giây" dưới dạng ngắn gọn "1:05:30" hoặc "5:30".
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Các dòng nguyên liệu đã quy đổi sang [servings] người ăn (chỉ để hiển thị,
/// không đổi công thức). Dữ liệu khẩu phần không hợp lệ thì hiện số lượng gốc.
List<String> scaledIngredientLines(Recipe recipe, int servings, String languageCode) {
  final canScale = recipe.baseServings > 0 && servings > 0;
  return [
    for (final ingredient in recipe.ingredients)
      ingredientLine(
        canScale ? scaleIngredient(ingredient, recipe.baseServings, servings) : ingredient,
        languageCode,
      ),
  ];
}
