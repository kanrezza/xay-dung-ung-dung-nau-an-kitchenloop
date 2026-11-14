import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../community/data/community_repository.dart';
import '../../community/domain/community_stats.dart';
import '../../community/models/community_post.dart';
import '../../community/view/post_detail_screen.dart';
import '../data/admin_repository.dart';
import '../domain/admin_stats.dart';
import '../models/admin_user.dart';
import 'widgets/announcement_editor.dart';

/// Mục Tổng quan của màn Quản trị (spec 007): số liệu chung, bài được thích nhiều, thông báo chung.
class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key, this.now, this.onOpenQueue});

  final DateTime Function()? now;

  /// Chuyển sang mục Cộng đồng (hàng chờ duyệt).
  final VoidCallback? onOpenQueue;

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  late final Stream<List<AdminUser>> _users = context.read<AdminRepository>().watchUsers();
  late final Stream<List<CommunityPost>> _posts = context.read<CommunityRepository>().watchAllPosts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = (widget.now ?? DateTime.now)();
    return StreamBuilder<List<AdminUser>>(
      stream: _users,
      builder: (context, users) => StreamBuilder<List<CommunityPost>>(
        stream: _posts,
        builder: (context, posts) {
          if (users.hasError || posts.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('admin.err_load'.tr())));
          }
          if (!users.hasData || !posts.hasData) return const Center(child: CircularProgressIndicator());
          final a = computeAdminStats(users.data!, now);
          final c = computeCommunityStats(posts.data!, now);
          final tiles = [
            ('o_users', a.total, Icons.people_alt_outlined, false),
            ('o_new', a.newLast7Days, Icons.person_add_alt, false),
            ('o_locked', a.locked, Icons.lock_outline, a.locked > 0),
            ('o_visible', c.visible, Icons.public, false),
            ('o_pending', c.hidden, Icons.pending_actions, c.hidden > 0),
            ('o_likes', c.totalLikes, Icons.favorite_border, false),
            ('o_featured', c.featured, Icons.star_outline, false),
            ('o_authors', c.authors, Icons.edit_note, false),
            ('o_reports', c.totalReports, Icons.flag_outlined, false),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.05,
                children: [
                  for (final (key, value, icon, warn) in tiles)
                    _Kpi(
                      key: Key(key),
                      icon: icon,
                      value: value,
                      label: 'admin.$key'.tr(),
                      warn: warn,
                      onTap: key == 'o_pending' ? widget.onOpenQueue : null,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('admin.o_top'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: c.topPosts.isEmpty
                    ? ListTile(leading: const Icon(Icons.favorite_border), title: Text('admin.o_top_empty'.tr()))
                    : Column(children: [
                        for (final (i, post) in c.topPosts.indexed)
                          ListTile(
                            key: Key('top_${post.id}'),
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('community.by'.tr(args: [post.authorName])),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.favorite, size: 16, color: Colors.red.shade400),
                              Text(' ${post.likeCount}'),
                            ]),
                            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post))),
                          ),
                      ]),
              ),
              const SizedBox(height: 20),
              const AnnouncementEditor(),
            ],
          );
        },
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({super.key, required this.icon, required this.value, required this.label, this.warn = false, this.onTap});

  final IconData icon;
  final int value;
  final String label;
  final bool warn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = warn ? scheme.errorContainer : scheme.surfaceContainerHigh;
    final fg = warn ? scheme.onErrorContainer : scheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 20, color: warn ? fg : scheme.primary),
              Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: fg, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}
