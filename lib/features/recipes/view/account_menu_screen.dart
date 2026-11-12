import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../data/account_actions.dart';

/// Màn hình tài khoản tối thiểu: email, đổi ngôn ngữ và đăng xuất.
class AccountMenuScreen extends StatelessWidget {
  const AccountMenuScreen({
    super.key,
    required this.actions,
    required this.loginBuilder,
  });

  final AccountActions actions;

  /// Màn hình đăng nhập để quay về sau khi đăng xuất.
  final WidgetBuilder loginBuilder;

  Future<void> _confirmAndSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('account.logout'.tr()),
        content: Text('account.logout_confirm'.tr()),
        actions: [
          TextButton(
            key: const Key('logout_cancel'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('logout_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('account.logout'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await actions.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: loginBuilder),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = context.locale.languageCode;
    return Scaffold(
      appBar: AppBar(title: Text('account.title'.tr())),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(actions.email ?? '—'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'account.language'.tr(),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          _LanguageTile(
            tileKey: const Key('lang_vi'),
            label: 'Tiếng Việt',
            selected: current == 'vi',
            onTap: () => actions.setLanguage(context, const Locale('vi')),
          ),
          _LanguageTile(
            tileKey: const Key('lang_en'),
            label: 'English',
            selected: current == 'en',
            onTap: () => actions.setLanguage(context, const Locale('en')),
          ),
          const Divider(),
          ListTile(
            key: const Key('logout_button'),
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text(
              'account.logout'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _confirmAndSignOut(context),
          ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.tileKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      title: Text(label),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}
