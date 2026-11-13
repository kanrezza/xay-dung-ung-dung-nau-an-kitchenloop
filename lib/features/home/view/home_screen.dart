import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../planner/domain/shopping_builder.dart';
import '../../planner/providers/meal_plan_provider.dart';
import '../../planner/providers/shopping_provider.dart';
import '../../recipes/data/account_actions.dart';
import '../../recipes/data/cooking_session_store.dart';
import '../../recipes/models/cooking_session.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/providers/recipe_list_provider.dart';
import '../../recipes/view/account_menu_screen.dart';
import '../../recipes/view/cooking_mode_screen.dart';
import '../../recipes/view/recipe_detail_screen.dart';
import '../../recipes/view/recipe_editor_screen.dart';
import 'widgets/home_sections.dart';

/// Trang chủ: lời chào, số liệu nhanh, món hôm nay, nấu tiếp, gợi ý.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.loginBuilder,
    required this.onOpenTab,
    this.refreshToken = 0,
    this.now,
  });

  final WidgetBuilder loginBuilder;

  /// Chuyển tab trong khung chính (1 = Công thức, 2 = Thực đơn, 3 = Đi chợ).
  final void Function(int tab) onOpenTab;

  /// Tăng mỗi khi tab Trang chủ được chọn lại, để đọc lại các món đang nấu dở.
  final int refreshToken;
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<CookingSession>> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = context.read<CookingSessionStore>().loadAll();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) {
      _sessions = context.read<CookingSessionStore>().loadAll();
    }
  }

  String _greeting(DateTime now) {
    if (now.hour < 11) return 'home.greeting_morning'.tr();
    if (now.hour < 18) return 'home.greeting_afternoon'.tr();
    return 'home.greeting_evening'.tr();
  }

  void _openDetail(String id) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RecipeDetailScreen(recipeId: id)));

  void _openAccount() => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AccountMenuScreen(actions: context.read<AccountActions>(), loginBuilder: widget.loginBuilder),
        ),
      );

  Future<void> _continue(Recipe recipe) async {
    await Navigator.push(context, CookingModeScreen.route(context, recipe));
    if (mounted) setState(() => _sessions = context.read<CookingSessionStore>().loadAll());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = (widget.now ?? DateTime.now)();
    final recipeList = context.watch<RecipeListProvider>();
    final plan = context.watch<MealPlanProvider>();
    final recipes = {for (final r in recipeList.recipes) r.id: r};
    final today = plan.today;
    final weekCount = plan.thisWeek.entries.length;
    // "Cần mua": các dòng chưa tick của tuần này (trạng thái đi chợ chỉ biết khi đang xem tuần này).
    final shopping = context.watch<ShoppingProvider>();
    final checked = shopping.weekStart == plan.thisWeekStart ? shopping.state.checked : const <String>{};
    final toBuy = buildShoppingList(plan: plan.thisWeek, recipes: recipes, extras: shopping.weekStart == plan.thisWeekStart ? shopping.state.extras : const [])
        .items
        .where((i) => !checked.contains(i.key))
        .length;
    final planned = plan.thisWeek.entries.map((e) => e.recipeId).toSet();
    final suggestions = [
      ...recipeList.recipes.where((r) => !planned.contains(r.id)),
      ...recipeList.recipes.where((r) => planned.contains(r.id)),
    ].take(8).toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => setState(() => _sessions = context.read<CookingSessionStore>().loadAll()),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_greeting(now),
                              key: const Key('home_greeting'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                          Text('home.subtitle'.tr(), style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('open_account'),
                      tooltip: 'account.title'.tr(),
                      icon: const Icon(Icons.person_outline),
                      onPressed: _openAccount,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                // Ba ô luôn cao bằng nhau dù nhãn dài ngắn khác nhau.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: StatTile(
                              key: const Key('stat_recipes'),
                              icon: Icons.menu_book,
                              value: recipeList.recipes.length,
                              label: 'home.stat_recipes'.tr(),
                              onTap: () => widget.onOpenTab(1))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile(
                              key: const Key('stat_week'),
                              icon: Icons.calendar_month,
                              value: weekCount,
                              label: 'home.stat_week'.tr(),
                              onTap: () => widget.onOpenTab(2))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile(
                              key: const Key('stat_shopping'),
                              icon: Icons.shopping_basket,
                              value: toBuy,
                              label: 'home.stat_shopping'.tr(),
                              onTap: () => widget.onOpenTab(3))),
                    ],
                  ),
                ),
              ),
              FutureBuilder<List<CookingSession>>(
                future: _sessions,
                builder: (context, snap) {
                  final active = [
                    for (final s in snap.data ?? const <CookingSession>[])
                      if (recipes[s.recipeId] != null) (s, recipes[s.recipeId]!),
                  ];
                  if (active.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle('home.continue'.tr()),
                      for (final (session, recipe) in active.take(3))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: ContinueCookingCard(
                              key: Key('continue_${recipe.id}'), recipe: recipe, session: session, onTap: () => _continue(recipe)),
                        ),
                    ],
                  );
                },
              ),
              SectionTitle('home.today'.tr(), action: 'home.plan_now'.tr(), onAction: () => widget.onOpenTab(2)),
              if (today.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: ListTile(
                      key: const Key('today_empty'),
                      leading: const Icon(Icons.event_note),
                      title: Text('home.today_empty'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                )
              else
                for (final e in today)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TodayMealTile(
                      key: Key('today_${e.id}'),
                      entry: e,
                      recipe: recipes[e.recipeId],
                      onTap: recipes[e.recipeId] == null ? null : () => _openDetail(e.recipeId),
                    ),
                  ),
              if (suggestions.isEmpty) ...[
                SectionTitle('home.suggestions'.tr()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text('home.empty_recipes'.tr(), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            key: const Key('home_add_recipe'),
                            onPressed: () => Navigator.push(context, RecipeEditorScreen.route(context)),
                            icon: const Icon(Icons.add),
                            label: Text('home.add_recipe'.tr()),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SectionTitle('home.suggestions'.tr(), action: 'home.see_all'.tr(), onAction: () => widget.onOpenTab(1)),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => SuggestionCard(
                      key: Key('suggest_${suggestions[i].id}'),
                      recipe: suggestions[i],
                      onTap: () => _openDetail(suggestions[i].id),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
