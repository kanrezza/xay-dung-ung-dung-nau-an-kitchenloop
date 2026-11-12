import 'package:flutter/material.dart';

import '../../models/recipe_step.dart';
import '../../providers/cooking_mode_provider.dart';
import '../display_helpers.dart';
import 'recipe_image.dart';
import 'step_timer_chip.dart';

/// Một trang của chế độ nấu: nội dung bước bằng chữ lớn, ảnh, hẹn giờ.
class CookingStepPage extends StatelessWidget {
  const CookingStepPage({super.key, required this.step, required this.provider});

  final RecipeStep step;
  final CookingModeProvider provider;

  /// Cỡ chữ tối thiểu 24 sp; hệ thống vẫn nhân thêm theo cỡ chữ người dùng chọn.
  static const double fontSize = 28;

  @override
  Widget build(BuildContext context) {
    final imageUrl = step.imageUrl;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty) ...[
            RecipeImage(url: imageUrl, width: double.infinity, height: 200, borderRadius: 12),
            const SizedBox(height: 16),
          ],
          Text(
            stepDisplayText(step),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: fontSize,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
          ),
          if (step.durationSec != null) ...[
            const SizedBox(height: 24),
            Center(
              child: StepTimerChip(
                state: provider.stateOf(step.id),
                remainingSec: provider.remainingSec(step.id),
                onStart: () => provider.startTimer(step.id),
                onPause: () => provider.pauseTimer(step.id),
                onReset: () => provider.resetTimer(step.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
