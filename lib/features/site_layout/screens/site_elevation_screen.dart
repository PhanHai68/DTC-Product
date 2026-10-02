import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/site_layout_models.dart';
import '../providers/site_layout_provider.dart';

class SiteElevationScreen extends StatelessWidget {
  const SiteElevationScreen({super.key, required this.machineId});
  final String machineId;

  @override
  Widget build(BuildContext context) {
    final bundle = context.watch<SiteLayoutProvider>().bundle;
    MachinePlacement? machine;
    if (bundle != null) {
      for (final item in bundle.machines) {
        if (item.id == machineId) machine = item;
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mặt đứng thiết bị')),
      body: machine == null || bundle == null
          ? const Center(child: Text('Không tìm thấy thiết bị.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    machine.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Chiều cao máy: ${bundle.project.dimensionUnit.format(machine.heightMm)} · Sàn đến đế: ${bundle.project.dimensionUnit.format(machine.floorToBaseMm)} · Khoảng hở trên: ${bundle.project.dimensionUnit.format(machine.clearanceTopMm)}',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: CustomPaint(
                        painter: _ElevationPainter(
                          machine: machine,
                          unit: bundle.project.dimensionUnit,
                          ceilingMm: bundle.project.ceilingHeightMm,
                          beamMm: bundle.project.lowestBeamHeightMm,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _HeightStatus(machine: machine, project: bundle.project),
                ],
              ),
            ),
    );
  }
}

class _HeightStatus extends StatelessWidget {
  const _HeightStatus({required this.machine, required this.project});
  final MachinePlacement machine;
  final SiteLayoutProject project;

  @override
  Widget build(BuildContext context) {
    final limits = [
      project.ceilingHeightMm,
      project.lowestBeamHeightMm,
    ].whereType<double>().toList();
    if (limits.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.help_outline, color: Colors.orange),
        title: Text('Chưa thể xác minh'),
        subtitle: Text('Chưa nhập chiều cao trần hoặc dầm thấp nhất.'),
      );
    }
    final limit = limits.reduce(math.min);
    final passed = machine.requiredHeightMm <= limit;
    return ListTile(
      leading: Icon(
        passed ? Icons.check_circle : Icons.warning_amber_rounded,
        color: passed ? Colors.green : Colors.red,
      ),
      title: Text(
        passed ? 'Đủ chiều cao lắp đặt' : 'Không đủ chiều cao lắp đặt',
      ),
      subtitle: Text(
        'Yêu cầu ${project.dimensionUnit.format(machine.requiredHeightMm)} · Giới hạn ${project.dimensionUnit.format(limit)}',
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  const _ElevationPainter({
    required this.machine,
    required this.unit,
    this.ceilingMm,
    this.beamMm,
  });
  final MachinePlacement machine;
  final SiteDimensionUnit unit;
  final double? ceilingMm;
  final double? beamMm;

  @override
  void paint(Canvas canvas, Size size) {
    const margin = 36.0;
    final maxHeight = [
      machine.requiredHeightMm,
      ceilingMm ?? 0,
      beamMm ?? 0,
    ].reduce(math.max);
    final scale = (size.height - margin * 2) / math.max(maxHeight, 1);
    final floorY = size.height - margin;
    canvas.drawLine(
      Offset(margin, floorY),
      Offset(size.width - margin, floorY),
      Paint()
        ..color = const Color(0xFF0A2740)
        ..strokeWidth = 2,
    );
    final machineWidth = math.min(size.width * 0.42, 240.0);
    final machineRect = Rect.fromLTWH(
      (size.width - machineWidth) / 2,
      floorY - (machine.floorToBaseMm + machine.heightMm) * scale,
      machineWidth,
      machine.heightMm * scale,
    );
    canvas.drawRect(
      machineRect,
      Paint()..color = const Color(0xFF087F78).withValues(alpha: 0.28),
    );
    canvas.drawRect(
      machineRect,
      Paint()
        ..color = const Color(0xFF087F78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (machine.floorToBaseMm > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          machineRect.left + machineWidth * 0.15,
          floorY - machine.floorToBaseMm * scale,
          machineWidth * 0.7,
          machine.floorToBaseMm * scale,
        ),
        Paint()..color = const Color(0xFF64748B),
      );
    }
    final requiredY = floorY - machine.requiredHeightMm * scale;
    canvas.drawLine(
      Offset(margin, requiredY),
      Offset(size.width - margin, requiredY),
      Paint()
        ..color = Colors.orange
        ..strokeWidth = 1.5,
    );
    _text(
      canvas,
      'Chiều cao yêu cầu ${unit.format(machine.requiredHeightMm)}',
      Offset(margin, requiredY - 20),
      Colors.orange.shade800,
    );
    if (ceilingMm != null) {
      _line(canvas, size, floorY, scale, ceilingMm!, 'Trần', Colors.blue);
    }
    if (beamMm != null) {
      _line(canvas, size, floorY, scale, beamMm!, 'Dầm thấp nhất', Colors.red);
    }
    _text(
      canvas,
      machine.model,
      machineRect.center - const Offset(35, 8),
      const Color(0xFF0A2740),
    );
  }

  void _line(
    Canvas canvas,
    Size size,
    double floorY,
    double scale,
    double value,
    String label,
    Color color,
  ) {
    final y = floorY - value * scale;
    canvas.drawLine(
      Offset(16, y),
      Offset(size.width - 16, y),
      Paint()
        ..color = color
        ..strokeWidth = 2,
    );
    _text(canvas, '$label ${unit.format(value)}', Offset(20, y + 4), color);
  }

  void _text(Canvas canvas, String value, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _ElevationPainter oldDelegate) =>
      oldDelegate.machine != machine ||
      oldDelegate.unit != unit ||
      oldDelegate.ceilingMm != ceilingMm ||
      oldDelegate.beamMm != beamMm;
}
