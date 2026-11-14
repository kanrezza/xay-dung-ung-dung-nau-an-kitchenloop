import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/view/widgets/recipe_cover.dart';
import '../../recipes/view/widgets/detail_header.dart';
import '../../recipes/view/widgets/recipe_sections.dart';
import '../models/community_post.dart';
import '../providers/community_provider.dart';
import '../../admin/providers/admin_status_provider.dart';
import 'widgets/admin_post_tools.dart';
import 'widgets/like_button.dart';
import 'widgets/post_card.dart';

/// Xem một bài cộng đồng: nguyên liệu, các bước; lưu vào sổ, báo cáo (bài người khác), gỡ (bài mình).
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final CommunityPost post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  bool _busy = false;

  void _say(String key) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));

  Future<void> _save() async {
    setState(() => _busy = true);
    final id = await context.read<CommunityProvider>().saveToMine(widget.post);
    if (!mounted) return;
    setState(() => _busy = false);
    _say(id == null ? 'community.save_failed' : 'community.saved');
  }

  Future<void> _report() async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('community.report_title'.tr(), style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final r in ReportReason.values)
              ListTile(
                key: Key('reason_${reportReasonIds[r]}'),
                leading: const Icon(Icons.flag_outlined),
                title: Text('community.reason_${reportReasonIds[r]}'.tr()),
                onTap: () => Navigator.pop(sheetContext, r),
              ),
          ],
        ),
      ),
    );
    if (reason == null || !mounted) return;
    final ok = await context.read<CommunityProvider>().report(widget.post.id, reason);
    if (!mounted) return;
    _say(ok ? 'community.reported' : 'community.report_failed');
    if (ok) Navigator.pop(context);
  }

  Future<void> _unshare() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('community.unshare_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text('community.unshare'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<CommunityProvider>().unshare(widget.post.id);
    if (!mounted) return;
    _say(ok ? 'community.removed' : 'community.offline');
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    // Bản mới nhất từ danh sách (sau khi thích/ghim); bài ẩn không có trong danh sách thì dùng bản được truyền vào.
    final post = provider.postById(widget.post.id) ?? widget.post;
    final isAdmin = context.watch<AdminStatusProvider>().isAdmin;
    final badges = postBadges(post);
    final mine = post.authorId == provider.currentUid;
    final textTheme = Theme.of(context).textTheme;
    final recipe = post.toRecipe();
    final secs = post.steps.fold<int>(0, (sum, s) => sum + (s.durationSec ?? 0));
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            leading: const Padding(padding: EdgeInsets.all(6), child: CircleBack()),
            flexibleSpace: FlexibleSpaceBar(background: RecipeCover(title: post.title, imageUrl: '', iconSize: 64)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList.list(
              children: [
                if (badges.isNotEmpty) ...[Wrap(spacing: 6, children: badges), const SizedBox(height: 6)],
                Text(post.title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  [mine ? 'community.yours'.tr() : 'community.by'.tr(args: [post.authorName]), postDate(post.createdAt)]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (secs > 0) InfoChip(icon: Icons.schedule, text: formatPostCookTime(secs)),
                    InfoChip(icon: Icons.people_outline, text: 'recipes.info_servings'.plural(post.baseServings)),
                    for (final tag in post.tags) InfoChip(icon: Icons.sell_outlined, text: tag),
                  ],
                ),
                if (post.note.isNotEmpty) ...[const SizedBox(height: 12), Text(post.note, style: textTheme.bodyLarge)],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!mine) ...[
                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('save_post'),
                          onPressed: _busy ? null : _save,
                          icon: const Icon(Icons.bookmark_add_outlined),
                          label: Text('community.save'.tr()),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    LikeButton(post: post),
                  ],
                ),
                if (isAdmin) ...[const SizedBox(height: 12), AdminPostTools(post: post)],
                const SizedBox(height: 24),
                Text('recipes.ingredients'.tr(), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                IngredientsList(recipe: recipe, languageCode: context.locale.languageCode, servings: post.baseServings),
                const SizedBox(height: 24),
                Text('recipes.steps'.tr(), style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                StepsList(recipe: recipe),
                const SizedBox(height: 16),
                Align(
                  child: mine
                      ? TextButton.icon(
                          key: const Key('unshare_post'),
                          onPressed: _unshare,
                          icon: const Icon(Icons.delete_outline),
                          label: Text('community.unshare'.tr()),
                        )
                      : TextButton.icon(
                          key: const Key('report_post'),
                          onPressed: _report,
                          icon: const Icon(Icons.flag_outlined),
                          label: Text('community.report'.tr()),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
