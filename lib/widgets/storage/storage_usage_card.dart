import 'package:flutter/material.dart';

import '../../models/stored_file.dart';
import '../../theme/dtc_palette.dart';

class StorageUsageCard extends StatelessWidget {
  const StorageUsageCard({
    super.key,
    required this.summary,
    required this.onClearCache,
  });

  final StorageUsageSummary summary;
  final VoidCallback onClearCache;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final total = summary.totalBytes == 0 ? 1 : summary.totalBytes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_outline_rounded, color: palette.navy, size: 20),
                const SizedBox(width: 10),
                Text('Dung lượng đã dùng', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatBytes(summary.totalBytes),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: palette.navy,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    _segment(summary.pdfBytes, total, const Color(0xFFE53935)),
                    _segment(summary.imageBytes, total, const Color(0xFF43A047)),
                    _segment(summary.model3dBytes, total, const Color(0xFF1E88E5)),
                    _segment(summary.otherBytes, total, const Color(0xFFFB8C00)),
                    _segment(summary.cacheBytes, total, palette.border),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Legend(color: const Color(0xFFE53935), label: 'PDF', bytes: summary.pdfBytes),
                _Legend(color: const Color(0xFF43A047), label: 'Hình ảnh', bytes: summary.imageBytes),
                _Legend(color: const Color(0xFF1E88E5), label: '3D', bytes: summary.model3dBytes),
                _Legend(color: const Color(0xFFFB8C00), label: 'Khác', bytes: summary.otherBytes),
                _Legend(color: palette.border, label: 'Cache', bytes: summary.cacheBytes),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bộ nhớ đệm: ${formatBytes(summary.cacheBytes)}',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: summary.cacheBytes > 0 ? onClearCache : null,
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                  label: const Text('Xóa bộ nhớ đệm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _segment(int bytes, int total, Color color) {
    final flex = bytes <= 0 ? 0 : bytes;
    if (flex == 0) return const SizedBox.shrink();
    return Expanded(flex: flex, child: Container(color: color));
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.bytes});

  final Color color;
  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label · ${formatBytes(bytes)}', style: const TextStyle(fontSize: 12.5)),
      ],
    );
  }
}
