import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/week.dart';

/// "9/11" — ngắn gọn, không phụ thuộc dữ liệu định dạng ngày của từng ngôn ngữ.
String shortDate(DateTime d) => '${d.day}/${d.month}';

/// Thanh chọn tuần: ‹ 9/11 – 15/11 › và nút "Tuần này".
class WeekHeader extends StatelessWidget {
  const WeekHeader({
    super.key,
    required this.weekStart,
    required this.isThisWeek,
    required this.onPrevious,
    required this.onNext,
    required this.onThisWeek,
  });

  final DateTime weekStart;
  final bool isThisWeek;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onThisWeek;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = 'planner.week_range'.tr(args: [shortDate(weekStart), shortDate(dayOfWeek(weekStart, 6))]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        children: [
          IconButton(key: const Key('week_prev'), icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
          Expanded(
            child: Text(
              range,
              key: const Key('week_range'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(key: const Key('week_next'), icon: const Icon(Icons.chevron_right), onPressed: onNext),
          AnimatedOpacity(
            opacity: isThisWeek ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: TextButton(
              key: const Key('week_today'),
              onPressed: isThisWeek ? null : onThisWeek,
              child: Text('planner.this_week'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
