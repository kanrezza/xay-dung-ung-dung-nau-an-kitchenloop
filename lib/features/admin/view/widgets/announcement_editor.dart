import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../community/providers/announcement_provider.dart';

/// Ô soạn thông báo chung cho mọi người dùng (spec 007, US3).
class AnnouncementEditor extends StatefulWidget {
  const AnnouncementEditor({super.key});

  @override
  State<AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<AnnouncementEditor> {
  final _controller = TextEditingController();
  bool _edited = false;
  bool _busy = false;
  String _lastSeen = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AnnouncementProvider>().ensureListening();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AnnouncementProvider>();
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    String key;
    try {
      final issues = await provider.save(text);
      if (issues.isNotEmpty) {
        key = 'admin.ann_rejected';
      } else {
        key = text.trim().isEmpty ? 'admin.ann_cleared' : 'admin.ann_saved';
        _edited = false;
        if (text.trim().isEmpty) _controller.clear();
      }
    } catch (_) {
      key = 'admin.ann_failed';
    }
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(key.tr())));
  }

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AnnouncementProvider>().text;
    // Nạp nội dung đang có vào ô soạn khi người quản trị chưa gõ gì.
    if (current != _lastSeen) {
      _lastSeen = current;
      if (!_edited) _controller.text = current;
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.campaign_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('admin.ann_title'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text('admin.ann_desc'.tr(), style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            TextField(
              key: const Key('announcement_field'),
              controller: _controller,
              maxLength: announcementMax,
              maxLines: 3,
              minLines: 2,
              onChanged: (_) => _edited = true,
              decoration: InputDecoration(hintText: 'admin.ann_hint'.tr(), border: const OutlineInputBorder()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (current.isNotEmpty)
                  TextButton.icon(
                    key: const Key('announcement_clear'),
                    onPressed: _busy ? null : () => _save(''),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('admin.ann_clear'.tr()),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const Key('announcement_save'),
                  onPressed: _busy ? null : () => _save(_controller.text),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: Text('admin.ann_save'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
