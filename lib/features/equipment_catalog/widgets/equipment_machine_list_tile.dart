import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';
import '../utils/equipment_spec_sheet.dart';

/// Thẻ 1 model trong danh sách — cùng kiểu thẻ model máy nghiền (ảnh khung
/// trắng, tên model xanh đậm, các ô giá trị màu theo cấu hình catalog).
class EquipmentMachineListTile extends StatelessWidget {
  const EquipmentMachineListTile({
    super.key,
    required this.config,
    required this.machine,
    required this.onTap,
    this.imagePath,
    this.subtitle,
  });

  final EquipmentCatalogConfig config;
  final EquipmentMachine machine;
  final VoidCallback onTap;
  final String? imagePath;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final chips = EquipmentSpecSheet(
      config: config,
      machine: machine,
      series: null,
    ).chips;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('${config.id}_machine_tile_${machine.machineId}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (imagePath case final path?)
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: Image.asset(
                      path,
                      fit: BoxFit.contain,
                      cacheWidth: kIsWeb ? null : 180,
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade800.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    config.icon,
                    size: 20,
                    color: Colors.blue.shade800,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      machine.model,
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final (text, color) in chips)
                            _SpecChip(text: text, color: color),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.blue.shade800),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
