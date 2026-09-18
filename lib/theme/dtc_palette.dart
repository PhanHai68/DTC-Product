import 'package:flutter/material.dart';

/// Shared brand color palette, layered on top of the app's central
/// [ThemeData] (see lib/main.dart). Used by screens/widgets that need the
/// DTC brand accent colors (navy/cyan) not covered by [ColorScheme].
abstract final class DtcPalette {
  static const navy = Color(0xFF0A2740);
  static const navyLight = Color(0xFF123D5A);
  static const cyan = Color(0xFF00A6A6);
  static const cyanLight = Color(0xFF37C6B7);
  static const ink = Color(0xFF102F46);
  // 4.69:1 contrast on white was too close to the 4.5:1 WCAG AA floor for
  // small text; darkened slightly for a safer margin.
  static const muted = Color(0xFF4E6472);
  static const canvas = Color(0xFFF3F7F9);
  static const border = Color(0xFFDCE7EB);
}
