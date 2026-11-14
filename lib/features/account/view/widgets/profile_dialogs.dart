import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';

/// Thông báo mới thay ngay thông báo cũ (không xếp hàng chờ).
void _say(BuildContext context, String key, [List<String>? args]) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(key.tr(args: args))));

/// Bảng chọn ảnh đại diện: thư viện, máy ảnh, xoá ảnh.
Future<void> showAvatarSheet(BuildContext context) async {
  final provider = context.read<ProfileProvider>();
  final hasPhoto = provider.profile?.hasAvatar ?? false;
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('account.change_photo'.tr(), style: Theme.of(sheet).textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            key: const Key('avatar_gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: Text('account.photo_gallery'.tr()),
            onTap: () => Navigator.pop(sheet, 'gallery'),
          ),
          ListTile(
            key: const Key('avatar_camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text('account.photo_camera'.tr()),
            onTap: () => Navigator.pop(sheet, 'camera'),
          ),
          if (hasPhoto)
            ListTile(
              key: const Key('avatar_remove'),
              leading: Icon(Icons.delete_outline, color: Theme.of(sheet).colorScheme.error),
              title: Text('account.photo_remove'.tr(), style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
              onTap: () => Navigator.pop(sheet, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'remove') {
    final ok = await provider.removeAvatar();
    if (context.mounted) _say(context, ok ? 'account.photo_removed' : 'account.photo_failed');
    return;
  }
  final picked = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    // Ảnh lưu thẳng trong hồ sơ nên phải nhỏ: 256 px, chất lượng 75 (~10–30 KB).
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 75,
  );
  if (picked == null || !context.mounted) return;
  final ok = await provider.setAvatar(File(picked.path));
  if (context.mounted) _say(context, ok ? 'account.photo_saved' : 'account.photo_failed');
}

/// Hộp thoại đổi tên hiển thị.
Future<void> showRenameDialog(BuildContext context) async {
  final provider = context.read<ProfileProvider>();
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: provider.profile?.name ?? ''),
  );
  if (name == null || !context.mounted) return;
  final error = await provider.rename(name);
  if (!context.mounted) return;
  _say(context, switch (error) {
    null => 'account.name_saved',
    NameError.empty => 'account.err_name_empty',
    NameError.tooLong => 'account.err_name_long',
    NameError.notAllowed => 'account.err_name_bad',
    NameError.failed => 'account.err_name_failed',
  });
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('account.edit_name'.tr()),
      content: TextField(
        key: const Key('name_field'),
        controller: _controller,
        autofocus: true,
        maxLength: nameMax,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: 'account.name_label'.tr(), helperText: 'account.name_hint'.tr()),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        FilledButton(key: const Key('name_save'), onPressed: () => Navigator.pop(context, _controller.text), child: Text('common.save'.tr())),
      ],
    );
  }
}
