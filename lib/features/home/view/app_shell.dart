import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../account/view/account_screen.dart';
import '../../community/view/community_screen.dart';
import '../../planner/view/plan_screen.dart';
import '../../recipes/data/account_actions.dart';
import '../../recipes/view/recipe_list_screen.dart';
import 'home_screen.dart';
import 'shell_destination.dart';

/// Khung chính sau đăng nhập: 5 tab (Trang chủ, Công thức, Kế hoạch, Cộng đồng, Tài khoản).
/// Tab Kế hoạch gồm hai tab con Thực đơn | Đi chợ (spec 005). IndexedStack giữ trạng thái từng tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.loginBuilder, this.initial = ShellDestination.home});

  final WidgetBuilder loginBuilder;
  final ShellDestination initial;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index;
  late final ValueNotifier<int> _planTab;

  /// Tab đã được mở ít nhất một lần. Tab chưa mở thì chưa dựng (không tải dữ liệu, không vẽ),
  /// tab đã mở được giữ nguyên trạng thái khi chuyển qua lại.
  final Set<int> _visited = {};
  int _homeRefresh = 0;

  static int _tabOf(ShellDestination d) => switch (d) {
        ShellDestination.home => 0,
        ShellDestination.recipes => 1,
        ShellDestination.planner || ShellDestination.shopping => 2,
        ShellDestination.community => 3,
        ShellDestination.account => 4,
      };

  @override
  void initState() {
    super.initState();
    _index = _tabOf(widget.initial);
    _visited.add(_index);
    _planTab = ValueNotifier(widget.initial == ShellDestination.shopping ? 1 : 0);
  }

  @override
  void dispose() {
    _planTab.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() {
        if (index == 0 && _index != 0) _homeRefresh++;
        _index = index;
        _visited.add(index);
      });

  void _open(ShellDestination d) {
    if (d == ShellDestination.planner) _planTab.value = 0;
    if (d == ShellDestination.shopping) _planTab.value = 1;
    _select(_tabOf(d));
  }

  Widget _page(int i) => switch (i) {
        0 => HomeScreen(onOpen: _open, refreshToken: _homeRefresh),
        1 => const RecipeListScreen(),
        2 => PlanScreen(subTab: _planTab),
        3 => const CommunityScreen(),
        _ => AccountScreen(actions: context.read<AccountActions>(), loginBuilder: widget.loginBuilder),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 5; i++)
            _visited.contains(i)
                // Tab ẩn: tắt hiệu ứng chuyển động (ví dụ vòng quay "đang tải") để khỏi vẽ lại mỗi khung hình.
                ? TickerMode(enabled: i == _index, child: _page(i))
                : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(
              key: const Key('nav_home'),
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: 'nav.home'.tr()),
          NavigationDestination(
              key: const Key('nav_recipes'),
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: 'nav.recipes'.tr()),
          NavigationDestination(
              key: const Key('nav_plan'),
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: 'nav.plan'.tr()),
          NavigationDestination(
              key: const Key('nav_community'),
              icon: const Icon(Icons.public_outlined),
              selectedIcon: const Icon(Icons.public),
              label: 'nav.community'.tr()),
          NavigationDestination(
              key: const Key('nav_account'),
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: 'nav.account'.tr()),
        ],
      ),
    );
  }
}
