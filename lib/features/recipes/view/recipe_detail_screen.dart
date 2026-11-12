import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipe_repository.dart';
import '../models/recipe.dart';
import '../providers/recipe_list_provider.dart';
import 'cooking_mode_screen.dart';
import 'display_helpers.dart';
import 'recipe_editor_screen.dart';
import 'widgets/recipe_image.dart';
import 'widgets/recipe_sections.dart';
import 'widgets/servings_stepper.dart';

/// Xem một công thức: ảnh, tên, ghi chú, nguyên liệu, các bước, nội dung gốc.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late final Stream<Recipe?> _stream;
  late final RecipeRepository _repository;

  /// Khẩu phần đang xem; chỉ để quy đổi hiển thị, không bao giờ ghi vào công thức.
  int? _viewServings;
  int? _lastBaseServings;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RecipeRepository>();
    _stream = _repository.watchRecipe(widget.recipeId);
  }

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
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
    navigator.pop(); // thoát trước để không thấy màn hình "không tìm thấy"
    try {
      await _repository.delete(widget.recipeId);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('recipes.err_save_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Recipe?>(
      stream: _stream,
      builder: (context, snapshot) {
        final recipe = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting && recipe == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        if (recipe == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('recipes.not_found'.tr())),
          );
        }
        return _buildRecipe(context, recipe);
      },
    );
  }

  Widget _buildRecipe(BuildContext context, Recipe recipe) {
    final lang = context.locale.languageCode;
    // Khẩu phần gốc đổi (ví dụ vừa sửa công thức): quay về xem theo khẩu phần gốc mới.
    if (_lastBaseServings != recipe.baseServings) {
      _lastBaseServings = recipe.baseServings;
      _viewServings = null;
    }
    final servings = _viewServings ?? recipe.baseServings;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      // Không đặt tiêu đề trên thanh trên cùng: tên món (có thể dài, xuống dòng) đã
      // hiện to ngay đầu nội dung, đặt cả hai chỗ bị lặp.
      appBar: AppBar(
        actions: [
          IconButton(
            key: const Key('edit_recipe'),
            tooltip: 'common.edit'.tr(),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(
              context,
              RecipeEditorScreen.route(
                context,
                existing: recipe,
                tagSuggestions: context.read<RecipeListProvider>().availableTags.map((t) => t.label).toList(),
              ),
            ),
          ),
          IconButton(
            key: const Key('delete_recipe'),
            tooltip: 'common.delete'.tr(),
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          if (recipe.imageUrl.isNotEmpty)
            RecipeImage(url: recipe.imageUrl, height: 200, width: double.infinity, borderRadius: 12),
          const SizedBox(height: 12),
          Text(recipeDisplayTitle(recipe), style: textTheme.headlineSmall),
          if (recipe.isSyncing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                key: const Key('detail_syncing'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('recipes.syncing'.tr(), style: textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text('recipes.f_servings'.tr(), style: textTheme.labelLarge),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: ServingsStepper(
              value: servings,
              onChanged: (value) => setState(() => _viewServings = value),
            ),
          ),
          if (servings != recipe.baseServings)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('recipes.servings_original'.plural(recipe.baseServings), style: textTheme.bodySmall),
            ),
          const SizedBox(height: 16),
          // Từ danh sách chỉ cần 2 chạm để bắt đầu nấu: chọn món rồi bấm nút này.
          FilledButton.icon(
            key: const Key('start_cooking'),
            onPressed: () => Navigator.push(context, CookingModeScreen.route(context, recipe, servings: servings)),
            icon: const Icon(Icons.play_arrow),
            label: Text('recipes.start_cooking'.tr(), style: const TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          ),
          if (recipe.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [for (final tag in recipe.tags) Chip(label: Text(tag))]),
          ],
          if (recipe.note.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(recipe.note),
          ],
          const SizedBox(height: 20),
          Text('recipes.ingredients'.tr(), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          IngredientsList(recipe: recipe, languageCode: lang, servings: servings),
          const SizedBox(height: 20),
          Text('recipes.steps'.tr(), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          StepsList(recipe: recipe),
          if (recipe.legacy != null) ...[
            const SizedBox(height: 20),
            LegacySection(legacy: recipe.legacy!),
          ],
        ],
      ),
    );
  }
}
