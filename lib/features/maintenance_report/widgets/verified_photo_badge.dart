import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';

/// "✓ Verified" hoặc "⚠ Image Integrity Failed" — không hiển thị SHA-256 đầy
/// đủ, chỉ cần trạng thái ngắn gọn theo đúng yêu cầu.
class VerifiedPhotoBadge extends StatelessWidget {
  const VerifiedPhotoBadge({super.key, required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final color = verified ? palette.cyan : const Color(0xFFDC2626);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          verified ? 'Đã xác thực' : 'Ảnh lỗi',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
        ),
      ],
    );
  }
}
