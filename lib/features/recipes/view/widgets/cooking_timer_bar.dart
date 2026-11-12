import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../providers/cooking_mode_provider.dart';
import '../display_helpers.dart';

/// Phần đầu màn hình nấu: cảnh báo hết giờ, danh sách mọi hẹn giờ đang có
/// (bấm để nhảy tới bước đó) và lời nhắc khi chưa cho phép thông báo.
class CookingTimerBar extends StatelessWidget {
  const CookingTimerBar({super.key, required this.provider});

  final CookingModeProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = provider.recipe.steps;
    final alarms = provider.alarms;
    final timers = provider.activeTimers;

    int orderOf(String stepId) => steps.firstWhere((s) => s.id == stepId).order;

    return Column(
      children: [
        for (final stepId in alarms)
          Card(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            color: scheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.alarm_on, color: scheme.onErrorContainer),
              title: Text(
                'recipes.timer_alarm'.tr(args: ['${orderOf(stepId)}']),
                style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.bold),
              ),
              trailing: TextButton(
                key: Key('dismiss_alarm_$stepId'),
                onPressed: () => provider.acknowledgeAlarm(stepId),
                child: Text('common.close'.tr()),
              ),
            ),
          ),
        if (timers.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final t in timers)
                    ActionChip(
                      key: Key('running_timer_${t.stepId}'),
                      avatar: Icon(
                        provider.stateOf(t.stepId) == TimerState.paused ? Icons.pause : Icons.timer_outlined,
                        size: 18,
                      ),
                      label: Text(
                        '${'recipes.step_n'.tr(args: ['${orderOf(t.stepId)}'])} · '
                        '${provider.stateOf(t.stepId) == TimerState.finished ? 'recipes.timer_done'.tr() : formatDuration(provider.remainingSec(t.stepId))}',
                      ),
                      onPressed: () => provider.goTo(steps.indexWhere((s) => s.id == t.stepId)),
                    ),
                ],
              ),
            ),
          ),
        if (provider.notificationsDenied)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'recipes.notif_denied'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
