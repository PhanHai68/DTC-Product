import 'package:flutter/material.dart';

/// Bộ màu thương hiệu DTC cho từng chế độ sáng/tối. Dùng qua [DtcPalette.of]
/// để luôn lấy đúng bộ màu theo [Brightness] hiện tại thay vì hằng số cố định.
class DtcPaletteData {
  const DtcPaletteData({
    required this.navy,
    required this.navyLight,
    required this.cyan,
    required this.cyanLight,
    required this.ink,
    required this.muted,
    required this.canvas,
    required this.border,
    required this.surface,
  });

  /// Màu chữ/icon nhấn mạnh chính (tiêu đề, icon nổi bật).
  final Color navy;

  /// Biến thể nhạt hơn của [navy], dùng cho icon phụ.
  final Color navyLight;

  /// Màu nhấn thương hiệu (accent bar, viền nổi bật khi chọn/nổi bật).
  final Color cyan;
  final Color cyanLight;

  /// Màu chữ nội dung chính, tương phản cao trên [surface]/[canvas].
  final Color ink;

  /// Màu chữ phụ/mô tả, tương phản thấp hơn [ink].
  final Color muted;

  /// Nền toàn màn hình (tương đương scaffoldBackgroundColor).
  final Color canvas;

  /// Viền mặc định cho card/ô nhập liệu.
  final Color border;

  /// Nền "thẻ" (card, ô tròn icon...) — trắng ở chế độ sáng, xám đậm ở tối.
  final Color surface;
}

/// Bộ màu thương hiệu DTC, lớp trên [ThemeData] trung tâm (xem lib/main.dart).
/// Luôn lấy màu qua `DtcPalette.of(context)` để tự đổi theo chế độ sáng/tối —
/// không dùng hằng số tĩnh vì sẽ không đổi màu khi bật giao diện tối.
abstract final class DtcPalette {
  static const _light = DtcPaletteData(
    navy: Color(0xFF0A2740),
    navyLight: Color(0xFF123D5A),
    cyan: Color(0xFF00A6A6),
    cyanLight: Color(0xFF37C6B7),
    ink: Color(0xFF102F46),
    muted: Color(0xFF4E6472),
    canvas: Color(0xFFF3F7F9),
    border: Color(0xFFDCE7EB),
    surface: Colors.white,
  );

  static const _dark = DtcPaletteData(
    navy: Color(0xFFEAF2F6),
    navyLight: Color(0xFFCBD9E0),
    cyan: Color(0xFF4FD1C7),
    cyanLight: Color(0xFF6FE0D6),
    ink: Color(0xFFECF3F6),
    muted: Color(0xFFA9B8C0),
    canvas: Color(0xFF0D1418),
    border: Color(0xFF2B3B43),
    surface: Color(0xFF162229),
  );

  static DtcPaletteData of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}
