import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/cooking_session_store.dart';
import '../data/screen_awake.dart';
import '../data/timer_notifier.dart';
import '../models/cooking_session.dart';
import '../models/recipe.dart';
import '../providers/cooking_mode_provider.dart';
import 'display_helpers.dart';
import 'widgets/cooking_ingredients_drawer.dart';
import 'widgets/cooking_step_page.dart';
import 'widgets/cooking_timer_bar.dart';

/// Chế độ nấu từng bước: mỗi lần một bước bằng chữ lớn, vuốt hoặc bấm để
/// chuyển bước, giữ màn hình sáng, hẹn giờ cho bước có thời gian.
class CookingModeScreen extends StatefulWidget {
  const CookingModeScreen({super.key});

  /// Route kèm [CookingModeProvider] riêng cho mỗi lần nấu. Cần
  /// [CookingSessionStore], [TimerNotifier] và [ScreenAwake] trong cây widget.
  ///
  /// [servings] là khẩu phần người dùng đã chọn ở màn hình chi tiết (null = khẩu
  /// phần gốc). Khi tiếp tục một phiên dở thì dùng khẩu phần đã lưu trong phiên.
  static Route<void> route(BuildContext context, Recipe recipe, {int? servings}) {
    final store = context.read<CookingSessionStore>();
    final notifier = context.read<TimerNotifier>();
    final awake = context.read<ScreenAwake>();
    return MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (_) => CookingModeProvider(
          recipe: recipe,
          store: store,
          notifier: notifier,
          awake: awake,
          initialServings: servings,
          timerTitle: (_) => 'recipes.timer_done'.tr(),
          timerBody: (step) => 'recipes.timer_notif_body'.tr(args: [recipeDisplayTitle(recipe), '${step.order}']),
        ),
        child: const CookingModeScreen(),
      ),
    );
  }

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> with WidgetsBindingObserver {
  final _pageController = PageController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final CookingModeProvider _provider;
  int _knownAlarms = 0;
  bool _doneShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<CookingModeProvider>();
    _provider.addListener(_onProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.removeListener(_onProviderChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _provider.setForeground(state == AppLifecycleState.resumed);
  }

  Future<void> _bootstrap() async {
    final saved = await _provider.loadSavedSession();
    CookingSession? resume;
    if (saved != null) {
      if (!mounted) return;
      final keepGoing = await _askResume(saved.stepIndex + 1);
      if (keepGoing == true) {
        resume = saved;
      } else {
        await _provider.discardSaved(saved);
      }
    }
    if (!mounted) return;
    await _provider.begin(resumeFrom: resume);
  }

  Future<bool?> _askResume(int stepNumber) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('recipes.cook_resume_title'.tr()),
        actions: [
          TextButton(
            key: const Key('cook_restart'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('recipes.restart'.tr()),
          ),
          FilledButton(
            key: const Key('cook_continue'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('recipes.continue_cooking'.tr(args: ['$stepNumber'])),
          ),
        ],
      ),
    );
  }

  void _onProviderChanged() {
    // Có cảnh báo hết giờ mới: rung và phát âm báo (ngoài thông báo của hệ thống).
    final alarms = _provider.alarms.length;
    if (alarms > _knownAlarms) _alertUser();
    _knownAlarms = alarms;

    if (_provider.isFinished && !_doneShown) {
      _doneShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDone());
    }
  }

  Future<void> _alertUser() async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Thiết bị không hỗ trợ rung/âm báo: cảnh báo trên màn hình vẫn hiện.
    }
  }

  Future<void> _showDone() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text('recipes.cook_done_title'.tr()),
        content: Text('recipes.cook_done_message'.tr()),
        actions: [
          FilledButton(
            key: const Key('cook_done_close'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  /// Giữ PageView khớp với bước hiện tại khi bước đổi bằng nút bấm hoặc chip.
  void _alignPage(int index) {
    if (!_pageController.hasClients) return;
    final current = (_pageController.page ?? index.toDouble()).round();
    if (current != index) {
      _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<CookingModeProvider>();
    final recipe = p.recipe;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && p.isActive) _alignPage(p.stepIndex);
    });

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(recipeDisplayTitle(recipe), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            key: const Key('open_ingredients'),
            tooltip: 'recipes.ingredients'.tr(),
            icon: const Icon(Icons.list_alt),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: CookingIngredientsDrawer(provider: p),
      // Vòng quay tải chỉ hiện khi đang chờ bắt đầu; đã hoàn thành thì giữ nội dung
      // phía sau hộp thoại "Nấu xong rồi!" để màn hình không bị nháy.
      body: (!p.isActive && !p.isFinished)
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(value: (p.stepIndex + 1) / p.stepCount, minHeight: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'recipes.step_of'.tr(args: ['${p.stepIndex + 1}', '${p.stepCount}']),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                CookingTimerBar(provider: p),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: p.stepCount,
                    onPageChanged: p.goTo,
                    itemBuilder: (context, index) => CookingStepPage(step: recipe.steps[index], provider: p),
                  ),
                ),
                _BottomBar(provider: p),
              ],
            ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.provider});

  final CookingModeProvider provider;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('cook_prev'),
                onPressed: provider.canGoPrevious ? provider.previous : null,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text('recipes.cook_prev'.tr(), style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                key: const Key('cook_next'),
                onPressed: provider.next,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                child: Text(
                  (provider.isLastStep ? 'recipes.cook_finish' : 'recipes.cook_next').tr(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
