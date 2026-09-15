// Card hiển thị thông tin tóm tắt một máy cân đóng gói.
// Sử dụng trong màn hình Search và Catalog.

import 'package:flutter/material.dart';

import '../../models/packing_machine.dart';

/// Hai ảnh gốc định lượng có chủ thể sát mép hơn các icon crop từ catalog.
/// Chừa thêm khoảng trắng để kích thước máy nhìn đồng bộ trong danh sách.
bool shouldInsetPackingIcon(String? imagePath) {
  final normalized = imagePath?.replaceAll('\\', '/').toLowerCase() ?? '';
  return normalized.endsWith('/lcj_icon.png') ||
      normalized.endsWith('/lcs_icon.png');
}

class MachineCard extends StatelessWidget {
  final PackingMachine machine;
  final VoidCallback? onTap;
  final VoidCallback? onCompare;
  final bool isSelected; // Đang được chọn so sánh

  const MachineCard({
    super.key,
    required this.machine,
    this.onTap,
    this.onCompare,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hình ảnh ──────────────────────────────────────────────────
              _MachineImage(imagePath: machine.imageMainPath, size: 80),
              const SizedBox(width: 12),

              // ── Thông tin ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Model name
                    Text(
                      machine.model,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Nhóm máy
                    if (machine.productGroup != null)
                      Text(
                        machine.productGroup!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _groupColor(context, machine.productGroup),
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Specs chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (machine.bagMaterial != null)
                          _SpecChip(
                            label: machine.bagMaterial!,
                            icon: Icons.inventory_2_outlined,
                          ),
                        if (machine.bagEdges != null)
                          _SpecChip(label: machine.bagEdges!),
                        _SpecChip(
                          label: machine.weightRangeText,
                          icon: Icons.scale_outlined,
                        ),
                        _SpecChip(
                          label: machine.capacityRangeText,
                          icon: Icons.speed_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Action buttons ─────────────────────────────────────────────
              Column(
                children: [
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: colorScheme.primary,
                  ),
                  if (onCompare != null) ...[
                    const SizedBox(height: 8),
                    IconButton(
                      key: ValueKey('compare_${machine.model}'),
                      tooltip: isSelected
                          ? 'Bỏ khỏi danh sách so sánh'
                          : 'Chọn để so sánh',
                      onPressed: onCompare,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        foregroundColor: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : colorScheme.primaryContainer,
                      ),
                      icon: Icon(
                        isSelected
                            ? Icons.check_rounded
                            : Icons.add_chart_rounded,
                        size: 22,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _groupColor(BuildContext context, String? group) {
    if (group == null) return Theme.of(context).colorScheme.primary;
    if (group.contains('PE')) return Colors.blue.shade700;
    if (group.contains('PP') || group.contains('Bao')) {
      return Colors.green.shade700;
    }
    return Colors.orange.shade700;
  }
}

/// Widget hiển thị hình ảnh máy với fallback placeholder
class _MachineImage extends StatelessWidget {
  final String? imagePath;
  final double size;

  const _MachineImage({this.imagePath, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: imagePath != null && imagePath!.isNotEmpty
            ? Padding(
                padding: EdgeInsets.all(
                  shouldInsetPackingIcon(imagePath) ? size * 0.14 : 0,
                ),
                child: Image.asset(
                  imagePath!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => _placeholder(context),
                ),
              )
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.precision_manufacturing_outlined,
        size: size * 0.45,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Chip nhỏ hiển thị một thông số
class _SpecChip extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _SpecChip({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget export thêm: MachineImage để dùng bên ngoài
class MachineImage extends StatelessWidget {
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;

  const MachineImage({
    super.key,
    this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return Image.asset(
        imagePath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(context),
      );
    }
    return _buildPlaceholder(context);
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxHeight < 96 || constraints.maxWidth < 96;
          final icon = Icon(
            Icons.precision_manufacturing_outlined,
            size: compact ? 32 : 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );

          return Center(
            child: compact
                ? icon
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(height: 8),
                      Text(
                        'Không có hình',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
