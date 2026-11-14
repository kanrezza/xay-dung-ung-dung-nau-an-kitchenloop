import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/announcement_provider.dart';

/// Thông báo chung của quản trị viên (Trang chủ, Cộng đồng). Ẩn được trên máy này.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key, this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0)});

  final EdgeInsets padding;

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AnnouncementProvider>().ensureListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AnnouncementProvider>();
    final text = provider.visibleText;
    if (text.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.padding,
      child: Material(
        key: const Key('announcement'),
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: scheme.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('community.announcement'.tr(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onTertiaryContainer)),
                    Text(text, style: TextStyle(color: scheme.onTertiaryContainer)),
                  ],
                ),
              ),
              IconButton(
                key: const Key('announcement_close'),
                tooltip: 'community.announcement_hide'.tr(),
                icon: Icon(Icons.close, color: scheme.onTertiaryContainer),
                onPressed: provider.dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
