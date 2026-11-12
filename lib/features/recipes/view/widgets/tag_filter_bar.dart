import 'package:flutter/material.dart';

import '../../domain/recipe_filter.dart';

/// Hàng thẻ để lọc danh sách: chọn nhiều thẻ (công thức phải có đủ các thẻ đã
/// chọn), mỗi thẻ kèm số công thức. Cuộn ngang khi có nhiều thẻ.
class TagFilterBar extends StatelessWidget {
  const TagFilterBar({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
  });

  final List<TagCount> tags;

  /// Khoá (đã chuẩn hoá) của các thẻ đang chọn.
  final Set<String> selected;

  /// Gọi với khoá của thẻ vừa bấm.
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tag = tags[index];
          return Center(
            child: FilterChip(
              key: Key('tag_chip_${tag.key}'),
              label: Text('${tag.label} (${tag.count})'),
              selected: selected.contains(tag.key),
              onSelected: (_) => onToggle(tag.key),
            ),
          );
        },
      ),
    );
  }
}
