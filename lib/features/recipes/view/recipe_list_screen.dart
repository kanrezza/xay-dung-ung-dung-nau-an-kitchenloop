import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../providers/recipe_list_provider.dart';
import 'recipe_detail_screen.dart';
import 'recipe_editor_screen.dart';
import 'widgets/recipe_card.dart';
import 'widgets/tag_filter_bar.dart';

/// Tab Công thức: lưới công thức riêng của người dùng, tìm kiếm và lọc theo thẻ.
class RecipeListScreen extends StatefulWidget {
  const RecipeListScreen({super.key});

  @override
  State<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends State<RecipeListScreen> {
  bool _noticeScheduled = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RecipeListProvider>().runMigrationIfNeeded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Giữ ô tìm kiếm khớp với từ khoá của provider (ví dụ khi bộ lọc bị xoá hoặc đăng xuất).
  void _syncSearchField(RecipeListProvider provider) {
    if (_searchController.text == provider.query) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _searchController.text == provider.query) return;
      _searchController.value = TextEditingValue(
        text: provider.query,
        selection: TextSelection.collapsed(offset: provider.query.length),
      );
    });
  }

  void _showMigrationNoticeIfAny(RecipeListProvider provider) {
    final result = provider.lastMigration;
    if (result == null || _noticeScheduled) return;
    _noticeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noticeScheduled = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('recipes.migrated_summary'.tr(
          args: ['${result.migrated}', '${result.unparsedIngredientLines}'],
        )),
      ));
      provider.clearMigrationNotice();
    });
  }

  Future<void> _confirmDelete(Recipe recipe) async {
    final provider = context.read<RecipeListProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('recipes.delete_title'.tr()),
        content: Text('common.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.delete(recipe.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('recipes.err_save_failed'.tr())));
    }
  }

  void _openEditor([Recipe? existing]) {
    final suggestions = context.read<RecipeListProvider>().availableTags.map((t) => t.label).toList();
    Navigator.push(context, RecipeEditorScreen.route(context, existing: existing, tagSuggestions: suggestions));
  }

  void _openDetail(Recipe recipe) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => RecipeDetailScreen(recipeId: recipe.id)),
      );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RecipeListProvider>();
    _showMigrationNoticeIfAny(provider);
    _syncSearchField(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text('recipes.title'.tr()),
      ),
      // Danh sách trống đã có nút "Thêm công thức" ở giữa màn hình; không hiện thêm nút nổi.
      floatingActionButton: _showsEmptyState(provider)
          ? null
          : FloatingActionButton.extended(
              key: const Key('add_recipe'),
              onPressed: _openEditor,
              icon: const Icon(Icons.add),
              label: Text('recipes.add'.tr()),
            ),
      body: _buildBody(provider),
    );
  }

  bool _showsEmptyState(RecipeListProvider provider) =>
      provider.isEmpty && !provider.isLoading && provider.error == null;

  Widget _buildBody(RecipeListProvider provider) {
    if (provider.isEmpty && provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.isEmpty && provider.error != null) {
      return _MessageView(icon: Icons.error_outline, message: 'recipes.err_load_failed'.tr());
    }
    if (provider.isEmpty) {
      return _MessageView(
        icon: Icons.restaurant_menu,
        message: 'recipes.empty'.tr(),
        actionLabel: 'recipes.add'.tr(),
        onAction: _openEditor,
      );
    }
    return Column(
      children: [
        _SearchAndTags(
          controller: _searchController,
          provider: provider,
        ),
        Expanded(
          child: provider.isFilteredEmpty
              ? _MessageView(
                  icon: Icons.search_off,
                  message: 'recipes.empty_filtered'.tr(),
                  actionLabel: 'recipes.clear_filters'.tr(),
                  actionKey: const Key('clear_filters'),
                  actionIcon: Icons.filter_alt_off,
                  onAction: provider.clearFilters,
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  // Lưới 2 cột trên điện thoại, nhiều cột hơn trên máy tính bảng.
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: provider.filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = provider.filteredRecipes[index];
                    return RecipeCard(
                      key: ValueKey(recipe.id),
                      recipe: recipe,
                      onTap: () => _openDetail(recipe),
                      onEdit: () => _openEditor(recipe),
                      onDelete: () => _confirmDelete(recipe),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Ô tìm kiếm và hàng thẻ lọc ở đầu danh sách.
class _SearchAndTags extends StatelessWidget {
  const _SearchAndTags({required this.controller, required this.provider});

  final TextEditingController controller;
  final RecipeListProvider provider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('search_field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'recipes.search_hint'.tr(),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: provider.query.isEmpty
                  ? null
                  : IconButton(
                      key: const Key('clear_search'),
                      tooltip: 'recipes.search_clear'.tr(),
                      icon: const Icon(Icons.close),
                      onPressed: () => provider.setQuery(''),
                    ),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onChanged: provider.setQuery,
          ),
        ),
        TagFilterBar(tags: provider.availableTags, selected: provider.selectedTags, onToggle: provider.toggleTag),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionKey = const Key('empty_add_recipe'),
    this.actionIcon = Icons.add,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key actionKey;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                key: actionKey,
                onPressed: onAction,
                icon: Icon(actionIcon),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
