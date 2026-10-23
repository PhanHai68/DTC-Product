import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../models/technical_term.dart';

/// Biểu tượng nhỏ cho trạng thái học: đang học / đã thuộc.
class TermStatusIcon extends StatelessWidget {
  const TermStatusIcon({super.key, required this.status});

  final TermStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final learned = status == TermStatus.learned;
    return Tooltip(
      message: status.label,
      child: Icon(
        learned ? Icons.check_circle_rounded : Icons.school_outlined,
        size: 20,
        color: learned ? Colors.green.shade600 : palette.cyan,
        semanticLabel: status.label,
      ),
    );
  }
}
