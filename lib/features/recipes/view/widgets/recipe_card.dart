import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../home/view/widgets/recipe_cover.dart';
import '../../models/recipe.dart';
import '../display_helpers.dart';

enum _CardAction { edit, delete }

/// Một công thức trong lưới: ảnh bìa (ảnh thật hoặc minh hoạ), tên, thời gian, khẩu phần,
/// số nguyên liệu/bước, menu sửa/xoá và nhãn "đang đồng bộ".
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final seconds = recipeTotalSeconds(recipe);
    final title = recipeDisplayTitle(recipe);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RecipeCover(title: title, imageUrl: recipe.imageUrl, iconSize: 40),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.28),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<_CardAction>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                        onSelected: (action) => action == _CardAction.edit ? onEdit() : onDelete(),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: _CardAction.edit, child: Text('common.edit'.tr())),
                          PopupMenuItem(value: _CardAction.delete, child: Text('common.delete'.tr())),
                        ],
                      ),
                    ),
                  ),
                  if (seconds > 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _Badge(icon: Icons.schedule, text: formatCookTime(seconds)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${'recipes.n_ingredients'.plural(recipe.ingredients.length)} · '
                    '${'recipes.n_steps'.plural(recipe.steps.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (recipe.isSyncing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        key: Key('syncing_${recipe.id}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 14, color: scheme.primary),
                          const SizedBox(width: 4),
                          Text('recipes.syncing'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ nền tối trên ảnh bìa (thời gian nấu).
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
