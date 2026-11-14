import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../home/view/widgets/recipe_cover.dart';
import '../../../recipes/view/display_helpers.dart';
import '../../models/community_post.dart';

/// "14/11" — ngày đăng ngắn gọn.
String postDate(DateTime? d) => d == null ? '' : '${d.day}/${d.month}';

/// Tổng thời gian nấu của bài (dùng chung định dạng với công thức).
String formatPostCookTime(int seconds) => formatCookTime(seconds);

/// Một bài trong danh sách cộng đồng: ảnh minh hoạ, tên món, người đăng, thời gian nấu.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, required this.isMine, required this.onTap});

  final CommunityPost post;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final secs = post.steps.fold<int>(0, (sum, s) => sum + (s.durationSec ?? 0));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Chiều cao cố định: Row kéo giãn theo chiều dọc cần giới hạn (thẻ nằm trong danh sách cuộn).
        child: SizedBox(
          height: 112,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 112, child: RecipeCover(title: post.title, imageUrl: '', iconSize: 36)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              isMine ? 'community.yours'.tr() : 'community.by'.tr(args: [post.authorName]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: isMine ? scheme.primary : scheme.onSurfaceVariant),
                            ),
                          ),
                          if (post.createdAt != null) Text(' · ${postDate(post.createdAt)}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (secs > 0) formatCookTime(secs),
                          'recipes.info_servings'.plural(post.baseServings),
                          'recipes.n_ingredients'.plural(post.ingredients.length),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
