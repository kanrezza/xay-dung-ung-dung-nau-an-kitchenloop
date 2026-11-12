import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../display_helpers.dart';
import 'recipe_image.dart';

/// Danh sách nguyên liệu (số lượng + đơn vị + tên).
class IngredientsList extends StatelessWidget {
  const IngredientsList({
    super.key,
    required this.recipe,
    required this.languageCode,
    required this.servings,
  });

  final Recipe recipe;
  final String languageCode;

  /// Số người ăn đang xem; số lượng được quy đổi từ khẩu phần gốc của công thức.
  final int servings;

  @override
  Widget build(BuildContext context) {
    final lines = scaledIngredientLines(recipe, servings, languageCode);
    final style = Theme.of(context).textTheme.bodyLarge;
    final bullet = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Icon(Icons.circle, size: 6, color: bullet),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(line, style: style)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Các bước nấu theo thứ tự, kèm thời gian và ảnh nếu có.
class StepsList extends StatelessWidget {
  const StepsList({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final step in recipe.steps)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 14, child: Text('${step.order}')),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stepDisplayText(step)),
                        if (step.durationSec != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: const Icon(Icons.timer_outlined, size: 18),
                              label: Text(formatDuration(step.durationSec!)),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        if (step.imageUrl != null && step.imageUrl!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: RecipeImage(
                              url: step.imageUrl!,
                              height: 140,
                              width: double.infinity,
                              borderRadius: 8,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Nội dung gốc của công thức cũ, hiển thị nguyên văn để đối chiếu.
class LegacySection extends StatelessWidget {
  const LegacySection({super.key, required this.legacy});

  final RecipeLegacy legacy;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    return Card(
      child: ExpansionTile(
        key: const Key('legacy_section'),
        title: Text('recipes.original_content'.tr()),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // Mặc định ExpansionTile căn giữa nội dung mở ra; nguyên văn cần căn trái.
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Bỏ đường kẻ trên/dưới khi mở (đã nằm trong Card).
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          if (legacy.ingredients.isNotEmpty) ...[
            Text('recipes.legacy_ingredients'.tr(), style: titleStyle),
            const SizedBox(height: 4),
            for (final line in legacy.ingredients) Text('• $line'),
            const SizedBox(height: 12),
          ],
          if (legacy.instructions.trim().isNotEmpty) ...[
            Text('recipes.legacy_instructions'.tr(), style: titleStyle),
            const SizedBox(height: 4),
            Text(legacy.instructions),
          ],
        ],
      ),
    );
  }
}
