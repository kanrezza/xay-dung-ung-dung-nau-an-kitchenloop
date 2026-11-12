import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/quantity_parser.dart';
import '../../models/ingredient.dart';
import '../display_helpers.dart';

/// Đọc một ô số: rỗng → `null` hợp lệ; sai định dạng → giữ [previous] và báo lỗi.
({double? value, bool invalid}) _parseNumber(String text, double? previous) {
  if (text.trim().isEmpty) return (value: null, invalid: false);
  final parsed = parseQuantity(text);
  if (parsed == null) return (value: previous, invalid: true);
  return (value: parsed, invalid: false);
}

/// Một dòng nguyên liệu {tên, số lượng, đơn vị, giá, kcal}. Số lượng nhận
/// "2", "0,5", "1/2", "1 1/2". Lỗi hiện ngay tại ô liên quan.
class IngredientRow extends StatefulWidget {
  const IngredientRow({
    super.key,
    required this.ingredient,
    required this.errors,
    required this.onChanged,
    required this.onFieldInvalid,
    required this.onRemove,
    this.dragHandle,
  });

  final Ingredient ingredient;

  /// Mã lỗi của dòng này (ví dụ `name_invalid`, `quantity_negative`).
  final List<String> errors;
  final ValueChanged<Ingredient> onChanged;

  /// Báo một ô số đang nhập sai định dạng (`quantity`, `price`, `kcal`).
  final void Function(String field, bool invalid) onFieldInvalid;
  final VoidCallback onRemove;
  final Widget? dragHandle;

  @override
  State<IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<IngredientRow> {
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _kcal;
  bool _initialized = false;
  final Set<String> _localInvalid = {};

  /// Giá và kcal là tuỳ chọn, ít khi nhập: gập lại để mỗi dòng gọn hơn.
  bool _extraOpen = false;

  /// Mở sẵn ô giá/kcal khi đã có giá trị hoặc đang có lỗi ở hai ô này.
  bool get _showExtra =>
      _extraOpen ||
      _localInvalid.contains('price') ||
      _localInvalid.contains('kcal') ||
      widget.errors.any((e) => e.startsWith('price_') || e.startsWith('kcal_'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final ing = widget.ingredient;
    final lang = context.locale.languageCode;
    // Dòng giữ chỗ: để trống ô tên và hiện gợi ý đã dịch.
    _name = TextEditingController(text: ing.isPlaceholder ? '' : ing.name);
    _quantity = TextEditingController(text: formatQuantity(ing.quantity, languageCode: lang));
    _unit = TextEditingController(text: ing.unit ?? '');
    _price = TextEditingController(text: formatQuantity(ing.price, languageCode: lang));
    _kcal = TextEditingController(text: formatQuantity(ing.kcal, languageCode: lang));
    _extraOpen = ing.price != null || ing.kcal != null;
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _unit.dispose();
    _price.dispose();
    _kcal.dispose();
    super.dispose();
  }

  void _emit() {
    final prev = widget.ingredient;
    final q = _parseNumber(_quantity.text, prev.quantity);
    final p = _parseNumber(_price.text, prev.price);
    final k = _parseNumber(_kcal.text, prev.kcal);
    for (final entry in {'quantity': q.invalid, 'price': p.invalid, 'kcal': k.invalid}.entries) {
      final changed = entry.value ? _localInvalid.add(entry.key) : _localInvalid.remove(entry.key);
      if (changed) widget.onFieldInvalid(entry.key, entry.value);
    }
    final keepPlaceholder = prev.isPlaceholder && _name.text.isEmpty;
    final unit = _unit.text.trim();
    widget.onChanged(prev.copyWith(
      name: keepPlaceholder ? prev.name : _name.text,
      isPlaceholder: keepPlaceholder,
      quantity: q.value,
      unit: unit.isEmpty ? null : _unit.text,
      price: p.value,
      kcal: k.value,
    ));
    setState(() {});
  }

  String? _error(List<String> codes, {String? localField}) {
    if (localField != null && _localInvalid.contains(localField)) {
      return recipeErrorMessage('${localField}_invalid');
    }
    for (final code in codes) {
      if (widget.errors.contains(code)) return recipeErrorMessage(code);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = widget.ingredient.isPlaceholder;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.dragHandle != null) ...[widget.dragHandle!, const SizedBox(width: 8)],
                Expanded(
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'recipes.f_ingredient_name'.tr(),
                      hintText: isPlaceholder && _name.text.isEmpty ? 'recipes.placeholder_ingredient'.tr() : null,
                      errorText: _error(['name_invalid']),
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                IconButton(
                  tooltip: 'common.delete'.tr(),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantity,
                      decoration: InputDecoration(
                        labelText: 'recipes.f_quantity'.tr(),
                        hintText: '1/2',
                        errorText: _error(['quantity_negative', 'quantity_invalid'], localField: 'quantity'),
                        errorMaxLines: 2,
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: InputDecoration(
                        labelText: 'recipes.f_unit'.tr(),
                        errorText: _error(['unit_too_long']),
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                ],
              ),
            ),
            if (!_showExtra)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('show_price_kcal'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => setState(() => _extraOpen = true),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('recipes.add_price_kcal'.tr()),
                ),
              )
            else ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'recipes.f_price'.tr(),
                          errorText: _error(['price_negative', 'price_invalid'], localField: 'price'),
                        ),
                        onChanged: (_) => _emit(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _kcal,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'recipes.f_kcal'.tr(),
                          errorText: _error(['kcal_negative', 'kcal_invalid'], localField: 'kcal'),
                        ),
                        onChanged: (_) => _emit(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
