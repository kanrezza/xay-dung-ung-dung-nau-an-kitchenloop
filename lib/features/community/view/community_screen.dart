import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/community_provider.dart';
import '../models/community_post.dart';
import 'post_detail_screen.dart';
import 'widgets/announcement_banner.dart';
import 'widgets/feed_controls.dart';
import 'widgets/post_card.dart';

/// Tab Cộng đồng: công thức người khác chia sẻ (đã qua kiểm duyệt tự động), tìm kiếm.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    // Chỉ tải khi tab được dựng lần đầu.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityProvider>().ensureListening();
    });
  }

  void _open(CommunityPost post) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: post)));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final theme = Theme.of(context);
    final posts = provider.posts;
    final filtering = provider.query.isNotEmpty || provider.tag != null;
    final List<Widget> items;
    if (provider.isLoading && provider.allPosts.isEmpty) {
      items = [const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))];
    } else if (provider.error != null && provider.allPosts.isEmpty) {
      items = [_Message(icon: Icons.cloud_off, text: 'community.err_load'.tr())];
    } else if (posts.isEmpty) {
      items = [
        _Message(
          icon: filtering ? Icons.search_off : Icons.diversity_3,
          text: (filtering ? 'community.empty_search' : 'community.empty').tr(),
        ),
      ];
    } else {
      items = [
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: PostCard(
              key: Key('post_${post.id}'),
              post: post,
              isMine: post.authorId == provider.currentUid,
              onTap: () => _open(post),
            ),
          ),
      ];
    }
    return Scaffold(
      appBar: AppBar(title: Text('community.title'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              key: const Key('community_search'),
              onChanged: provider.setQuery,
              decoration: InputDecoration(
                hintText: 'community.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const AnnouncementBanner(padding: EdgeInsets.fromLTRB(16, 4, 16, 4)),
                if (!filtering) FeaturedStrip(posts: provider.featured, onOpen: _open),
                const SizedBox(height: 4),
                FeedControls(
                  sort: provider.sort,
                  onSort: provider.setSort,
                  tags: provider.tags,
                  selectedTag: provider.tag,
                  onTag: provider.toggleTag,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('community.banner'.tr(), style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
                ...items,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
