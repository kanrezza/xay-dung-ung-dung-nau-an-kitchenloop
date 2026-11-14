import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../home/view/widgets/recipe_cover.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/recipe_list_provider.dart';
import '../../recipes/view/recipe_detail_screen.dart';
import '../domain/week.dart';
import '../models/week_plan.dart';
import '../providers/meal_plan_provider.dart';
import 'widgets/add_meal_sheet.dart';
import 'widgets/week_header.dart';

/// Báo lỗi lưu thực đơn (dùng chung cho màn Thực đơn và màn chi tiết công thức).
void showMealPlanError(BuildContext context, MealPlanError error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text((error == MealPlanError.full ? 'planner.err_full' : 'planner.err_save').tr())),
  );
}

/// Tab Thực đơn: 7 ngày của tuần, mỗi ngày 3 bữa; thêm/xoá món, chuyển tuần.
class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({super.key, this.now, this.embedded = false});

  /// Nằm trong tab Kế hoạch: không có tiêu đề riêng, chỉ có thanh chọn tuần.
  final bool embedded;

  /// Thời điểm hiện tại (test truyền vào để đánh dấu "hôm nay" ổn định).
  final DateTime Function()? now;

  Future<void> _add(BuildContext context, int day, MealSlot slot) async {
    final provider = context.read<MealPlanProvider>();
    final choice = await showAddMealSheet(
      context,
      weekStart: provider.weekStart,
      recipes: context.read<RecipeListProvider>().recipes,
      day: day,
      slot: slot,
    );
    if (choice == null || !context.mounted) return;
    final error = await provider.add(
      day: choice.day,
      slot: choice.slot,
      recipeId: choice.recipe.id,
      title: choice.recipe.title,
      servings: choice.servings,
    );
    if (error != null && context.mounted) showMealPlanError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MealPlanProvider>();
    final recipes = {for (final r in context.watch<RecipeListProvider>().recipes) r.id: r};
    final today = dayIndexInWeek(provider.weekStart, (now ?? DateTime.now)());
    final header = WeekHeader(
      weekStart: provider.weekStart,
      isThisWeek: provider.isThisWeek,
      onPrevious: provider.previousWeek,
      onNext: provider.nextWeek,
      onThisWeek: () => provider.showWeek(0),
    );
    return Scaffold(
      appBar: embedded
          ? PreferredSize(preferredSize: const Size.fromHeight(52), child: Material(child: Center(child: header)))
          : AppBar(
              title: Text('planner.title'.tr()),
              bottom: PreferredSize(preferredSize: const Size.fromHeight(48), child: header),
            ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, day) => _DayCard(
          key: Key('day_$day'),
          weekStart: provider.weekStart,
          day: day,
          isToday: day == today,
          plan: provider.plan,
          recipes: recipes,
          onAdd: (slot) => _add(context, day, slot),
          onRemove: provider.remove,
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.weekStart,
    required this.day,
    required this.isToday,
    required this.plan,
    required this.recipes,
    required this.onAdd,
    required this.onRemove,
  });

  final DateTime weekStart;
  final int day;
  final bool isToday;
  final WeekPlan plan;
  final Map<String, Recipe> recipes;
  final void Function(MealSlot slot) onAdd;
  final Future<MealPlanError?> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = plan.entries.where((e) => e.day == day).length;
    return Card(
      color: isToday ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isToday ? BorderSide(color: scheme.primary, width: 1.5) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('planner.day_$day'.tr(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text(shortDate(dayOfWeek(weekStart, day)), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                    child: Text('planner.today'.tr(), style: TextStyle(color: scheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
                const Spacer(),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text('planner.week_count'.plural(count), style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
            for (final slot in MealSlot.values)
              _SlotRow(
                day: day,
                slot: slot,
                entries: plan.entriesFor(day, slot),
                recipes: recipes,
                onAdd: () => onAdd(slot),
                onRemove: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.day,
    required this.slot,
    required this.entries,
    required this.recipes,
    required this.onAdd,
    required this.onRemove,
  });

  final int day;
  final MealSlot slot;
  final List<MealEntry> entries;
  final Map<String, Recipe> recipes;
  final VoidCallback onAdd;
  final Future<MealPlanError?> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // Đủ rộng cho "Breakfast" (tiếng Anh) mà không bị cắt.
            width: 92,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Icon(slotIcon(slot), size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Flexible(child: Text(slotLabel(slot), style: theme.textTheme.labelMedium, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries) _EntryTile(entry: e, recipe: recipes[e.recipeId], onRemove: () => onRemove(e.id)),
                TextButton.icon(
                  key: Key('add_${day}_${slot.name}'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('planner.add'.tr()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.recipe, required this.onRemove});

  final MealEntry entry;
  final Recipe? recipe;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deleted = recipe == null;
    return Card(
      key: Key('entry_${entry.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      color: theme.colorScheme.surface,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 8),
        leading: RecipeCover(
          title: entry.title,
          imageUrl: recipe?.imageUrl ?? '',
          width: 40,
          height: 40,
          borderRadius: 10,
          iconSize: 18,
        ),
        title: Text(
          entry.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: deleted ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
        ),
        subtitle: Text(deleted ? 'planner.deleted_recipe'.tr() : 'planner.servings_n'.plural(entry.servings)),
        onTap: deleted
            ? null
            : () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RecipeDetailScreen(recipeId: entry.recipeId))),
        trailing: IconButton(
          key: Key('remove_${entry.id}'),
          tooltip: 'planner.remove'.tr(),
          icon: const Icon(Icons.close, size: 20),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
