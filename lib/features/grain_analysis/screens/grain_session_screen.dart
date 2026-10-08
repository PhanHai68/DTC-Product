import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../engine/geometry.dart';
import '../engine/image_quality.dart';
import '../engine/result_calculator.dart';
import '../models/analysis_session.dart';
import '../models/grain.dart';
import '../providers/grain_analysis_provider.dart';
import '../utils/grain_format.dart';
import '../widgets/grain_image_viewer.dart';

enum _EditMode { view, add, remove }

/// Kết quả một phiên: ảnh đánh dấu từng hạt, sửa tay số đếm (FR-07),
/// bảng tỉ lệ (đếm nhanh), xác nhận và lưu phiên (FR-08).
class GrainSessionScreen extends StatefulWidget {
  const GrainSessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<GrainSessionScreen> createState() => _GrainSessionScreenState();
}

class _GrainSessionScreenState extends State<GrainSessionScreen> {
  late final GrainAnalysisProvider _provider;
  AnalysisSession? _session;
  final _paths = <String, String?>{};
  bool _loading = true;
  int _imageIndex = 0;
  _EditMode _mode = _EditMode.view;
  bool _busy = false;

  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _provider = context.read<GrainAnalysisProvider>();
    _load();
  }

  Future<void> _load() async {
    final s = await _provider.loadSession(widget.sessionId);
    if (s != null) {
      for (final f in s.imagePaths) {
        _paths[f] = await _provider.photoService.pathOf(f);
      }
    }
    if (!mounted) return;
    setState(() {
      _session = s;
      _loading = false;
    });
  }

  bool get _editable => _session?.status == SessionStatus.draft;

  Future<void> _apply({
    List<Grain> upserted = const [],
    List<String> deletedIds = const [],
  }) async {
    final s = _session;
    if (s == null || _busy) return;
    setState(() => _busy = true);
    try {
      final next = await _provider.applyEdits(
        s,
        upserted: upserted,
        deletedIds: deletedIds,
      );
      if (mounted) setState(() => _session = next);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hạt dưới điểm chạm (tọa độ khung đã nắn), ưu tiên hạt chứa điểm.
  Grain? _hit(Offset p, List<Grain> grains, double medianArea) {
    final tolerance = math.max(6.0, math.sqrt(medianArea / math.pi));
    Grain? nearest;
    var best = double.infinity;
    for (final g in grains) {
      if (pointInPolygon(p.dx, p.dy, g.contour)) return g;
      final d = (Offset(g.centroidX, g.centroidY) - p).distance;
      if (d < best) {
        best = d;
        nearest = g;
      }
    }
    return best <= tolerance ? nearest : null;
  }

  Future<void> _onTap(Offset p) async {
    final s = _session!;
    final image = s.images[_imageIndex];
    final grains = s.grainsOf(_imageIndex);
    if (p.dx < 0 ||
        p.dy < 0 ||
        p.dx > image.frameWidth ||
        p.dy > image.frameHeight) {
      return;
    }
    switch (_mode) {
      case _EditMode.add:
        await _apply(upserted: [_manualGrain(s, p)]);
      case _EditMode.remove:
        final g = _hit(p, grains, image.medianAreaPx);
        if (g == null) return;
        if (g.source == GrainSource.manual) {
          await _apply(deletedIds: [g.id]);
        } else {
          await _apply(upserted: [g.copyWith(removed: !g.removed)]);
        }
      case _EditMode.view:
        final g = _hit(p, grains, image.medianAreaPx);
        if (g != null && g.isCluster && !g.removed) await _editCluster(g);
    }
  }

  /// Hạt bị sót do người dùng chạm thêm: hình tròn cỡ hạt trung vị.
  Grain _manualGrain(AnalysisSession s, Offset p) {
    final image = s.images[_imageIndex];
    var next = 1;
    final prefix = 'i$_imageIndex-m';
    for (final g in s.grains) {
      if (g.id.startsWith(prefix)) {
        next = math.max(
          next,
          (int.tryParse(g.id.substring(prefix.length)) ?? 0) + 1,
        );
      }
    }
    final area = image.medianAreaPx > 0 ? image.medianAreaPx : 100.0;
    final r = math.sqrt(area / math.pi);
    final ppm = image.pixelsPerMm;
    return Grain(
      id: '$prefix$next',
      imageIndex: _imageIndex,
      contour: [
        for (var k = 0; k < 12; k++) ...[
          p.dx + r * math.cos(2 * math.pi * k / 12),
          p.dy + r * math.sin(2 * math.pi * k / 12),
        ],
      ],
      centroidX: p.dx,
      centroidY: p.dy,
      areaPx: area,
      areaMm2: ppm == null ? null : area / (ppm * ppm),
      source: GrainSource.manual,
    );
  }

  Future<void> _editCluster(Grain g) async {
    var value = g.estimatedCount;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Số hạt trong cụm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'App ước số hạt theo diện tích cụm. Đếm lại trên ảnh rồi sửa '
                'nếu cần.',
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: value > 1 ? () => setLocal(() => value--) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '$value',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => setLocal(() => value++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, value),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (result != null && result != g.estimatedCount) {
      await _apply(upserted: [g.copyWith(estimatedCount: result)]);
    }
  }

  Future<void> _confirm() async {
    final s = _session;
    if (s == null) return;
    setState(() => _busy = true);
    final next = await _provider.confirm(s);
    if (!mounted) return;
    setState(() {
      _session = next;
      _busy = false;
      _mode = _EditMode.view;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xác nhận và lưu phiên.')));
  }

  Future<void> _delete() async {
    final s = _session;
    if (s == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa phiên phân tích?'),
        content: const Text('Ảnh và kết quả của phiên sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _provider.deleteSession(s);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (_loading || s == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kết quả phân tích')),
        body: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Không tìm thấy phiên phân tích.'),
        ),
      );
    }
    final palette = DtcPalette.of(context);
    final image = s.images[_imageIndex];
    final path = _paths[image.fileName];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.mode.label),
        actions: [
          IconButton(
            key: const Key('grain_session_delete'),
            tooltip: 'Xóa phiên',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
      body: Column(
        children: [
          if (s.images.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Cả mẫu')),
                  ButtonSegment(value: 1, label: Text('Nhóm đã tách')),
                ],
                selected: {_imageIndex},
                onSelectionChanged: (v) =>
                    setState(() => _imageIndex = v.first),
              ),
            ),
          if (_editable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<_EditMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _EditMode.view,
                    icon: Icon(Icons.zoom_in_rounded),
                    label: Text('Xem'),
                  ),
                  ButtonSegment(
                    value: _EditMode.add,
                    icon: Icon(Icons.add_circle_outline_rounded),
                    label: Text('Thêm hạt'),
                  ),
                  ButtonSegment(
                    value: _EditMode.remove,
                    icon: Icon(Icons.remove_circle_outline_rounded),
                    label: Text('Xóa hạt'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: Text(switch (_mode) {
              _EditMode.view when _editable =>
                'Phóng to bằng hai ngón. Chạm vào cụm (vòng cam có số) để '
                    'sửa số hạt.',
              _EditMode.view => 'Phóng to bằng hai ngón để xem từng hạt.',
              _EditMode.add => 'Chạm vào hạt bị sót để thêm.',
              _EditMode.remove =>
                'Chạm vào vật thể không phải hạt để xóa; chạm lại để khôi '
                    'phục.',
            }, style: TextStyle(color: palette.muted, fontSize: 12.5)),
          ),
          Expanded(
            flex: 5,
            child: ColoredBox(
              color: Colors.black,
              child: path == null
                  ? const Center(
                      child: Text(
                        'Không tìm thấy file ảnh gốc.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : GrainImageViewer(
                      imagePath: path,
                      image: image,
                      grains: s.grainsOf(_imageIndex),
                      onTapImage: _editable && !_busy ? _onTap : null,
                    ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GrainLegend(),
          ),
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _ResultCard(session: s),
                const SizedBox(height: 10),
                _InfoCard(session: s, date: _date.format(s.createdAt)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: _editable
                    ? FilledButton.icon(
                        key: const Key('grain_session_confirm'),
                        onPressed: _busy ? null : _confirm,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: const Text('Xác nhận & lưu phiên'),
                      )
                    : OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.verified_outlined),
                        label: Text('Đã xác nhận ${_date.format(s.updatedAt)}'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.session});

  final AnalysisSession session;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final s = session;
    final big = TextStyle(
      color: palette.navy,
      fontSize: 26,
      fontWeight: FontWeight.w900,
    );
    final label = TextStyle(color: palette.muted, fontSize: 12.5);
    final children = <Widget>[];
    if (s.mode == AnalysisMode.quick) {
      final group = s.resultOf(ClassResult.groupId);
      final rest = s.resultOf(ClassResult.restId);
      if (group != null && rest != null) {
        final count = GrainResultCalculator.roundForDisplay([
          group.countPercent,
          rest.countPercent,
        ]);
        final area = GrainResultCalculator.roundForDisplay([
          group.areaPercent,
          rest.areaPercent,
        ]);
        final areaInMm =
            s.images.length > 1 &&
            s.images[0].pixelsPerMm != null &&
            s.images[1].pixelsPerMm != null;
        children.addAll([
          Text(
            '${GrainFormat.percent(count[0])} số hạt',
            key: const Key('grain_result_count_percent'),
            style: big,
          ),
          Text(
            '${GrainFormat.count(group.grainCount)} hạt nhóm / '
            '${GrainFormat.count(group.grainCount + rest.grainCount)} hạt cả mẫu',
            style: label,
          ),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.2),
              2: FlexColumnWidth(1.4),
              3: FlexColumnWidth(1.6),
            },
            children: [
              _row(context, [
                'Nhóm',
                'Số hạt',
                '% số hạt',
                '% diện tích',
              ], header: true),
              _row(context, [
                'Nhóm đã tách',
                GrainFormat.count(group.grainCount),
                GrainFormat.percent(count[0]),
                GrainFormat.percent(area[0]),
              ]),
              _row(context, [
                'Phần còn lại',
                GrainFormat.count(rest.grainCount),
                GrainFormat.percent(count[1]),
                GrainFormat.percent(area[1]),
              ]),
            ],
          ),
          if (!areaInMm)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '% diện tích so theo pixel vì có ảnh không nhận ra khay — '
                'chỉ đúng khi hai ảnh chụp cùng khoảng cách.',
                style: label,
              ),
            ),
          if (rest.grainCount < 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Số hạt nhóm lớn hơn cả mẫu — kiểm tra lại hai ảnh.',
                style: TextStyle(color: Color(0xFFC0392B)),
              ),
            ),
        ]);
      }
    } else {
      final all = s.resultOf(ClassResult.allId);
      final grains = s.grainsOf(0);
      final clusters = grains.where((g) => g.isCluster && !g.removed).length;
      final manual = grains.where((g) => g.source == GrainSource.manual).length;
      final removed = grains.where((g) => g.removed).length;
      children.addAll([
        Text(
          '${GrainFormat.count(all?.grainCount ?? 0)} hạt',
          key: const Key('grain_result_total'),
          style: big,
        ),
        Text(
          [
            if (clusters > 0) '$clusters cụm ước lượng',
            if (manual > 0) '$manual hạt thêm tay',
            if (removed > 0) '$removed vật thể đã xóa',
          ].join(' · ').ifEmpty('Đếm tự động, chưa sửa tay'),
          style: label,
        ),
      ]);
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  TableRow _row(
    BuildContext context,
    List<String> cells, {
    bool header = false,
  }) {
    final palette = DtcPalette.of(context);
    return TableRow(
      children: [
        for (var i = 0; i < cells.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              cells[i],
              textAlign: i == 0 ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                color: header ? palette.muted : palette.ink,
                fontWeight: header ? FontWeight.w700 : FontWeight.w600,
                fontSize: header ? 12 : 13.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.session, required this.date});

  final AnalysisSession session;
  final String date;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final s = session;
    final rows = <(String, String)>[
      ('Trạng thái', s.status.label),
      if (s.lotCode != null) ('Số lô', s.lotCode!),
      ('Loại mẫu', s.sampleType.label),
      if (s.sampleWeightG != null)
        ('Khối lượng mẫu', '${GrainFormat.decimal(s.sampleWeightG!)} g'),
      if (s.createdBy.isNotEmpty) ('Người thực hiện', s.createdBy),
      ('Thời gian', date),
      ('Khay chuẩn', s.trayId.toUpperCase()),
      ('Phiên bản thuật toán', s.algorithmVersion),
      if (s.note != null) ('Ghi chú', s.note!),
    ];
    final warnings = <String>[];
    for (var i = 0; i < s.images.length; i++) {
      final img = s.images[i];
      final prefix = s.images.length > 1 ? 'Ảnh ${i + 1}: ' : '';
      if (img.pixelsPerMm == null) {
        warnings.add('${prefix}không nhận ra khay — không có số đo mm.');
      } else {
        rows.add((
          '$prefixĐộ phân giải',
          '${GrainFormat.decimal(img.pixelsPerMm!)} px/mm',
        ));
      }
      if (img.issues.isNotEmpty) {
        final labels = [
          for (final n in img.issues) QualityIssue.byName(n)?.label ?? n,
        ];
        warnings.add('$prefixảnh kém, đã bỏ qua: ${labels.join(', ')}.');
      }
      if (img.ignoredRegionCount > 0) {
        warnings.add(
          '$prefix${img.ignoredRegionCount} vùng lớn bất thường (bóng đổ, mép '
          'giấy, đống hạt) không được tính.',
        );
      }
      if (img.edgeCutCount > 0) {
        warnings.add(
          '$prefix${img.edgeCutCount} vật thể chạm mép vùng phân tích không '
          'được tính.',
        );
      }
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Color(0xFFB9770E),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(w, style: TextStyle(color: palette.ink)),
                    ),
                  ],
                ),
              ),
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(k, style: TextStyle(color: palette.muted)),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        style: TextStyle(
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
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

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
