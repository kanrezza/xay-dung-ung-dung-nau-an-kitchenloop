import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/recipe_step.dart';
import '../display_helpers.dart';
import 'recipe_image.dart';

/// Một bước nấu {nội dung, ảnh, thời gian tuỳ chọn phút/giây}.
/// Thời gian ≤ 0 bị từ chối (lỗi `duration_invalid`).
class StepEditor extends StatefulWidget {
  const StepEditor({
    super.key,
    required this.step,
    required this.errors,
    required this.onChanged,
    required this.onFieldInvalid,
    required this.onRemove,
    required this.onPickImage,
    required this.onRemoveImage,
    this.isUploading = false,
    this.dragHandle,
  });

  final RecipeStep step;

  /// Mã lỗi của bước này (ví dụ `text_invalid`, `duration_invalid`).
  final List<String> errors;
  final ValueChanged<RecipeStep> onChanged;
  final void Function(String field, bool invalid) onFieldInvalid;
  final VoidCallback onRemove;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final bool isUploading;
  final Widget? dragHandle;

  @override
  State<StepEditor> createState() => _StepEditorState();
}

class _StepEditorState extends State<StepEditor> {
  late final TextEditingController _text;
  late final TextEditingController _minutes;
  late final TextEditingController _seconds;
  bool _durationInvalid = false;

  @override
  void initState() {
    super.initState();
    final s = widget.step;
    // Bước giữ chỗ: để trống ô nội dung và hiện gợi ý đã dịch.
    _text = TextEditingController(text: s.isPlaceholder ? '' : s.text);
    final d = s.durationSec;
    _minutes = TextEditingController(text: d == null ? '' : '${d ~/ 60}');
    _seconds = TextEditingController(text: d == null ? '' : '${d % 60}');
  }

  @override
  void dispose() {
    _text.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  int? _parseInt(String s) => s.trim().isEmpty ? 0 : int.tryParse(s.trim());

  void _emit() {
    final prev = widget.step;
    final m = _parseInt(_minutes.text);
    final s = _parseInt(_seconds.text);
    final blank = _minutes.text.trim().isEmpty && _seconds.text.trim().isEmpty;
    final invalid = !blank && (m == null || s == null || m < 0 || s < 0);
    if (invalid != _durationInvalid) {
      _durationInvalid = invalid;
      widget.onFieldInvalid('duration', invalid);
    }
    final int? duration = blank ? null : (invalid ? prev.durationSec : m! * 60 + s!);
    final keepPlaceholder = prev.isPlaceholder && _text.text.isEmpty;
    widget.onChanged(prev.copyWith(
      text: keepPlaceholder ? prev.text : _text.text,
      isPlaceholder: keepPlaceholder,
      durationSec: duration,
    ));
    setState(() {});
  }

  String? _error(List<String> codes) {
    for (final code in codes) {
      if (widget.errors.contains(code)) return recipeErrorMessage(code);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final durationError = _durationInvalid
        ? recipeErrorMessage('duration_invalid')
        : _error(['duration_invalid']);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.dragHandle != null) ...[widget.dragHandle!, const SizedBox(width: 8)],
                Expanded(
                  child: Text(
                    'recipes.step_n'.tr(args: ['${step.order}']),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'common.delete'.tr(),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextField(
                controller: _text,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'recipes.f_step_text'.tr(),
                  hintText: step.isPlaceholder && _text.text.isEmpty ? 'recipes.placeholder_step'.tr() : null,
                  errorText: _error(['text_invalid']),
                ),
                onChanged: (_) => _emit(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                      decoration: InputDecoration(
                        labelText: 'recipes.f_minutes'.tr(),
                        errorText: durationError,
                        errorMaxLines: 3,
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _seconds,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                      decoration: InputDecoration(labelText: 'recipes.f_seconds'.tr()),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ImageSlot(
              url: step.imageUrl,
              isUploading: widget.isUploading,
              onPick: widget.onPickImage,
              onRemove: widget.onRemoveImage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({
    required this.url,
    required this.isUploading,
    required this.onPick,
    required this.onRemove,
  });

  final String? url;
  final bool isUploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text('recipes.pick_image'.tr()),
        ),
      );
    }
    return Row(
      children: [
        RecipeImage(url: imageUrl, width: 72, height: 72, borderRadius: 8),
        const SizedBox(width: 8),
        TextButton(onPressed: onRemove, child: Text('recipes.remove_image'.tr())),
      ],
    );
  }
}
