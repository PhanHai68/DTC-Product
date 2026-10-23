import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';

/// Huy hiệu chữ "E-V" (English – Việt) dùng làm icon cho từ vựng.
class EnViBadge extends StatelessWidget {
  const EnViBadge({super.key, this.size = 18});

  /// Chiều cao huy hiệu, tương đương cỡ icon đặt cạnh.
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Semantics(
      label: 'Anh – Việt',
      child: ExcludeSemantics(
        // Không đặt `alignment` cho Container: sẽ giãn hết chiều ngang được
        // cấp (VD ô `leading` của ListTile). Center(widthFactor: 1) giữ vừa chữ.
        child: Container(
          height: size,
          padding: EdgeInsets.symmetric(horizontal: size * 0.22),
          decoration: BoxDecoration(
            color: palette.cyan.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(color: palette.cyan, width: 1.2),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              'E-V',
              style: TextStyle(
                color: palette.cyan,
                fontSize: size * 0.56,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
