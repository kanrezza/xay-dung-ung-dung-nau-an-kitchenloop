import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/community_provider.dart';
import 'post_detail_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final theme = Theme.of(context);
    final posts = provider.posts;
    Widget body;
    if (provider.isLoading && posts.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (provider.error != null && posts.isEmpty) {
      body = _Message(icon: Icons.cloud_off, text: 'community.err_load'.tr());
    } else if (posts.isEmpty) {
      body = _Message(
        icon: provider.query.isEmpty ? Icons.diversity_3 : Icons.search_off,
        text: (provider.query.isEmpty ? 'community.empty' : 'community.empty_search').tr(),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => PostCard(
          key: Key('post_${posts[i].id}'),
          post: posts[i],
          isMine: posts[i].authorId == provider.currentUid,
          onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PostDetailScreen(post: posts[i]))),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('community.title'.tr())),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text('community.banner'.tr(), style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
          Expanded(child: body),
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
