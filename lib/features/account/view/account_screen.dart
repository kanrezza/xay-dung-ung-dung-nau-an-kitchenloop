import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../admin/view/admin_screen.dart';
import '../../community/providers/community_provider.dart';
import '../../planner/providers/meal_plan_provider.dart';
import '../../recipes/data/account_actions.dart';
import '../../recipes/providers/recipe_list_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/theme_mode_provider.dart';
import 'widgets/account_sections.dart';
import 'widgets/profile_dialogs.dart';
import 'widgets/user_avatar.dart';

/// Phiên bản hiển thị ở mục Giới thiệu.
const appVersion = '1.4.0';

/// Tab Tài khoản (spec 005): hồ sơ (ảnh, tên), số liệu, cài đặt, đổi mật khẩu, quản trị, đăng xuất.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.actions, required this.loginBuilder});

  final AccountActions actions;

  /// Màn hình đăng nhập để quay về sau khi đăng xuất.
  final WidgetBuilder loginBuilder;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final Future<bool> _isAdmin = widget.actions.isAdmin();

  @override
  void initState() {
    super.initState();
    // Đếm bài đã chia sẻ cần danh sách cộng đồng.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityProvider>().ensureListening();
    });
  }

  Future<void> _confirmAndSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('account.logout'.tr()),
        content: Text('account.logout_confirm'.tr()),
        actions: [
          TextButton(key: const Key('logout_cancel'), onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(key: const Key('logout_confirm'), onPressed: () => Navigator.pop(d, true), child: Text('account.logout'.tr())),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.actions.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true)
        .pushAndRemoveUntil(MaterialPageRoute<void>(builder: widget.loginBuilder), (route) => false);
  }

  Future<void> _changePassword(String email) async {
    final profile = context.read<ProfileProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.lock_reset),
        title: Text('account.change_password'.tr()),
        content: Text('account.change_password_desc'.tr(args: [email])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(key: const Key('password_send'), onPressed: () => Navigator.pop(d, true), child: Text('account.send'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await profile.sendPasswordReset();
    messenger.showSnackBar(SnackBar(
      content: Text(sent ? 'account.password_sent'.tr(args: [email]) : 'account.password_failed'.tr()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    final email = profile?.email ?? widget.actions.email ?? '';
    final themeMode = context.watch<ThemeModeProvider>();
    final uid = context.watch<CommunityProvider>().currentUid;
    final shared = context.watch<CommunityProvider>().posts.where((p) => p.authorId == uid).length;
    final recipes = context.watch<RecipeListProvider>().recipes.length;
    final week = context.watch<MealPlanProvider>().thisWeek.entries.length;
    final lang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text('account.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // --- Hồ sơ ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primaryContainer, scheme.surfaceContainerLow],
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  key: const Key('change_avatar'),
                  onTap: profileProvider.uploading ? null : () => showAvatarSheet(context),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      UserAvatar(profile: profile, radius: 48),
                      if (profileProvider.uploading)
                        const SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 3)),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: scheme.primary,
                          child: Icon(Icons.photo_camera, size: 16, color: scheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        profile?.displayName ?? '',
                        key: const Key('profile_name'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      key: const Key('edit_name'),
                      tooltip: 'account.edit_name'.tr(),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => showRenameDialog(context),
                    ),
                  ],
                ),
                Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    MiniStat(value: recipes, label: 'account.stat_recipes'.tr()),
                    MiniStat(value: week, label: 'account.stat_week'.tr()),
                    MiniStat(value: shared, label: 'account.stat_shared'.tr()),
                  ],
                ),
              ],
            ),
          ),

          // --- Cài đặt ---
          SettingsSection(title: 'account.section_settings'.tr(), children: [
            ChoiceRow(
              icon: Icons.translate,
              label: 'account.language'.tr(),
              chips: [
                ChoiceChip(key: const Key('lang_vi'), label: const Text('Tiếng Việt'), selected: lang == 'vi', onSelected: (_) => widget.actions.setLanguage(context, const Locale('vi'))),
                ChoiceChip(key: const Key('lang_en'), label: const Text('English'), selected: lang == 'en', onSelected: (_) => widget.actions.setLanguage(context, const Locale('en'))),
              ],
            ),
            ChoiceRow(
              icon: Icons.contrast,
              label: 'account.theme'.tr(),
              chips: [
                for (final (mode, key) in [(ThemeMode.system, 'system'), (ThemeMode.light, 'light'), (ThemeMode.dark, 'dark')])
                  ChoiceChip(
                    key: Key('theme_$key'),
                    label: Text('account.theme_$key'.tr()),
                    selected: themeMode.mode == mode,
                    onSelected: (_) => themeMode.setMode(mode),
                  ),
              ],
            ),
          ]),

          // --- Tài khoản ---
          SettingsSection(title: 'account.section_account'.tr(), children: [
            ListTile(
              key: const Key('change_password'),
              leading: const Icon(Icons.lock_reset),
              title: Text('account.change_password'.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: email.isEmpty ? null : () => _changePassword(email),
            ),
            FutureBuilder<bool>(
              future: _isAdmin,
              builder: (context, snap) => snap.data != true
                  ? const SizedBox.shrink()
                  : ListTile(
                      key: const Key('admin_entry'),
                      leading: const Icon(Icons.admin_panel_settings_outlined),
                      title: Text('account.admin'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, AdminScreen.route()),
                    ),
            ),
          ]),

          // --- Giới thiệu ---
          SettingsSection(title: 'account.section_about'.tr(), children: [
            ListTile(
              leading: const Icon(Icons.restaurant_menu),
              title: const Text('KitchenLoop'),
              subtitle: Text('account.about_desc'.tr()),
              trailing: Text('account.version'.tr(args: [appVersion]), style: theme.textTheme.bodySmall),
            ),
          ]),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('logout_button'),
            onPressed: _confirmAndSignOut,
            icon: const Icon(Icons.logout),
            label: Text('account.logout'.tr()),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
