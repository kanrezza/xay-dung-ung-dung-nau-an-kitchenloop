import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../providers/cooking_mode_provider.dart';
import '../display_helpers.dart';

/// Hẹn giờ của một bước: Bắt đầu / Tạm dừng / Tiếp tục / Đặt lại, đếm ngược và
/// trạng thái "hết giờ".
class StepTimerChip extends StatelessWidget {
  const StepTimerChip({
    super.key,
    required this.state,
    required this.remainingSec,
    required this.onStart,
    required this.onPause,
    required this.onReset,
  });

  final TimerState state;
  final int remainingSec;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final finished = state == TimerState.finished;
    return Card(
      key: const Key('step_timer_chip'),
      color: finished ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(finished ? Icons.alarm_on : Icons.timer_outlined, size: 32),
                const SizedBox(width: 12),
                Text(
                  finished ? 'recipes.timer_done'.tr() : formatDuration(remainingSec),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: finished ? scheme.onErrorContainer : null,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: _buttons(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buttons() {
    final reset = TextButton(onPressed: onReset, child: Text('recipes.timer_reset'.tr()));
    switch (state) {
      case TimerState.idle:
        return [
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text('recipes.timer_start'.tr()),
          ),
        ];
      case TimerState.running:
        return [
          FilledButton.tonalIcon(
            onPressed: onPause,
            icon: const Icon(Icons.pause),
            label: Text('recipes.timer_pause'.tr()),
          ),
          reset,
        ];
      case TimerState.paused:
        return [
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text('recipes.timer_resume'.tr()),
          ),
          reset,
        ];
      case TimerState.finished:
        return [reset];
    }
  }
}
