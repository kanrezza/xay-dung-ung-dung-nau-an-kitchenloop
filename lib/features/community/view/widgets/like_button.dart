import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_post.dart';
import '../../providers/community_provider.dart';

/// Nút ♥ kèm số lượt thích. Bài của chính mình chỉ hiện số, không bấm được (rules cũng chặn).
class LikeButton extends StatelessWidget {
  const LikeButton({super.key, required this.post, this.compact = false});

  final CommunityPost post;

  /// Dạng nhỏ (trên thẻ bài): biểu tượng trên, số dưới.
  final bool compact;

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<CommunityProvider>().toggleLike(post);
    if (!ok) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('community.like_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final mine = post.authorId == provider.currentUid;
    final liked = post.isLikedBy(provider.currentUid);
    final color = liked ? Colors.red.shade400 : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = Icon(liked ? Icons.favorite : Icons.favorite_border, color: color, size: compact ? 22 : 24);
    final onTap = mine ? null : () => _toggle(context);
    final tooltip = (liked ? 'community.unlike' : 'community.like').tr();
    if (compact) {
      return InkWell(
        key: Key('like_${post.id}'),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              icon,
              Text('${post.likeCount}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      key: Key('like_${post.id}'),
      onPressed: onTap,
      icon: icon,
      label: Text('community.likes_n'.plural(post.likeCount)),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
    );
  }
}

/// Nhãn nhỏ: "Nổi bật", "Quản trị viên".
class PostBadge extends StatelessWidget {
  const PostBadge({super.key, required this.icon, required this.label, this.admin = false});

  final IconData icon;
  final String label;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = admin ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = admin ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// Các nhãn của một bài.
List<Widget> postBadges(CommunityPost post) => [
      if (post.featured) PostBadge(icon: Icons.star, label: 'community.featured_badge'.tr()),
      if (post.byAdmin) PostBadge(icon: Icons.verified, label: 'community.admin_badge'.tr(), admin: true),
    ];
