import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../recipes/models/recipe.dart';
import '../data/community_repository.dart';
import '../providers/community_provider.dart';

/// Chia sẻ một công thức lên cộng đồng: xác nhận (nói rõ những gì sẽ công khai), kiểm duyệt
/// trước ở ứng dụng, gửi lên (rules kiểm duyệt lần nữa), rồi báo kết quả.
Future<void> shareRecipe(BuildContext context, Recipe recipe) async {
  final provider = context.read<CommunityProvider>();
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.public),
      title: Text('community.share_title'.tr()),
      content: Text('community.share_body'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
        FilledButton(key: const Key('share_confirm'), onPressed: () => Navigator.pop(d, true), child: Text('community.share_confirm'.tr())),
      ],
    ),
  );
  if (confirmed != true) return;

  final outcome = await provider.share(recipe);
  if (!context.mounted) return;
  if (outcome.issues.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        key: const Key('share_issues'),
        icon: Icon(Icons.rule, color: Theme.of(d).colorScheme.error),
        title: Text('community.not_ok'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final issue in outcome.issues)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text('community.issue_${issue.name}'.tr())),
                  ],
                ),
              ),
          ],
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(d), child: Text('common.close'.tr()))],
      ),
    );
    return;
  }
  final String message;
  if (outcome.ok) {
    message = (outcome.kind == ShareKind.created ? 'community.shared' : 'community.updated').tr();
  } else if (outcome.wait != null) {
    message = 'community.too_soon'.tr(args: ['${outcome.wait!.inSeconds.clamp(1, 999)}']);
  } else if (outcome.rejected) {
    message = 'community.rejected'.tr();
  } else {
    message = 'community.offline'.tr();
  }
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
