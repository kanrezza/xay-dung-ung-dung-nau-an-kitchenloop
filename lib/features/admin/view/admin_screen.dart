import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/admin_repository.dart';
import '../domain/admin_stats.dart';
import '../models/admin_user.dart';
import '../../community/view/admin_community_tab.dart';
import 'admin_overview_tab.dart';
import 'widgets/admin_widgets.dart';

/// Quản trị tối thiểu (spec 002): thống kê tài khoản, tìm kiếm, khoá/mở khoá.
/// Không có dữ liệu công thức của người dùng.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, this.now});

  /// Thời điểm "bây giờ" để tính số tài khoản mới (test truyền vào cho ổn định).
  final DateTime Function()? now;

  static Route<void> route() => MaterialPageRoute(builder: (_) => const AdminScreen());

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late final AdminRepository _repository;
  late final Stream<List<AdminUser>> _users;
  final _search = TextEditingController();
  String _query = '';
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _repository = context.read<AdminRepository>();
    _users = _repository.watchUsers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleLock(AdminUser user) async {
    final lock = !user.isLocked;
    final who = user.name.isNotEmpty ? user.name : user.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text((lock ? 'admin.lock_title' : 'admin.unlock_title').tr()),
        content: Text((lock ? 'admin.lock_confirm' : 'admin.unlock_confirm').tr(args: [who])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('admin_confirm'),
            style: lock ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text((lock ? 'admin.lock' : 'admin.unlock').tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(user.id));
    try {
      await _repository.setLocked(user.id, lock);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('admin.err_update'.tr())));
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Ba mục: Tổng quan (spec 007), Tài khoản (spec 002), Cộng đồng (spec 004: thống kê, hàng chờ duyệt).
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('admin.title'.tr()),
          bottom: TabBar(tabs: [
            Tab(key: const Key('admin_tab_overview'), icon: const Icon(Icons.dashboard_outlined), text: 'admin.tab_overview'.tr()),
            Tab(key: const Key('admin_tab_users'), icon: const Icon(Icons.people_outline), text: 'admin.tab_users'.tr()),
            Tab(key: const Key('admin_tab_community'), icon: const Icon(Icons.public), text: 'admin.tab_community'.tr()),
          ]),
        ),
        body: TabBarView(children: [
          Builder(
            builder: (tabContext) => AdminOverviewTab(
              now: widget.now,
              onOpenQueue: () => DefaultTabController.of(tabContext).animateTo(2),
            ),
          ),
          StreamBuilder<List<AdminUser>>(
            stream: _users,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Message(icon: Icons.gpp_bad_outlined, text: 'admin.err_load'.tr());
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final all = snapshot.data!;
              final stats = computeAdminStats(all, (widget.now ?? DateTime.now)());
              final shown = filterAdminUsers(all, _query);
              final self = _repository.currentUid;
              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: AdminStatsRow(stats: stats),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text('admin.privacy_note'.tr(), style: textTheme.bodySmall)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      key: const Key('admin_search'),
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'admin.search_hint'.tr(),
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (shown.isEmpty) _Message(icon: Icons.person_search_outlined, text: 'admin.empty'.tr()),
                  for (final user in shown)
                    AdminUserTile(
                      key: Key('admin_user_${user.id}'),
                      user: user,
                      isSelf: user.id == self,
                      busy: _busy.contains(user.id),
                      onToggleLock: () => _toggleLock(user),
                    ),
                ],
              );
            },
          ),
          AdminCommunityTab(now: widget.now),
        ]),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
