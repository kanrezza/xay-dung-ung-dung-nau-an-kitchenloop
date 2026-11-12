import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recipe_repository.dart';
import '../models/recipe.dart';
import '../providers/recipe_editor_provider.dart';
import 'widgets/ingredients_section.dart';
import 'widgets/recipe_basic_fields.dart';
import 'widgets/steps_section.dart';
import 'widgets/tags_field.dart';

/// Tạo hoặc sửa một công thức. Đóng màn hình trả về `id` công thức đã lưu
/// (hoặc `null` nếu người dùng thoát mà không lưu).
class RecipeEditorScreen extends StatelessWidget {
  const RecipeEditorScreen({super.key, this.tagSuggestions = const []});

  /// Các thẻ đã dùng ở công thức khác, gợi ý khi nhập thẻ.
  final List<String> tagSuggestions;

  /// Route kèm [RecipeEditorProvider] riêng cho mỗi lần mở. [existing] != null
  /// nghĩa là đang sửa công thức đó.
  static Route<String?> route(BuildContext context, {Recipe? existing, List<String> tagSuggestions = const []}) {
    final repository = context.read<RecipeRepository>();
    return MaterialPageRoute<String?>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => RecipeEditorProvider(repository: repository, existing: existing),
        child: RecipeEditorScreen(tagSuggestions: tagSuggestions),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final provider = context.read<RecipeEditorProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final id = await provider.save();
      if (id != null) {
        navigator.pop(id);
      } else {
        messenger.showSnackBar(SnackBar(content: Text('recipes.err_fix_errors'.tr())));
      }
    } catch (_) {
      // Lỗi không phải do dữ liệu (ví dụ bị từ chối quyền): giữ nguyên dữ liệu đang nhập.
      messenger.showSnackBar(SnackBar(content: Text('recipes.err_save_failed'.tr())));
    }
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('recipes.unsaved_title'.tr()),
        content: Text('recipes.unsaved_message'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('recipes.keep_editing'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('recipes.discard'.tr()),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecipeEditorProvider>();
    return PopScope<Object?>(
      canPop: !p.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text((p.isEditing ? 'recipes.edit_title' : 'recipes.new_title').tr()),
          actions: [
            if (p.isSaving)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              TextButton(
                key: const Key('save_recipe'),
                onPressed: () => _save(context),
                child: Text('common.save'.tr()),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: [
            const RecipeBasicFields(),
            const SizedBox(height: 16),
            TagsField(suggestions: tagSuggestions),
            const SizedBox(height: 24),
            const IngredientsSection(),
            const SizedBox(height: 24),
            const StepsSection(),
          ],
        ),
      ),
    );
  }
}
