import 'package:flutter/material.dart';

/// Giao diện chung của ứng dụng (sáng và tối). Tách riêng để `main.dart` và bộ chụp ảnh giao
/// diện (thư mục `screenshots/`) dùng đúng cùng một theme.
///
/// Material 3 bỏ qua `primarySwatch`, nên bảng màu được dựng từ một màu gốc cam.
ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.orange,
    brightness: brightness,
    // "fidelity": giữ màu chính sát màu cam gốc (mặc định ra cam đất ngả nâu).
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  // Kiểu chữ dựng từ bộ chữ chuẩn của theme (giữ đúng font của nền tảng).
  final text = ThemeData(colorScheme: scheme, useMaterial3: true).textTheme;
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: rounded,
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: scheme.onSurface)),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(shape: rounded),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
  );
}
