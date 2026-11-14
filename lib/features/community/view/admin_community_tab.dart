import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/community_repository.dart';
import '../domain/community_stats.dart';
import '../models/community_post.dart';
import 'post_detail_screen.dart';
import 'widgets/post_card.dart';

/// Mục Cộng đồng trong màn Quản trị: số liệu, biểu đồ bài đăng 7 ngày, hàng chờ duyệt.
class AdminCommunityTab extends StatefulWidget {
  const AdminCommunityTab({super.key, this.now});

  final DateTime Function()? now;

  @override
  State<AdminCommunityTab> createState() => _AdminCommunityTabState();
}

class _AdminCommunityTabState extends State<AdminCommunityTab> {
  late final CommunityRepository _repository = context.read<CommunityRepository>();
  late final Stream<List<CommunityPost>> _posts = _repository.watchAllPosts();
  final Set<String> _busy = {};

  Future<void> _set(CommunityPost post, PostStatus status) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(post.id));
    try {
      await _repository.setStatus(post.id, status, resetReports: status == PostStatus.visible);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('admin.err_update'.tr())));
    } finally {
      if (mounted) setState(() => _busy.remove(post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<CommunityPost>>(
      stream: _posts,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('admin.err_load'.tr())));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snap.data!;
        final stats = computeCommunityStats(posts, (widget.now ?? DateTime.now)());
        final queue = posts.where((p) => p.status == PostStatus.hidden).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Stat(key: const Key('c_visible'), value: stats.visible, label: 'admin.c_visible'.tr()),
                _Stat(key: const Key('c_hidden'), value: stats.hidden, label: 'admin.c_hidden'.tr(), warn: stats.hidden > 0),
                _Stat(key: const Key('c_removed'), value: stats.removed, label: 'admin.c_removed'.tr()),
                _Stat(key: const Key('c_reports'), value: stats.totalReports, label: 'admin.c_reports'.tr()),
                _Stat(key: const Key('c_authors'), value: stats.authors, label: 'admin.c_authors'.tr()),
              ],
            ),
            const SizedBox(height: 16),
            Text('admin.c_week'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _WeekChart(perDay: stats.perDay, today: (widget.now ?? DateTime.now)()),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('admin.c_note'.tr(), style: theme.textTheme.bodySmall)),
              ],
            ),
            const SizedBox(height: 16),
            Text('admin.c_queue'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (queue.isEmpty)
              Card(child: ListTile(leading: const Icon(Icons.task_alt), title: Text('admin.c_queue_empty'.tr())))
            else
              for (final post in queue)
                _QueueItem(
                  key: Key('queue_${post.id}'),
                  post: post,
                  busy: _busy.contains(post.id),
                  reports: _repository.reportsOf(post.id),
                  onRestore: () => _set(post, PostStatus.visible),
                  onRemove: () => _set(post, PostStatus.removed),
                ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.value, required this.label, this.warn = false});

  final int value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = warn ? scheme.errorContainer : scheme.primaryContainer;
    final fg = warn ? scheme.onErrorContainer : scheme.onPrimaryContainer;
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: fg)),
        ],
      ),
    );
  }
}

/// Biểu đồ cột đơn giản: số bài mỗi ngày trong 7 ngày (cột cuối là hôm nay).
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.perDay, required this.today});

  final List<int> perDay;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = perDay.fold<int>(1, (m, v) => v > m ? v : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: SizedBox(
          height: 130,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${perDay[i]}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        height: 80 * perDay[i] / max + 2,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: i == 6 ? scheme.primary : scheme.primary.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        postDate(DateTime(today.year, today.month, today.day - (6 - i))),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueItem extends StatelessWidget {
  const _QueueItem({
    super.key,
    required this.post,
    required this.busy,
    required this.reports,
    required this.onRestore,
    required this.onRemove,
  });

  final CommunityPost post;
  final bool busy;
  final Future<List<PostReport>> reports;
  final VoidCallback onRestore;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post))),
              child: Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text('${'community.by'.tr(args: [post.authorName])} · ${'community.reports_n'.plural(post.reportCount)}', style: theme.textTheme.bodySmall),
            FutureBuilder<List<PostReport>>(
              future: reports,
              builder: (context, snap) {
                final reasons = {for (final r in snap.data ?? const <PostReport>[]) 'community.reason_${reportReasonIds[r.reason]}'.tr()};
                if (reasons.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('admin.c_reasons'.tr(args: [reasons.join(', ')]), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (busy) const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                OutlinedButton.icon(key: Key('remove_${post.id}'), onPressed: busy ? null : onRemove, icon: const Icon(Icons.delete_outline), label: Text('admin.c_remove'.tr())),
                const SizedBox(width: 8),
                FilledButton.icon(key: Key('restore_${post.id}'), onPressed: busy ? null : onRestore, icon: const Icon(Icons.restore), label: Text('admin.c_restore'.tr())),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
