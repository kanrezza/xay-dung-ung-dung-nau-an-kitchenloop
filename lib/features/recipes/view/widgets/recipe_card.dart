import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../display_helpers.dart';
import 'recipe_image.dart';

enum _CardAction { edit, delete }

/// Một công thức trong danh sách: ảnh, tên, số nguyên liệu/bước, menu sửa/xoá.
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(url: recipe.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipeDisplayTitle(recipe),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${'recipes.n_ingredients'.plural(recipe.ingredients.length)} · '
                      '${'recipes.n_steps'.plural(recipe.steps.length)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
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
                            Text(
                              'recipes.syncing'.tr(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.primary),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_CardAction>(
                onSelected: (action) => action == _CardAction.edit ? onEdit() : onDelete(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: _CardAction.edit, child: Text('common.edit'.tr())),
                  PopupMenuItem(value: _CardAction.delete, child: Text('common.delete'.tr())),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: 64,
      height: 64,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.restaurant_menu, color: scheme.onSurfaceVariant),
    );
    return RecipeImage(url: url, width: 64, height: 64, borderRadius: 8, fallback: fallback);
  }
}
