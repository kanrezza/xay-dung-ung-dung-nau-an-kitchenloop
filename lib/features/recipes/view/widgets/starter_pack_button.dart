import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/starter_recipes.dart';
import '../../providers/recipe_list_provider.dart';

/// Nút "Thêm công thức mẫu": hỏi xác nhận rồi thêm bộ món Việt có sẵn vào sổ của người dùng.
class StarterPackButton extends StatefulWidget {
  const StarterPackButton({super.key, this.asText = false});

  /// `true`: nút chữ (màn trống); `false`: nút biểu tượng trên thanh tiêu đề.
  final bool asText;

  @override
  State<StarterPackButton> createState() => _StarterPackButtonState();
}

class _StarterPackButtonState extends State<StarterPackButton> {
  bool _busy = false;

  Future<void> _run() async {
    final provider = context.read<RecipeListProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.auto_awesome),
        title: Text('recipes.starter_title'.tr()),
        content: Text('recipes.starter_desc'.tr(args: ['$starterRecipeCount'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text('common.cancel'.tr())),
          FilledButton(key: const Key('starter_confirm'), onPressed: () => Navigator.pop(d, true), child: Text('recipes.starter_add'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    String message;
    try {
      final added = await provider.addStarterRecipes();
      message = added == 0 ? 'recipes.starter_none'.tr() : 'recipes.starter_done'.plural(added);
    } catch (_) {
      message = 'recipes.err_save_failed'.tr();
    }
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asText) {
      return TextButton.icon(
        key: const Key('starter_pack_text'),
        onPressed: _busy ? null : _run,
        icon: const Icon(Icons.auto_awesome),
        label: Text('recipes.starter_title'.tr()),
      );
    }
    return IconButton(
      key: const Key('starter_pack'),
      tooltip: 'recipes.starter_title'.tr(),
      onPressed: _busy ? null : _run,
      icon: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome_outlined),
    );
  }
}
