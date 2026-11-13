import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../planner/view/meal_plan_screen.dart';
import '../../planner/view/shopping_list_screen.dart';
import '../../recipes/view/recipe_list_screen.dart';
import 'home_screen.dart';

/// Khung chính sau đăng nhập: thanh điều hướng 4 tab (Trang chủ, Công thức, Thực đơn, Đi chợ).
/// Dùng IndexedStack để mỗi tab giữ nguyên trạng thái (vị trí cuộn, ô tìm kiếm...).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.loginBuilder, this.initialTab = 0});

  final WidgetBuilder loginBuilder;
  final int initialTab;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialTab;
  int _homeRefresh = 0;

  void _select(int index) => setState(() {
        if (index == 0 && _index != 0) _homeRefresh++;
        _index = index;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(loginBuilder: widget.loginBuilder, onOpenTab: _select, refreshToken: _homeRefresh),
          RecipeListScreen(loginBuilder: widget.loginBuilder),
          const MealPlanScreen(),
          ShoppingListScreen(onOpenPlanner: () => _select(2)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          NavigationDestination(key: const Key('nav_home'), icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: 'nav.home'.tr()),
          NavigationDestination(key: const Key('nav_recipes'), icon: const Icon(Icons.menu_book_outlined), selectedIcon: const Icon(Icons.menu_book), label: 'nav.recipes'.tr()),
          NavigationDestination(key: const Key('nav_planner'), icon: const Icon(Icons.calendar_month_outlined), selectedIcon: const Icon(Icons.calendar_month), label: 'nav.planner'.tr()),
          NavigationDestination(key: const Key('nav_shopping'), icon: const Icon(Icons.shopping_cart_outlined), selectedIcon: const Icon(Icons.shopping_cart), label: 'nav.shopping'.tr()),
        ],
      ),
    );
  }
}
