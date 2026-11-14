import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Ảnh của công thức/bước nấu, có lưu cache trên đĩa nên xem lại được khi mất
/// mạng. Có vòng quay khi đang tải và biểu tượng thay thế khi tải lỗi (ví dụ
/// offline mà ảnh chưa từng được tải) — không bao giờ ném lỗi ra giao diện.
class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
    this.fallback,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  /// Hiện khi không có ảnh hoặc tải lỗi. Mặc định: biểu tượng món ăn (không có
  /// ảnh) hoặc ảnh hỏng (tải lỗi).
  final Widget? fallback;

  /// Chiều cao của khung chờ/lỗi khi [height] không được cho.
  static const double _defaultHeight = 100;

  Widget _box(BuildContext context, Widget child) {
    return Container(
      width: width,
      height: height ?? _defaultHeight,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget content = url.isEmpty
        ? (fallback ?? _box(context, Icon(Icons.restaurant_menu, color: scheme.onSurfaceVariant)))
        : LayoutBuilder(
            // Giải mã ảnh đúng cỡ hiển thị (× mật độ điểm ảnh) thay vì ảnh gốc tới 1600 px:
            // đỡ tốn bộ nhớ và đỡ giật khi cuộn danh sách nhiều ảnh.
            builder: (context, constraints) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              final w = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null);
              return CachedNetworkImage(
                imageUrl: url,
                width: width,
                height: height,
                fit: fit,
                memCacheWidth: w == null || !w.isFinite ? null : (w * dpr).round(),
                placeholder: (context, _) => _box(
                  context,
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, _, __) =>
                    fallback ?? _box(context, Icon(Icons.broken_image_outlined, size: 40, color: scheme.onSurfaceVariant)),
              );
            },
          );
    return ClipRRect(borderRadius: BorderRadius.circular(borderRadius), child: content);
  }
}
