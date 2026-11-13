import 'package:btl_ltdd/features/planner/domain/shopping_builder.dart';
import 'package:btl_ltdd/features/planner/models/shopping_state.dart';
import 'package:btl_ltdd/features/planner/models/week_plan.dart';
import 'package:btl_ltdd/features/recipes/models/ingredient.dart';
import 'package:btl_ltdd/features/recipes/models/recipe.dart';
import 'package:btl_ltdd/features/recipes/models/recipe_step.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe recipe(String id, String title, int servings, List<Ingredient> ings) => Recipe(
      id: id,
      ownerId: 'u',
      title: title,
      baseServings: servings,
      ingredients: ings,
      steps: const [RecipeStep(id: 's', order: 1, text: 'x')],
    );

MealEntry entry(String recipeId, {int servings = 2, int day = 0, MealSlot slot = MealSlot.dinner, String title = ''}) =>
    MealEntry(id: '$recipeId-$day-${slot.name}', day: day, slot: slot, recipeId: recipeId, title: title, servings: servings);

void main() {
  final weekStart = DateTime(2026, 11, 9);
  final thitKho = recipe('tk', 'Thịt kho', 4, const [
    Ingredient(id: '1', name: 'Trứng', quantity: 4, unit: 'quả'),
    Ingredient(id: '2', name: 'thịt ba chỉ', quantity: 500, unit: 'g'),
    Ingredient(id: '3', name: 'nước mắm', quantity: 3, unit: 'muỗng canh'),
    Ingredient(id: '4', name: 'tiêu xay vừa đủ'),
  ]);
  final trungChien = recipe('tc', 'Trứng chiên', 1, const [
    Ingredient(id: '1', name: 'trứng', quantity: 2, unit: 'Quả'),
    Ingredient(id: '2', name: 'hành lá', quantity: 1, unit: 'nhánh'),
  ]);
  final recipes = {'tk': thitKho, 'tc': trungChien};

  ShoppingItem find(ShoppingListResult r, String name) => r.items.firstWhere((i) => i.name.toLowerCase() == name.toLowerCase());

  test('gộp cùng nguyên liệu từ nhiều món (không phân biệt hoa thường) và ghi rõ món nguồn', () {
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 4), entry('tc', servings: 1, day: 1)]),
      recipes: recipes,
    );
    final egg = find(r, 'trứng');
    expect(egg.quantity, 6);
    expect(egg.unit, 'quả');
    expect(egg.sources, containsAll(['Thịt kho', 'Trứng chiên']));
  });

  test('quy đổi theo số người ăn của từng bữa', () {
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 2)]),
      recipes: recipes,
    );
    expect(find(r, 'thịt ba chỉ').quantity, 250);
    expect(find(r, 'nước mắm').quantity, 1.5);
  });

  test('đơn vị đếm được làm tròn LÊN khi đi chợ', () {
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 3)]),
      recipes: recipes,
    );
    expect(find(r, 'trứng').quantity, 3, reason: '4 × 3/4 = 3');
    final r2 = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 5)]),
      recipes: recipes,
    );
    expect(find(r2, 'trứng').quantity, 5, reason: '4 × 5/4 = 5');
    final r3 = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 1)]),
      recipes: recipes,
    );
    expect(find(r3, 'trứng').quantity, 1);
    final odd = recipe('o', 'Lẻ', 4, const [Ingredient(id: '1', name: 'chanh', quantity: 3, unit: 'quả')]);
    final r4 = buildShoppingList(plan: WeekPlan(weekStart: weekStart, entries: [entry('o', servings: 6)]), recipes: {'o': odd});
    expect(find(r4, 'chanh').quantity, 5, reason: '4,5 quả → mua 5');
  });

  test('g với kg, ml với lít được quy đổi và hiện theo kg/lít khi lớn', () {
    final a = recipe('a', 'A', 1, const [
      Ingredient(id: '1', name: 'thịt bò', quantity: 500, unit: 'g'),
      Ingredient(id: '2', name: 'sữa', quantity: 0.5, unit: 'lít'),
    ]);
    final b = recipe('b', 'B', 1, const [
      Ingredient(id: '1', name: 'Thịt bò', quantity: 1, unit: 'kg'),
      Ingredient(id: '2', name: 'sữa', quantity: 700, unit: 'ml'),
      Ingredient(id: '3', name: 'đường', quantity: 2, unit: 'lạng'),
    ]);
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('a', servings: 1), entry('b', servings: 1)]),
      recipes: {'a': a, 'b': b},
    );
    final beef = find(r, 'thịt bò');
    expect([beef.quantity, beef.unit], [1.5, 'kg']);
    final milk = find(r, 'sữa');
    expect([milk.quantity, milk.unit], [1.2, 'l']);
    final sugar = find(r, 'đường');
    expect([sugar.quantity, sugar.unit], [200, 'g']);
  });

  test('khác loại đơn vị thì không gộp (2 muỗng canh và 100 g là 2 dòng)', () {
    final a = recipe('a', 'A', 1, const [
      Ingredient(id: '1', name: 'đường', quantity: 2, unit: 'muỗng canh'),
      Ingredient(id: '2', name: 'đường', quantity: 100, unit: 'g'),
    ]);
    final r = buildShoppingList(plan: WeekPlan(weekStart: weekStart, entries: [entry('a', servings: 1)]), recipes: {'a': a});
    expect(r.items.where((i) => i.name == 'đường').length, 2);
  });

  test('nguyên liệu không có số lượng: một dòng, không số', () {
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 4), entry('tk', servings: 4, day: 2)]),
      recipes: recipes,
    );
    final pepper = find(r, 'tiêu xay vừa đủ');
    expect(pepper.quantity, isNull);
    expect(r.items.where((i) => i.name == 'tiêu xay vừa đủ').length, 1);
  });

  test('món đã bị xoá khỏi sổ: không tính nguyên liệu, báo tên', () {
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('gone', title: 'Bún chả')]),
      recipes: recipes,
    );
    expect(r.items, isEmpty);
    expect(r.missingRecipes, ['Bún chả']);
  });

  test('bỏ dòng giữ chỗ; món lẻ thêm vào cuối với khoá riêng', () {
    final a = recipe('a', 'A', 1, const [Ingredient(id: '1', name: '(Chưa có nguyên liệu)', isPlaceholder: true)]);
    final r = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('a', servings: 1)]),
      recipes: {'a': a},
      extras: const [ShoppingExtra(id: 'x1', name: 'Giấy bạc', quantity: 1, unit: 'cuộn')],
    );
    expect(r.items.length, 1);
    expect(r.items.single.key, 'extra:x1');
    expect(r.items.single.isExtra, isTrue);
  });

  test('khoá dòng bền: cùng nguyên liệu ở tuần khác vẫn cùng khoá (giữ trạng thái đã mua)', () {
    final r1 = buildShoppingList(plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 4)]), recipes: recipes);
    final r2 = buildShoppingList(
      plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 2), entry('tc', servings: 1)]),
      recipes: recipes,
    );
    expect(find(r1, 'trứng').key, find(r2, 'trứng').key);
    expect(find(r1, 'trứng').key, 'trung|quả');
  });

  test('sắp xếp theo tên không dấu', () {
    final r = buildShoppingList(plan: WeekPlan(weekStart: weekStart, entries: [entry('tk', servings: 4), entry('tc', servings: 1)]), recipes: recipes);
    final names = r.items.map((i) => i.name.toLowerCase()).toList();
    expect(names, ['hành lá', 'nước mắm', 'thịt ba chỉ', 'tiêu xay vừa đủ', 'trứng']);
  });
}
