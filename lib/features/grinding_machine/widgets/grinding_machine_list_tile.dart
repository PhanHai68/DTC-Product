import 'package:flutter/material.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../utils/grinding_format.dart';

/// Hàng hiển thị 1 model trong danh sách (Series list / Search) — chỉ hiện
/// các thông số CÓ dữ liệu, không hiển thị placeholder rỗng.
class GrindingMachineListTile extends StatelessWidget {
  const GrindingMachineListTile({
    super.key,
    required this.machine,
    required this.onTap,
    this.subtitle,
  });

  final GrindingMachine machine;
  final VoidCallback onTap;

  /// Dòng phụ tuỳ chỉnh (VD tên dòng máy khi hiển thị trong kết quả tìm
  /// kiếm gộp nhiều series) — mặc định null thì tự ẩn.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final chips = [
      GrindingFormat.capacityRange(machine),
      GrindingFormat.finenessRange(machine),
    ].whereType<String>().toList();

    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grinding_machine_tile_${machine.machineId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.model,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: chips
                            .map((c) => _SpecChip(text: c))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.cyan),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.cyan.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: palette.navy,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
