/// Widget hiển thị một dòng thông số kỹ thuật.
/// Sử dụng trong MachineDetailScreen.
library;

import 'package:flutter/material.dart';

class SpecRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isHighlighted; // Highlight khi so sánh có khác biệt

  const SpecRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: isHighlighted
          ? BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),

          // Label
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          // Value
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider mỏng giữa các nhóm thông số
class SpecDivider extends StatelessWidget {
  const SpecDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

/// Header cho nhóm thông số
class SpecSectionHeader extends StatelessWidget {
  final String title;

  const SpecSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
