import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/admin_stats.dart';
import '../../models/admin_user.dart';

/// Ba ô số liệu: tổng tài khoản, đang khoá, mới trong 7 ngày.
class AdminStatsRow extends StatelessWidget {
  const AdminStatsRow({super.key, required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(key: const Key('stat_total'), value: stats.total, label: 'admin.total'.tr())),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            key: const Key('stat_locked'),
            value: stats.locked,
            label: 'admin.locked'.tr(),
            warn: stats.locked > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _StatCard(key: const Key('stat_new'), value: stats.newLast7Days, label: 'admin.new_7d'.tr())),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.value, required this.label, this.warn = false});

  final int value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: warn ? scheme.errorContainer : scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: warn ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: warn ? scheme.onErrorContainer : scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "14/11/2026": không phụ thuộc dữ liệu định dạng ngày của từng ngôn ngữ.
String formatAdminDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Một dòng tài khoản: tên, email, ngày tham gia, trạng thái và nút khoá/mở khoá.
class AdminUserTile extends StatelessWidget {
  const AdminUserTile({
    super.key,
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onToggleLock,
  });

  final AdminUser user;

  /// Dòng của chính quản trị viên: không có nút khoá.
  final bool isSelf;
  final bool busy;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user.name.isNotEmpty ? user.name : 'admin.no_name'.tr();
    final initial = (user.name.isNotEmpty ? user.name : user.email).trim();
    final details = [
      if (user.email.isNotEmpty) user.email,
      if (user.createdAt != null) 'admin.joined'.tr(args: [formatAdminDate(user.createdAt!)]),
    ].join(' · ');

    Widget trailing;
    if (isSelf) {
      trailing = Chip(label: Text('admin.you'.tr()), visualDensity: VisualDensity.compact);
    } else if (busy) {
      trailing = const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (user.isLocked) {
      trailing = FilledButton.tonalIcon(
        key: Key('unlock_${user.id}'),
        onPressed: onToggleLock,
        icon: const Icon(Icons.lock_open, size: 18),
        label: Text('admin.unlock'.tr()),
      );
    } else {
      trailing = OutlinedButton.icon(
        key: Key('lock_${user.id}'),
        onPressed: onToggleLock,
        icon: const Icon(Icons.lock_outline, size: 18),
        label: Text('admin.lock'.tr()),
      );
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: user.isLocked ? scheme.errorContainer : scheme.secondaryContainer,
        foregroundColor: user.isLocked ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        child: user.isLocked
            ? const Icon(Icons.lock, size: 20)
            : Text(initial.isEmpty ? '?' : initial.characters.first.toUpperCase()),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty) Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (user.isLocked)
            Text(
              'admin.status_locked'.tr(),
              style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600),
            ),
        ],
      ),
      isThreeLine: user.isLocked,
      trailing: trailing,
    );
  }
}
