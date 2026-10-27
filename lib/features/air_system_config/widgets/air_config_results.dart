import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diagram/air_diagram_render.dart';
import '../l10n/air_strings.dart';
import '../models/air_result.dart';
import '../providers/air_config_editor_controller.dart';
import 'air_diagram_view.dart';

/// Tab "Kết quả": cảnh báo (lỗi trên cùng), ô thông số tổng, sơ đồ lắp đặt
/// (vừa khít chiều ngang, bấm để xem toàn màn hình).
class AirConfigResults extends StatelessWidget {
  const AirConfigResults({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AirConfigEditorController>();
    final s = ctrl.strings;
    final r = ctrl.result;
    return ListView(
      key: const PageStorageKey('air_config_results'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        _Warnings(result: r, strings: s),
        _SummaryCards(result: r, strings: s),
        const SizedBox(height: 12),
        _ElectricalCard(result: r, strings: s),
        _DiagramCard(ctrl: ctrl),
      ],
    );
  }
}

/// Sơ đồ thu nhỏ vừa khung; bấm mở [AirDiagramView] toàn màn hình (cuộn,
/// phóng to được).
/// MCCB, cáp máy nén, MCB và cáp máy sấy theo model máy nén — cùng bảng với
/// màn "Chọn MCCB và dây điện".
class _ElectricalCard extends StatelessWidget {
  const _ElectricalCard({required this.result, required this.strings});
  final AirResult result;
  final AirStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = strings.electricalRows(result);
    return Card(
      key: const Key('air_electrical_card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.electrical_services_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  strings.electricalTitle,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              Text(
                strings.electricalMissing,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(label)),
                    const SizedBox(width: 12),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC2410C),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiagramCard extends StatefulWidget {
  const _DiagramCard({required this.ctrl});
  final AirConfigEditorController ctrl;

  @override
  State<_DiagramCard> createState() => _DiagramCardState();
}

class _DiagramCardState extends State<_DiagramCard> {
  @override
  void initState() {
    super.initState();
    // Ảnh thiết bị nạp lần đầu; xong thì vẽ lại (trước đó là ô xám tạm).
    if (!AirDiagramImages.isLoaded) {
      AirDiagramImages.load().then((_) {
        if (mounted) setState(() {});
      }, onError: (_) {});
    }
  }

  void _open() {
    final ctrl = widget.ctrl;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: ctrl,
          child: Scaffold(
            appBar: AppBar(title: Text(ctrl.strings.tabDiagram)),
            body: const AirDiagramView(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.strings;
    final diagram = widget.ctrl.diagram;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.tabDiagram,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  key: const Key('air_diagram_fullscreen'),
                  tooltip: s.diagramFullScreen,
                  onPressed: _open,
                  icon: const Icon(Icons.fullscreen_rounded),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _open,
            child: ColoredBox(
              color: const Color(0xFFF1F5F9),
              child: AspectRatio(
                aspectRatio: diagram.width / diagram.height,
                child: FittedBox(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const Key('air_diagram_canvas'),
                      size: Size(diagram.width, diagram.height),
                      painter: AirDiagramPainter(diagram),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.result, required this.strings});
  final AirResult result;
  final AirStrings strings;

  @override
  Widget build(BuildContext context) {
    if (result.warnings.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.tableWarnings,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (final w in result.warnings)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _bg(w.level),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(w.level), size: 18, color: _fg(w.level)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${strings.level(w.level)}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _fg(w.level),
                              ),
                            ),
                            TextSpan(text: strings.warning(w)),
                          ],
                        ),
                        style: const TextStyle(color: Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _icon(WarningLevel l) => switch (l) {
    WarningLevel.error => Icons.error_outline,
    WarningLevel.caution => Icons.warning_amber_rounded,
    WarningLevel.note => Icons.info_outline,
  };
  static Color _fg(WarningLevel l) => switch (l) {
    WarningLevel.error => const Color(0xFFB91C1C),
    WarningLevel.caution => const Color(0xFFB45309),
    WarningLevel.note => const Color(0xFF475569),
  };
  static Color _bg(WarningLevel l) => switch (l) {
    WarningLevel.error => const Color(0xFFFEE2E2),
    WarningLevel.caution => const Color(0xFFFEF3C7),
    WarningLevel.note => const Color(0xFFF1F5F9),
  };
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.result, required this.strings});
  final AirResult result;
  final AirStrings strings;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final s = strings;
    final (powerLabel, powerValue, powerSub) = s.powerCard(r);
    final (dryerValue, dryerSub) = s.dryerCard(r);
    final (filterValue, filterSub) = s.lineFilterCard(r);
    final cards = [
      _Card(
        icon: Icons.bolt_rounded,
        label: powerLabel,
        value: powerValue,
        sub: s.compressorCardSub(r),
      ),
      _Card(
        icon: Icons.propane_tank_outlined,
        label: s.cardTank,
        value: s.tankCard(r.tank),
        sub: s.tankCardSub(r.tank),
      ),
      _Card(
        icon: Icons.ac_unit_rounded,
        label: s.cardDryer,
        value: dryerValue,
        sub: dryerSub,
      ),
      _Card(
        icon: Icons.filter_alt_outlined,
        label: s.cardLineFilter,
        value: filterValue,
        sub: filterSub,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 300
            ? 2
            : 1;
        // Các ô cùng hàng cao bằng nhau.
        return Column(
          children: [
            for (var i = 0; i < cards.length; i += columns)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var k = i; k < i + columns; k++) ...[
                        if (k > i) const SizedBox(width: 10),
                        Expanded(
                          child: k < cards.length
                              ? cards[k]
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
