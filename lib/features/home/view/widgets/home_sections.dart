import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../planner/models/week_plan.dart';
import '../../../planner/view/widgets/add_meal_sheet.dart';
import '../../../recipes/models/cooking_session.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/view/display_helpers.dart';
import 'recipe_cover.dart';

/// Tiêu đề một mục trên trang chủ, kèm nút phụ bên phải (tuỳ chọn).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Ô số liệu nhanh.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.value, required this.label, this.onTap});

  final IconData icon;
  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.onSecondaryContainer),
              const SizedBox(height: 8),
              Text('$value', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer)),
              Text(label, maxLines: 2, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một món của hôm nay (thẻ ngang có ảnh nhỏ, bữa, số người).
class TodayMealTile extends StatelessWidget {
  const TodayMealTile({super.key, required this.entry, required this.recipe, required this.onTap});

  final MealEntry entry;
  final Recipe? recipe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              RecipeCover(title: entry.title, imageUrl: recipe?.imageUrl ?? '', width: 56, height: 56, borderRadius: 12, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(slotIcon(entry.slot), size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(slotLabel(entry.slot), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                    Text('planner.servings_n'.plural(entry.servings), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ "nấu tiếp" một món đang nấu dở.
class ContinueCookingCard extends StatelessWidget {
  const ContinueCookingCard({super.key, required this.recipe, required this.session, required this.onTap});

  final Recipe recipe;
  final CookingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = recipe.steps.length;
    final step = (session.stepIndex + 1).clamp(1, total == 0 ? 1 : total);
    return Card(
      color: scheme.tertiaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              RecipeCover(title: recipe.title, imageUrl: recipe.imageUrl, width: 64, height: 64, borderRadius: 14, iconSize: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipeDisplayTitle(recipe), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: total == 0 ? 0 : step / total, minHeight: 6),
                    ),
                    const SizedBox(height: 4),
                    Text('recipes.step_of'.tr(args: ['$step', '$total']), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                child: const Icon(Icons.play_arrow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ gợi ý trong dải cuộn ngang.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key, required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secs = recipeTotalSeconds(recipe);
    return SizedBox(
      width: 164,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: RecipeCover(title: recipe.title, imageUrl: recipe.imageUrl, iconSize: 36)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipeDisplayTitle(recipe), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [if (secs > 0) formatCookTime(secs), 'recipes.info_servings'.plural(recipe.baseServings)].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
