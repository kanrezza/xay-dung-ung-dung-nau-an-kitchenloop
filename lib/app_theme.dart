import 'package:flutter/material.dart';

/// Giao diện chung của ứng dụng. Tách riêng để `main.dart` và bộ chụp ảnh giao
/// diện (thư mục `screenshots/`) dùng đúng cùng một theme.
///
/// Material 3 bỏ qua `primarySwatch`, nên phải dựng bảng màu từ một màu gốc.
ThemeData buildAppTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.orange,
        // "fidelity": giữ màu chính sát màu cam gốc (mặc định ra cam đất ngả nâu).
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      ),
      useMaterial3: true,
    );
