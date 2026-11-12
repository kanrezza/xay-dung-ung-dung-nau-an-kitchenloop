import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/text_normalizer.dart';
import '../../providers/recipe_editor_provider.dart';

/// Nhập thẻ cho công thức: gõ rồi bấm Enter (hoặc dấu phẩy) để thêm, bấm dấu ×
/// để xoá, kèm gợi ý từ các thẻ đã dùng ở công thức khác.
class TagsField extends StatefulWidget {
  const TagsField({super.key, this.suggestions = const []});

  /// Các thẻ người dùng đã dùng ở công thức khác.
  final List<String> suggestions;

  @override
  State<TagsField> createState() => _TagsFieldState();
}

class _TagsFieldState extends State<TagsField> {
  final _controller = TextEditingController();
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final provider = context.read<RecipeEditorProvider>();
    final result = provider.addTag(raw);
    setState(() {
      switch (result) {
        case TagAddResult.added:
        case TagAddResult.empty:
          _message = null;
        case TagAddResult.duplicate:
          _message = 'recipes.tag_duplicate'.tr();
        case TagAddResult.tooLong:
          _message = 'recipes.err_tag_invalid'.tr();
        case TagAddResult.tooMany:
          _message = 'recipes.err_tags_too_many'.tr();
      }
    });
    if (result == TagAddResult.added || result == TagAddResult.empty || result == TagAddResult.duplicate) {
      _controller.clear();
    }
  }

  /// Dấu phẩy kết thúc một thẻ, để dán hoặc gõ "nhanh, món sinh viên" một lần.
  void _onChanged(String text) {
    if (!text.contains(',')) return;
    final parts = text.split(',');
    for (var i = 0; i < parts.length - 1; i++) {
      _add(parts[i]);
    }
    final rest = parts.last;
    _controller.value = TextEditingValue(text: rest, selection: TextSelection.collapsed(offset: rest.length));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecipeEditorProvider>();
    final scheme = Theme.of(context).colorScheme;
    final used = p.draft.tags.map(normalizeForSearch).toSet();
    final suggestions = widget.suggestions.where((s) => !used.contains(normalizeForSearch(s))).take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.draft.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var i = 0; i < p.draft.tags.length; i++)
                  InputChip(
                    key: Key('tag_${normalizeForSearch(p.draft.tags[i])}'),
                    label: Text(p.draft.tags[i]),
                    onDeleted: () => p.removeTag(i),
                  ),
              ],
            ),
          ),
        TextField(
          key: const Key('tag_input'),
          controller: _controller,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'recipes.f_tags'.tr(),
            hintText: 'recipes.tag_hint'.tr(),
            errorText: _message,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'recipes.f_tags'.tr(),
              icon: const Icon(Icons.add),
              onPressed: () => _add(_controller.text),
            ),
          ),
          onChanged: _onChanged,
          onSubmitted: _add,
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'recipes.tag_suggestions'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in suggestions)
                ActionChip(
                  key: Key('suggest_${normalizeForSearch(s)}'),
                  label: Text(s),
                  onPressed: () => _add(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
