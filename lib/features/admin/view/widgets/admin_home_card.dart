import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../community/data/community_repository.dart';
import '../../../community/models/community_post.dart';
import '../../providers/admin_status_provider.dart';
import '../admin_screen.dart';

/// Thẻ "Bảng quản trị" ở Trang chủ, chỉ hiện với quản trị viên (spec 007, US4).
class AdminHomeCard extends StatefulWidget {
  const AdminHomeCard({super.key});

  @override
  State<AdminHomeCard> createState() => _AdminHomeCardState();
}

class _AdminHomeCardState extends State<AdminHomeCard> {
  Stream<List<CommunityPost>>? _posts;

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AdminStatusProvider>().isAdmin) return const SizedBox.shrink();
    // Chỉ nghe toàn bộ bài khi đúng là quản trị viên (người thường bị rules từ chối).
    _posts ??= context.read<CommunityRepository>().watchAllPosts();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: StreamBuilder<List<CommunityPost>>(
        stream: _posts,
        builder: (context, snap) {
          final posts = snap.data ?? const <CommunityPost>[];
          final pending = posts.where((p) => p.status == PostStatus.hidden).length;
          final visible = posts.where((p) => p.status == PostStatus.visible).length;
          return Material(
            key: const Key('admin_home_card'),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [scheme.tertiary, scheme.primary]),
              ),
              child: InkWell(
                onTap: () => Navigator.push(context, AdminScreen.route()),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.onPrimary.withValues(alpha: 0.2),
                        child: Icon(Icons.admin_panel_settings, color: scheme.onPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('admin.home_title'.tr(),
                                style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(
                              snap.hasData
                                  ? '${'admin.home_pending'.plural(pending)} · ${'admin.home_visible'.plural(visible)}'
                                  : 'admin.home_desc'.tr(),
                              style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
                            ),
                          ],
                        ),
                      ),
                      if (pending > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(12)),
                          child: Text('$pending', style: TextStyle(color: scheme.onError, fontWeight: FontWeight.w800)),
                        ),
                      Icon(Icons.chevron_right, color: scheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
