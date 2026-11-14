import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../home/view/widgets/recipe_cover.dart';
import '../../domain/feed_arrange.dart';
import '../../models/community_post.dart';

/// Chip xếp (Mới nhất / Được thích nhiều) và chip lọc theo thẻ, cuộn ngang.
class FeedControls extends StatelessWidget {
  const FeedControls({
    super.key,
    required this.sort,
    required this.onSort,
    required this.tags,
    required this.selectedTag,
    required this.onTag,
  });

  final FeedSort sort;
  final ValueChanged<FeedSort> onSort;
  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final (s, icon) in [(FeedSort.newest, Icons.schedule), (FeedSort.popular, Icons.local_fire_department_outlined)])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('sort_${s.name}'),
                avatar: Icon(icon, size: 18),
                showCheckmark: false,
                label: Text('community.sort_${s.name}'.tr()),
                selected: sort == s,
                onSelected: (_) => onSort(s),
              ),
            ),
          if (tags.isNotEmpty) const SizedBox(height: 24, child: VerticalDivider(width: 16)),
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                key: Key('tag_$tag'),
                label: Text(tag),
                selected: selectedTag == tag,
                onSelected: (_) => onTag(tag),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dải bài "Nổi bật" do quản trị viên ghim, cuộn ngang.
class FeaturedStrip extends StatelessWidget {
  const FeaturedStrip({super.key, required this.posts, required this.onOpen});

  final List<CommunityPost> posts;
  final ValueChanged<CommunityPost> onOpen;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(children: [
            Icon(Icons.star, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('community.featured'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            key: const Key('featured_strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final post = posts[i];
              return SizedBox(
                width: 190,
                child: Card(
                  key: Key('featured_${post.id}'),
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(post),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: RecipeCover(title: post.title, imageUrl: '', iconSize: 36)),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Row(children: [
                            Expanded(
                              child: Text(post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
                            Text(' ${post.likeCount}', style: theme.textTheme.bodySmall),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
