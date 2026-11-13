import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../home/view/widgets/recipe_cover.dart';
import '../../../recipes/domain/text_normalizer.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/view/display_helpers.dart';
import '../../../recipes/view/widgets/servings_stepper.dart';
import '../../domain/week.dart';
import '../../models/week_plan.dart';
import 'week_header.dart';

/// Kết quả của bảng thêm món.
class AddMealChoice {
  const AddMealChoice({required this.recipe, required this.day, required this.slot, required this.servings});

  final Recipe recipe;
  final int day;
  final MealSlot slot;
  final int servings;
}

String slotLabel(MealSlot slot) => 'planner.slot_${slot.name}'.tr();

IconData slotIcon(MealSlot slot) => switch (slot) {
      MealSlot.breakfast => Icons.wb_twilight,
      MealSlot.lunch => Icons.wb_sunny_outlined,
      MealSlot.dinner => Icons.nightlight_outlined,
    };

/// Bảng thêm món vào thực đơn. Từ màn Thực đơn: ngày và bữa đã biết, chọn công thức.
/// Từ màn chi tiết: công thức đã biết, chọn ngày và bữa.
Future<AddMealChoice?> showAddMealSheet(
  BuildContext context, {
  required DateTime weekStart,
  required List<Recipe> recipes,
  Recipe? recipe,
  int? day,
  MealSlot? slot,
}) {
  return showModalBottomSheet<AddMealChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddMealSheet(weekStart: weekStart, recipes: recipes, recipe: recipe, day: day, slot: slot),
  );
}

class _AddMealSheet extends StatefulWidget {
  const _AddMealSheet({required this.weekStart, required this.recipes, this.recipe, this.day, this.slot});

  final DateTime weekStart;
  final List<Recipe> recipes;
  final Recipe? recipe;
  final int? day;
  final MealSlot? slot;

  @override
  State<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<_AddMealSheet> {
  Recipe? _recipe;
  late int _day;
  late MealSlot _slot;
  int _servings = 2;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    final today = dayIndexInWeek(widget.weekStart, DateTime.now());
    _day = widget.day ?? (today >= 0 ? today : 0);
    _slot = widget.slot ?? MealSlot.dinner;
    if (_recipe != null) _servings = _recipe!.baseServings;
  }

  void _pick(Recipe r) => setState(() {
        _recipe = r;
        _servings = r.baseServings;
      });

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: recipe == null ? _buildPicker(context) : _buildOptions(context, recipe),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final q = normalizeForSearch(_query);
    final shown = widget.recipes.where((r) => q.isEmpty || normalizeForSearch(r.title).contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Text('planner.pick_recipe'.tr(), style: Theme.of(context).textTheme.titleLarge),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('pick_search'),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'planner.search'.tr(),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          Expanded(
            child: widget.recipes.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('planner.no_recipes'.tr(), textAlign: TextAlign.center)))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) {
                      final r = shown[i];
                      final secs = recipeTotalSeconds(r);
                      return ListTile(
                        key: Key('pick_${r.id}'),
                        leading: RecipeCover(title: r.title, imageUrl: r.imageUrl, width: 52, height: 52, borderRadius: 12, iconSize: 22),
                        title: Text(recipeDisplayTitle(r), maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([
                          'recipes.info_servings'.plural(r.baseServings),
                          if (secs > 0) formatCookTime(secs),
                        ].join(' · ')),
                        onTap: () => _pick(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context, Recipe recipe) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RecipeCover(title: recipe.title, imageUrl: recipe.imageUrl, width: 56, height: 56, borderRadius: 14, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(recipeDisplayTitle(recipe), style: theme.textTheme.titleLarge)),
            ],
          ),
          if (widget.day == null) ...[
            const SizedBox(height: 20),
            Text('planner.choose_day'.tr(), style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 0; d < 7; d++)
                  ChoiceChip(
                    key: Key('pick_day_$d'),
                    label: Text('${'planner.day_$d'.tr()} · ${shortDate(dayOfWeek(widget.weekStart, d))}'),
                    selected: _day == d,
                    onSelected: (_) => setState(() => _day = d),
                  ),
              ],
            ),
          ],
          if (widget.slot == null) ...[
            const SizedBox(height: 20),
            Text('planner.choose_slot'.tr(), style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<MealSlot>(
              segments: [
                for (final s in MealSlot.values)
                  ButtonSegment(value: s, icon: Icon(slotIcon(s)), label: Text(slotLabel(s))),
              ],
              selected: {_slot},
              onSelectionChanged: (v) => setState(() => _slot = v.first),
            ),
          ],
          const SizedBox(height: 20),
          Text('planner.servings'.tr(), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ServingsStepper(value: _servings, onChanged: (v) => setState(() => _servings = v)),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('add_meal_confirm'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: () => Navigator.pop(
              context,
              AddMealChoice(recipe: recipe, day: _day, slot: _slot, servings: _servings),
            ),
            icon: const Icon(Icons.event_available),
            label: Text('planner.confirm'.tr()),
          ),
        ],
      ),
    );
  }
}
