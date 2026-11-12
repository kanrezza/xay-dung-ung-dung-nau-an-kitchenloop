import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bộ chỉnh số người ăn: nút − / + và ô nhập số.
///
/// Chỉ nhận số nguyên trong [min]–[max]. Nhập 0, số âm, quá giới hạn hoặc để
/// trống thì bị từ chối: hiện lỗi trong lúc gõ và trả ô về giá trị cũ khi xác
/// nhận hoặc rời khỏi ô. Widget được điều khiển từ bên ngoài qua [value].
class ServingsStepper extends StatefulWidget {
  const ServingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  State<ServingsStepper> createState() => _ServingsStepperState();
}

class _ServingsStepperState extends State<ServingsStepper> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focus.addListener(() {
      if (!_focus.hasFocus) _revert();
    });
  }

  @override
  void didUpdateWidget(ServingsStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != '${widget.value}') {
      _setText('${widget.value}');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Trả ô về giá trị hiện tại và xoá thông báo lỗi.
  void _revert() {
    if (!mounted) return;
    setState(() {
      _invalid = false;
      _setText('${widget.value}');
    });
  }

  void _onTyped(String text) {
    final parsed = int.tryParse(text);
    final valid = parsed != null && parsed >= widget.min && parsed <= widget.max;
    setState(() => _invalid = !valid && text.trim().isNotEmpty);
    if (valid && parsed != widget.value) widget.onChanged(parsed);
  }

  /// Bấm +/−: luôn tính từ giá trị hiện tại, không phải từ chữ đang gõ dở.
  void _step(int delta) {
    final next = widget.value + delta;
    if (next < widget.min || next > widget.max) return;
    setState(() => _invalid = false);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              key: const Key('servings_minus'),
              icon: const Icon(Icons.remove),
              onPressed: widget.value > widget.min ? () => _step(-1) : null,
            ),
            SizedBox(
              width: 72,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9-]'))],
                style: Theme.of(context).textTheme.titleLarge,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  enabledBorder: _invalid
                      ? OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.error))
                      : null,
                ),
                onChanged: _onTyped,
                onSubmitted: (_) => _revert(),
              ),
            ),
            IconButton.filledTonal(
              key: const Key('servings_plus'),
              icon: const Icon(Icons.add),
              onPressed: widget.value < widget.max ? () => _step(1) : null,
            ),
          ],
        ),
        if (_invalid)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'recipes.err_servings_invalid'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
