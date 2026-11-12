import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/recipe_editor_provider.dart';
import '../display_helpers.dart';
import 'ingredient_row.dart';

/// Danh sách nguyên liệu kéo để đổi thứ tự, có nút thêm.
class IngredientsSection extends StatelessWidget {
  const IngredientsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecipeEditorProvider>();
    final items = p.draft.ingredients;
    final scheme = Theme.of(context).colorScheme;
    final sectionErrors = [
      for (final code in const ['ingredients_required', 'ingredients_too_many'])
        if (p.errors.contains(code)) recipeErrorMessage(code),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('recipes.ingredients'.tr(), style: Theme.of(context).textTheme.titleMedium),
        for (final message in sectionErrors)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: items.length,
          onReorder: p.moveIngredient,
          itemBuilder: (context, index) {
            final ingredient = items[index];
            return IngredientRow(
              key: ValueKey(ingredient.id),
              ingredient: ingredient,
              errors: p.ingredientErrors(index),
              onChanged: (value) => p.updateIngredient(index, value),
              onFieldInvalid: (field, invalid) => p.setFieldInvalid(ingredient.id, field, invalid),
              onRemove: () => p.removeIngredient(index),
              dragHandle: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: p.addIngredient,
            icon: const Icon(Icons.add),
            label: Text('recipes.add_ingredient'.tr()),
          ),
        ),
      ],
    );
  }
}
