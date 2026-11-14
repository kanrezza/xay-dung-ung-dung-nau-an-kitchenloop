import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'meal_plan_screen.dart';
import 'shopping_list_screen.dart';

/// Tab Kế hoạch (spec 005): hai tab con Thực đơn | Đi chợ, dùng chung tuần đang xem.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.subTab, this.now});

  /// Tab con đang chọn (0 = Thực đơn, 1 = Đi chợ); khung chính đổi giá trị này khi mở từ lối tắt.
  final ValueNotifier<int> subTab;
  final DateTime Function()? now;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.subTab.value);

  @override
  void initState() {
    super.initState();
    widget.subTab.addListener(_onSubTab);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) widget.subTab.value = _tabs.index;
    });
  }

  void _onSubTab() {
    if (_tabs.index != widget.subTab.value) _tabs.animateTo(widget.subTab.value);
  }

  @override
  void dispose() {
    widget.subTab.removeListener(_onSubTab);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('plan.title'.tr()),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(key: const Key('plan_tab_meals'), icon: const Icon(Icons.calendar_month_outlined), text: 'plan.tab_meals'.tr()),
            Tab(key: const Key('plan_tab_shopping'), icon: const Icon(Icons.shopping_cart_outlined), text: 'plan.tab_shopping'.tr()),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          MealPlanScreen(embedded: true, now: widget.now),
          ShoppingListScreen(embedded: true, onOpenPlanner: () => _tabs.animateTo(0)),
        ],
      ),
    );
  }
}
