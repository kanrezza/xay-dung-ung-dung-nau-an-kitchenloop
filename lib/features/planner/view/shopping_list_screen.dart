import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../recipes/domain/quantity_parser.dart';
import '../../recipes/providers/recipe_list_provider.dart';
import '../domain/shopping_builder.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/shopping_provider.dart';
import 'widgets/shopping_widgets.dart';
import 'widgets/week_header.dart';

/// "7 quả trứng", "1,5 kg thịt bò", "tiêu xay vừa đủ".
String shoppingItemLabel(ShoppingItem item, String languageCode) => [
      formatQuantity(item.quantity, languageCode: languageCode),
      item.unit ?? '',
      item.name,
    ].where((s) => s.isNotEmpty).join(' ');

/// Tab Đi chợ: danh sách nguyên liệu gộp từ thực đơn của tuần đang xem, tick đã mua,
/// thêm món lẻ. Danh sách được tính lại mỗi khi thực đơn hoặc công thức thay đổi.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key, this.onOpenPlanner, this.embedded = false});

  /// Nằm trong tab Kế hoạch: không có tiêu đề riêng; menu nằm ở thanh chọn tuần.
  final bool embedded;

  /// Chuyển sang tab Thực đơn (khi danh sách trống).
  final VoidCallback? onOpenPlanner;

  Future<void> _addExtra(BuildContext context) async {
    final shopping = context.read<ShoppingProvider>();
    final item = await showDialog<({String name, double? quantity, String unit})>(
      context: context,
      builder: (_) => const ExtraItemDialog(),
    );
    if (item == null || item.name.trim().isEmpty) return;
    final saved = await shopping.addExtra(name: item.name, quantity: item.quantity, unit: item.unit);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('shopping.err_save'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<MealPlanProvider>();
    final shopping = context.watch<ShoppingProvider>();
    final recipes = {for (final r in context.watch<RecipeListProvider>().recipes) r.id: r};
    final lang = context.locale.languageCode;
    final result = buildShoppingList(plan: plan.plan, recipes: recipes, extras: shopping.state.extras);
    final checked = shopping.state.checked;
    final bought = result.items.where((i) => checked.contains(i.key)).length;
    final total = result.items.length;
    final fromPlan = result.items.where((i) => !i.isExtra && (!shopping.hideChecked || !checked.contains(i.key))).toList();
    final extras = result.items.where((i) => i.isExtra && (!shopping.hideChecked || !checked.contains(i.key))).toList();
    final theme = Theme.of(context);

    final menu = PopupMenuButton<String>(
      key: const Key('shopping_menu'),
      onSelected: (v) => v == 'clear' ? shopping.clearChecked() : shopping.setHideChecked(!shopping.hideChecked),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: 'hide', checked: shopping.hideChecked, child: Text('shopping.hide_checked'.tr())),
        PopupMenuItem(value: 'clear', child: Text('shopping.clear_checked'.tr())),
      ],
    );
    final header = WeekHeader(
      weekStart: plan.weekStart,
      isThisWeek: plan.isThisWeek,
      onPrevious: plan.previousWeek,
      onNext: plan.nextWeek,
      onThisWeek: () => plan.showWeek(0),
      trailing: embedded ? menu : null,
    );
    return Scaffold(
      appBar: embedded
          ? PreferredSize(preferredSize: const Size.fromHeight(52), child: Material(child: Center(child: header)))
          : AppBar(
              title: Text('shopping.title'.tr()),
              actions: [menu],
              bottom: PreferredSize(preferredSize: const Size.fromHeight(48), child: header),
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_extra'),
        onPressed: () => _addExtra(context),
        icon: const Icon(Icons.add),
        label: Text('shopping.add_extra'.tr()),
      ),
      body: total == 0
          ? ShoppingEmpty(onOpenPlanner: onOpenPlanner)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ShoppingProgress(bought: bought, total: total),
                if (result.missingRecipes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'shopping.missing'.tr(args: [result.missingRecipes.join(', ')]),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final item in fromPlan)
                        ShoppingItemTile(item: item, label: shoppingItemLabel(item, lang), checked: checked.contains(item.key), onToggle: () => shopping.toggle(item.key)),
                    ],
                  ),
                ),
                if (extras.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text('shopping.extra_section'.tr(), style: theme.textTheme.titleSmall),
                  ),
                  Card(
                    child: Column(
                      children: [
                        for (final item in extras)
                          ShoppingItemTile(
                            item: item,
                            label: shoppingItemLabel(item, lang),
                            checked: checked.contains(item.key),
                            onToggle: () => shopping.toggle(item.key),
                            onDelete: () => shopping.removeExtra(item.extraId!),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
