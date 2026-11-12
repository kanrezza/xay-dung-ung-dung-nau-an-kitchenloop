import 'dart:convert';
import 'dart:io';

import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:btl_ltdd/features/recipes/view/display_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> loadJson(String lang) =>
    json.decode(File('assets/langs/$lang.json').readAsStringSync()) as Map<String, dynamic>;

bool hasKey(Map<String, dynamic> root, String key) {
  Object? node = root;
  for (final part in key.split('.')) {
    if (node is Map<String, dynamic> && node.containsKey(part)) {
      node = node[part];
    } else {
      return false;
    }
  }
  return node is String;
}

void main() {
  group('mọi mã lỗi có bản dịch', () {
    // Tất cả mã lỗi mà Ingredient/RecipeStep/Recipe.validate() và provider có thể sinh ra.
    const codes = [
      'title_required', 'title_too_long', 'servings_invalid', 'ingredients_required',
      'ingredients_too_many', 'steps_required', 'steps_too_many', 'steps_order_invalid',
      'tags_too_many', 'tag_invalid', 'note_too_long',
      'name_invalid', 'quantity_negative', 'quantity_invalid', 'unit_too_long',
      'price_negative', 'price_invalid', 'kcal_negative', 'kcal_invalid',
      'text_invalid', 'order_invalid', 'duration_invalid',
    ];

    for (final lang in ['vi', 'en']) {
      test('khoá dịch $lang', () {
        final root = loadJson(lang);
        for (final code in codes) {
          final key = recipeErrorKey(code);
          expect(hasKey(root, key), isTrue, reason: 'thiếu $lang.$key cho mã lỗi $code');
        }
      });
    }

    test('ánh xạ đặc biệt cho nguyên liệu/bước bắt buộc', () {
      expect(recipeErrorKey('ingredients_required'), 'recipes.err_no_ingredient');
      expect(recipeErrorKey('steps_required'), 'recipes.err_no_step');
      expect(recipeErrorKey('title_required'), 'recipes.err_title_required');
    });
  });

  group('ingredientLine', () {
    test('số lượng + đơn vị + tên', () {
      const i = Ingredient(id: 'a', name: 'thịt bò', quantity: 200, unit: 'g');
      expect(ingredientLine(i, 'vi'), '200 g thịt bò');
    });
    test('thập phân theo ngôn ngữ', () {
      const i = Ingredient(id: 'a', name: 'sữa', quantity: 1.5, unit: 'l');
      expect(ingredientLine(i, 'vi'), '1,5 l sữa');
      expect(ingredientLine(i, 'en'), '1.5 l sữa');
    });
    test('không có số lượng thì chỉ hiện tên', () {
      const i = Ingredient(id: 'a', name: 'muối');
      expect(ingredientLine(i, 'vi'), 'muối');
    });
    test('có số lượng nhưng không đơn vị', () {
      const i = Ingredient(id: 'a', name: 'trứng', quantity: 2);
      expect(ingredientLine(i, 'vi'), '2 trứng');
    });
  });

  group('formatDuration', () {
    test('dưới 1 giờ', () => expect(formatDuration(330), '5:30'));
    test('dưới 1 phút', () => expect(formatDuration(45), '0:45'));
    test('từ 1 giờ', () => expect(formatDuration(3930), '1:05:30'));
  });

  group('tên hiển thị khi có chuỗi giữ chỗ', () {
    // Gọi .tr() ngoài EasyLocalization trả về chính khoá, đủ để phân biệt nhánh.
    Recipe recipeWith({RecipeLegacy? legacy, String title = 'x'}) => Recipe(
          id: 'r',
          ownerId: 'u',
          title: title,
          baseServings: 2,
          ingredients: const [Ingredient(id: 'i', name: 'x')],
          steps: const [RecipeStep(id: 's', order: 1, text: 'y')],
          legacy: legacy,
        );

    test('công thức thường giữ nguyên tên', () {
      expect(recipeDisplayTitle(recipeWith(title: 'Phở')), 'Phở');
    });
    test('bản chuyển có legacy.title rỗng dùng khoá tên giữ chỗ', () {
      final r = recipeWith(
        title: '(Món chưa đặt tên)',
        legacy: const RecipeLegacy(title: '', ingredients: [], instructions: ''),
      );
      expect(recipeDisplayTitle(r), 'recipes.placeholder_title');
    });
    test('bản chuyển có tên gốc thì giữ tên', () {
      final r = recipeWith(
        title: 'Bún bò',
        legacy: const RecipeLegacy(title: 'Bún bò', ingredients: [], instructions: ''),
      );
      expect(recipeDisplayTitle(r), 'Bún bò');
    });
    test('dòng và bước giữ chỗ dùng khoá dịch', () {
      expect(
        ingredientDisplayName(const Ingredient(id: 'a', name: '(Chưa có nguyên liệu)', isPlaceholder: true)),
        'recipes.placeholder_ingredient',
      );
      expect(
        stepDisplayText(const RecipeStep(id: 's', order: 1, text: '(Chưa có hướng dẫn)', isPlaceholder: true)),
        'recipes.placeholder_step',
      );
      expect(stepDisplayText(const RecipeStep(id: 's', order: 1, text: 'Chiên')), 'Chiên');
    });
  });
}
