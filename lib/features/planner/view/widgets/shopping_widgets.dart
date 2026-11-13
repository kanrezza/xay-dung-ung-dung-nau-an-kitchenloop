import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../recipes/domain/quantity_parser.dart';
import '../../domain/shopping_builder.dart';

class ShoppingProgress extends StatelessWidget {
  const ShoppingProgress({super.key, required this.bought, required this.total});

  final int bought;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = bought == total;
    return Card(
      color: done ? theme.colorScheme.tertiaryContainer : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(done ? Icons.check_circle : Icons.shopping_basket_outlined),
                const SizedBox(width: 8),
                Text(
                  done ? 'shopping.all_done'.tr() : 'shopping.progress'.tr(args: ['$bought', '$total']),
                  key: const Key('shopping_progress'),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: total == 0 ? 0 : bought / total, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({super.key, required this.item, required this.label, required this.checked, required this.onToggle, this.onDelete});

  final ShoppingItem item;
  final String label;
  final bool checked;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return CheckboxListTile(
      key: Key('item_${item.key}'),
      value: checked,
      onChanged: (_) => onToggle(),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        label,
        style: TextStyle(
          decoration: checked ? TextDecoration.lineThrough : null,
          color: checked ? muted : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: item.sources.isEmpty
          ? null
          : Text('shopping.from'.tr(args: [item.sources.join(', ')]), maxLines: 2, overflow: TextOverflow.ellipsis),
      secondary: onDelete == null
          ? null
          : IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'common.delete'.tr(), onPressed: onDelete),
    );
  }
}

class ShoppingEmpty extends StatelessWidget {
  const ShoppingEmpty({super.key, this.onOpenPlanner});

  final VoidCallback? onOpenPlanner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('shopping.empty'.tr(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (onOpenPlanner != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('shopping_go_plan'),
                onPressed: onOpenPlanner,
                icon: const Icon(Icons.calendar_month),
                label: Text('shopping.go_plan'.tr()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại thêm món lẻ. Tự giữ và giải phóng các ô nhập khi đóng hẳn (giải phóng ngay
/// sau khi `showDialog` trả về sẽ lỗi vì hiệu ứng đóng hộp thoại vẫn còn dùng chúng).
class ExtraItemDialog extends StatefulWidget {
  const ExtraItemDialog({super.key});

  @override
  State<ExtraItemDialog> createState() => ExtraItemDialogState();
}

class ExtraItemDialogState extends State<ExtraItemDialog> {
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('shopping.add_extra'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('extra_name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'shopping.extra_name'.tr()),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('extra_quantity'),
                  controller: _quantity,
                  decoration: InputDecoration(labelText: 'shopping.extra_quantity'.tr(), hintText: '1/2'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('extra_unit'),
                  controller: _unit,
                  decoration: InputDecoration(labelText: 'shopping.extra_unit'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common.cancel'.tr())),
        FilledButton(
          key: const Key('extra_save'),
          onPressed: () => Navigator.pop(
            context,
            (name: _name.text, quantity: parseQuantity(_quantity.text), unit: _unit.text),
          ),
          child: Text('shopping.add_extra'.tr()),
        ),
      ],
    );
  }
}
