import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/recipe_editor_provider.dart';
import '../display_helpers.dart';
import 'image_picking.dart';
import 'recipe_image.dart';

/// Ảnh đại diện, tên món, số người ăn gốc và ghi chú.
class RecipeBasicFields extends StatefulWidget {
  const RecipeBasicFields({super.key});

  @override
  State<RecipeBasicFields> createState() => _RecipeBasicFieldsState();
}

class _RecipeBasicFieldsState extends State<RecipeBasicFields> {
  late final TextEditingController _title;
  late final TextEditingController _servings;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final draft = context.read<RecipeEditorProvider>().draft;
    _title = TextEditingController(text: draft.title);
    _servings = TextEditingController(text: draft.baseServings > 0 ? '${draft.baseServings}' : '');
    _note = TextEditingController(text: draft.note);
  }

  @override
  void dispose() {
    _title.dispose();
    _servings.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _error(List<String> errors, List<String> codes) {
    for (final code in codes) {
      if (errors.contains(code)) return recipeErrorMessage(code);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecipeEditorProvider>();
    final errors = p.errors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverImage(
          url: p.draft.imageUrl,
          isUploading: p.isUploading,
          onPick: () async {
            final url = await pickAndUploadImage(context);
            if (url != null) p.setImageUrl(url);
          },
          onRemove: () => p.setImageUrl(''),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'recipes.f_title'.tr(),
            errorText: _error(errors, ['title_required', 'title_too_long']),
            border: const OutlineInputBorder(),
          ),
          onChanged: p.setTitle,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _servings,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'recipes.f_servings'.tr(),
            errorText: _error(errors, ['servings_invalid']),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => p.setBaseServings(int.tryParse(v) ?? 0),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'recipes.f_note'.tr(),
            errorText: _error(errors, ['note_too_long']),
            border: const OutlineInputBorder(),
          ),
          onChanged: p.setNote,
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({
    required this.url,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  final String url;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isUploading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (url.isEmpty) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 40),
              const SizedBox(height: 8),
              Text('recipes.pick_image'.tr()),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        RecipeImage(url: url, height: 180, width: double.infinity, borderRadius: 12),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton.filledTonal(
            tooltip: 'recipes.remove_image'.tr(),
            icon: const Icon(Icons.close),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
