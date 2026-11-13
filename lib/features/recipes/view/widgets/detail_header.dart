import 'package:flutter/material.dart';

/// Nút tròn nền mờ trên ảnh bìa (dễ thấy trên cả ảnh sáng lẫn tối).
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IconButton.filled(
        style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35), foregroundColor: Colors.white),
        tooltip: tooltip,
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class CircleBack extends StatelessWidget {
  const CircleBack({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.35), foregroundColor: Colors.white),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const BackButtonIcon(),
      onPressed: () => Navigator.maybePop(context),
    );
  }
}

/// Nhãn thông tin nhanh (thời gian, số nguyên liệu, thẻ...).
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
