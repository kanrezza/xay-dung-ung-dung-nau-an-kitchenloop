import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/recipe_editor_provider.dart';
import '../display_helpers.dart';
import 'image_picking.dart';
import 'step_editor.dart';

/// Danh sách bước nấu kéo để đổi thứ tự, có nút thêm.
class StepsSection extends StatelessWidget {
  const StepsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<RecipeEditorProvider>();
    final steps = p.draft.steps;
    final scheme = Theme.of(context).colorScheme;
    final sectionErrors = [
      for (final code in const ['steps_required', 'steps_too_many', 'steps_order_invalid'])
        if (p.errors.contains(code)) recipeErrorMessage(code),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('recipes.steps'.tr(), style: Theme.of(context).textTheme.titleMedium),
        for (final message in sectionErrors)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: steps.length,
          onReorder: p.moveStep,
          itemBuilder: (context, index) {
            final step = steps[index];
            return StepEditor(
              key: ValueKey(step.id),
              step: step,
              errors: p.stepErrors(index),
              isUploading: p.isUploading,
              onChanged: (value) => p.updateStep(index, value),
              onFieldInvalid: (field, invalid) => p.setFieldInvalid(step.id, field, invalid),
              onRemove: () => p.removeStep(index),
              onRemoveImage: () => p.setStepImage(index, null),
              onPickImage: () async {
                final url = await pickAndUploadImage(context);
                if (url == null) return;
                // Chỉ số có thể đã đổi trong lúc tải ảnh: tìm lại theo id.
                final current = p.draft.steps.indexWhere((s) => s.id == step.id);
                if (current >= 0) p.setStepImage(current, url);
              },
              dragHandle: ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: p.addStep,
            icon: const Icon(Icons.add),
            label: Text('recipes.add_step'.tr()),
          ),
        ),
      ],
    );
  }
}
