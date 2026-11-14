import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/community_provider.dart';

/// Công cụ của quản trị viên trên một bài (spec 007): ghim nổi bật, ẩn, gỡ.
/// Chỉ hiện với quản trị viên; quyền thật do Firestore rules kiểm tra.
class AdminPostTools extends StatefulWidget {
  const AdminPostTools({super.key, required this.post});

  final CommunityPost post;

  @override
  State<AdminPostTools> createState() => _AdminPostToolsState();
}

class _AdminPostToolsState extends State<AdminPostTools> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function(CommunityProvider p) action, String doneKey, {bool leave = false}) async {
    final provider = context.read<CommunityProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    final ok = await action(provider);
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text((ok ? doneKey : 'admin.err_update').tr())));
    if (ok && leave) navigator.pop();
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('community.admin_remove_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(
            key: const Key('admin_remove_confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: Text('admin.c_remove'.tr()),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run((p) => p.setStatus(widget.post, PostStatus.removed), 'community.admin_removed', leave: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('admin_post_tools'),
      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.admin_panel_settings_outlined, size: 18, color: scheme.onTertiaryContainer),
              const SizedBox(width: 6),
              Expanded(child: Text('community.admin_tools'.tr(), style: const TextStyle(fontWeight: FontWeight.w700))),
              if (_busy) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            const SizedBox(height: 4),
            Text('community.reports_n'.plural(post.reportCount), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (post.status == PostStatus.visible)
                  FilledButton.tonalIcon(
                    key: const Key('admin_feature'),
                    onPressed: _busy
                        ? null
                        : () => _run((p) => p.setFeatured(post, !post.featured),
                            post.featured ? 'community.unfeatured_done' : 'community.featured_done'),
                    icon: Icon(post.featured ? Icons.star_outline : Icons.star),
                    label: Text((post.featured ? 'community.unfeature' : 'community.feature').tr()),
                  ),
                if (post.status == PostStatus.visible)
                  OutlinedButton.icon(
                    key: const Key('admin_hide'),
                    onPressed:
                        _busy ? null : () => _run((p) => p.setStatus(post, PostStatus.hidden), 'community.admin_hidden', leave: true),
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: Text('community.admin_hide'.tr()),
                  )
                else
                  OutlinedButton.icon(
                    key: const Key('admin_restore'),
                    onPressed:
                        _busy ? null : () => _run((p) => p.setStatus(post, PostStatus.visible), 'community.admin_restored', leave: true),
                    icon: const Icon(Icons.restore),
                    label: Text('admin.c_restore'.tr()),
                  ),
                OutlinedButton.icon(
                  key: const Key('admin_remove'),
                  onPressed: _busy ? null : _remove,
                  style: OutlinedButton.styleFrom(foregroundColor: scheme.error),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('admin.c_remove'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
