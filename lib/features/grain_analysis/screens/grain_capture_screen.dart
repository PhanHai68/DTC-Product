import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/input/localized_number.dart';
import '../../../theme/dtc_palette.dart';
import '../engine/grain_analyzer.dart';
import '../engine/image_quality.dart';
import '../engine/tray_layout.dart';
import '../models/analysis_session.dart';
import '../providers/grain_analysis_provider.dart';
import '../utils/grain_format.dart';

/// Tạo phiên mới: nhập thông tin mẫu, chụp ảnh, kiểm tra chất lượng, phân
/// tích. Đếm hạt cần 1 ảnh; đếm nhanh (luồng C) cần 2 ảnh.
class GrainCaptureScreen extends StatefulWidget {
  const GrainCaptureScreen({super.key, required this.mode});

  final AnalysisMode mode;

  @override
  State<GrainCaptureScreen> createState() => _GrainCaptureScreenState();
}

class _Slot {
  _Slot(this.title, this.hint);

  final String title;
  final String hint;
  String? fileName;
  String? path;
  GrainImageAnalysis? analysis;
  bool accepted = false;
  double? progress;
  String? stage;
  String? error;

  bool get busy => progress != null;

  void reset() {
    fileName = null;
    path = null;
    analysis = null;
    accepted = false;
    progress = null;
    stage = null;
    error = null;
  }
}

class _GrainCaptureScreenState extends State<GrainCaptureScreen> {
  late final GrainAnalysisProvider _provider;
  late final String _sessionId;
  late final List<_Slot> _slots;
  final _lot = TextEditingController();
  final _weight = TextEditingController();
  final _note = TextEditingController();
  final _operator = TextEditingController();
  SampleType _sampleType = SampleType.other;
  late TrayLayout _tray;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<GrainAnalysisProvider>();
    _sessionId = _provider.newSessionId();
    _tray = _provider.tray;
    _operator.text = _provider.operatorName;
    _slots = widget.mode == AnalysisMode.quick
        ? [
            _Slot(
              'Ảnh 1 — cả mẫu',
              'Rải toàn bộ mẫu một lớp trên khay rồi chụp.',
            ),
            _Slot(
              'Ảnh 2 — nhóm hạt đã tách',
              'Nhặt riêng nhóm hạt cần tính, rải lên khay rồi chụp.',
            ),
          ]
        : [
            _Slot(
              'Ảnh mẫu',
              'Rải mẫu một lớp trong khung nét đứt của khay chuẩn rồi chụp '
                  'thẳng từ trên xuống.',
            ),
          ];
  }

  @override
  void dispose() {
    _lot.dispose();
    _weight.dispose();
    _note.dispose();
    _operator.dispose();
    super.dispose();
  }

  bool get _hasImages => _slots.any((s) => s.fileName != null);
  bool get _ready => _slots.every((s) => s.accepted && !s.busy);

  Future<void> _capture(int index, ImageSource source) async {
    final slot = _slots[index];
    final messenger = ScaffoldMessenger.of(context);
    final old = slot.fileName;
    String? fileName;
    try {
      fileName = await _provider.photoService.pick(
        source: source,
        sessionId: _sessionId,
        imageIndex: index,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không lấy được ảnh: $error')),
      );
      return;
    }
    if (fileName == null || !mounted) return;
    if (old != null && old != fileName) await _provider.discardImages([old]);
    final path = await _provider.photoService.pathOf(fileName);
    setState(() {
      slot
        ..reset()
        ..fileName = fileName
        ..path = path
        ..progress = 0
        ..stage = 'Đọc ảnh';
    });
    try {
      final result = await _provider.runner.analyzeFile(
        path!,
        layout: _tray,
        imageIndex: index,
        onProgress: (f, stage) {
          if (mounted) {
            setState(() {
              slot
                ..progress = f
                ..stage = stage;
            });
          }
        },
      );
      if (!mounted) return;
      final detected = TrayLayout.all
          .where((t) => t.id == result.trayId && t.id != _tray.id)
          .firstOrNull;
      setState(() {
        slot
          ..analysis = result
          ..progress = null;
        if (detected != null) _tray = detected;
      });
      if (detected != null) {
        messenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(
              'Ảnh không có mốc tấm nền in — app nhận ra khay '
              '${detected.name} và phân tích theo khay này.',
            ),
          ),
        );
      }
      if (result.issues.isEmpty) {
        setState(() => slot.accepted = true);
      } else {
        await _askQuality(index);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        slot
          ..progress = null
          ..error = '$error'.replaceFirst('FormatException: ', '');
      });
    }
  }

  /// Ảnh không đạt: nêu lý do, cho chụp lại hoặc "vẫn tiếp tục" (FR-03).
  Future<void> _askQuality(int index) async {
    final slot = _slots[index];
    final issues = slot.analysis!.issues;
    final retake = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFC0392B)),
        title: const Text('Ảnh chưa đạt chất lượng'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final issue in issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${issue.label}: ',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        TextSpan(text: issue.message),
                      ],
                    ),
                  ),
                ),
              if (issues.contains(QualityIssue.markers))
                const Text(
                  'Nếu tiếp tục khi không nhận ra khay: vẫn đếm được, nhưng '
                  'không có số đo mm.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('grain_quality_continue'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vẫn tiếp tục'),
          ),
          FilledButton(
            key: const Key('grain_quality_retake'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Chụp lại'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retake ?? true) {
      final file = slot.fileName;
      setState(slot.reset);
      if (file != null) await _provider.discardImages([file]);
    } else {
      setState(() => slot.accepted = true);
    }
  }

  Future<void> _submit() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    try {
      await _provider.savePreferences(
        operatorName: _operator.text.trim(),
        tray: _tray,
      );
      final session = await _provider.createSession(
        id: _sessionId,
        mode: widget.mode,
        sampleType: _sampleType,
        lotCode: _lot.text.trim().isEmpty ? null : _lot.text.trim(),
        sampleWeightG: parseLocalizedDouble(_weight.text),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        tray: _tray,
        images: [
          for (final s in _slots)
            (fileName: s.fileName!, analysis: s.analysis!),
        ],
      );
      if (!mounted) return;
      context.pushReplacement('/grain-analysis/session/${session.id}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được phiên: $error')));
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_hasImages || _saving) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ phiên này?'),
        content: const Text('Ảnh đã chụp sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ phiên'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await _provider.discardImages([
        for (final s in _slots)
          if (s.fileName != null) s.fileName!,
      ]);
    }
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return PopScope(
      canPop: !_hasImages || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = GoRouter.of(context);
        if (await _confirmLeave() && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.mode.label)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _section(
              context,
              'Thông tin mẫu',
              Column(
                children: [
                  TextField(
                    key: const Key('grain_lot_code'),
                    controller: _lot,
                    decoration: const InputDecoration(labelText: 'Số lô'),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<SampleType>(
                    initialValue: _sampleType,
                    decoration: const InputDecoration(labelText: 'Loại mẫu'),
                    items: [
                      for (final t in SampleType.values)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (v) => setState(() => _sampleType = v!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('grain_sample_weight'),
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Khối lượng mẫu đã cân (g)',
                      helperText: 'Không bắt buộc ở bước đếm hạt',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('grain_operator'),
                    controller: _operator,
                    decoration: const InputDecoration(
                      labelText: 'Người thực hiện',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _note,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _tray.id,
                    decoration: InputDecoration(
                      labelText: 'Khay chuẩn',
                      helperText: _hasImages
                          ? 'Chụp lại ảnh nếu muốn đổi khay'
                          : null,
                    ),
                    items: [
                      for (final t in [
                        ...TrayLayout.all,
                        if (!TrayLayout.all.contains(_tray)) _tray,
                      ])
                        DropdownMenuItem(
                          value: t.id,
                          child: Text('Khay ${t.name}'),
                        ),
                    ],
                    onChanged: _hasImages
                        ? null
                        : (v) => setState(() => _tray = TrayLayout.byId(v)),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _slots.length; i++) ...[
              const SizedBox(height: 14),
              _section(context, _slots[i].title, _slotBody(context, i)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('grain_submit'),
              onPressed: _ready && !_saving ? _submit : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('Xem kết quả'),
            ),
            if (!_ready)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  widget.mode == AnalysisMode.quick
                      ? 'Cần chụp đủ 2 ảnh.'
                      : 'Cần chụp ảnh mẫu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, Widget child) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _slotBody(BuildContext context, int index) {
    final palette = DtcPalette.of(context);
    final slot = _slots[index];
    final buttons = Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: Key('grain_camera_$index'),
            onPressed: slot.busy
                ? null
                : () => _capture(index, ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(slot.fileName == null ? 'Chụp ảnh' : 'Chụp lại'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            key: Key('grain_gallery_$index'),
            onPressed: slot.busy
                ? null
                : () => _capture(index, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Chọn ảnh'),
          ),
        ),
      ],
    );
    if (slot.busy) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: slot.progress),
          const SizedBox(height: 8),
          Text(
            '${slot.stage ?? 'Đang phân tích'}… '
            '${((slot.progress ?? 0) * 100).round()}%',
            style: TextStyle(color: palette.muted),
          ),
        ],
      );
    }
    final a = slot.analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (a == null)
          Text(slot.hint, style: TextStyle(color: palette.muted, fontSize: 13))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slot.path != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    File(slot.path!),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    cacheWidth: 240,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${GrainFormat.count(a.totalCount)} hạt',
                      key: Key('grain_slot_count_$index'),
                      style: TextStyle(
                        color: palette.navy,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      a.pixelsPerMm == null
                          ? 'Không nhận ra khay — không có số đo mm'
                          : '${_tray.hasMarkers ? 'Thấy đủ 4 mốc' : 'Thấy viền khay'} · '
                                '${GrainFormat.decimal(a.pixelsPerMm!)} px/mm',
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                    if (a.issues.isNotEmpty)
                      Text(
                        'Ảnh kém: ${a.issues.map((i) => i.label).join(', ')}',
                        style: const TextStyle(
                          color: Color(0xFFC0392B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (a.ignoredRegionCount > 0)
                      Text(
                        '${a.ignoredRegionCount} vùng lớn bất thường (bóng đổ, '
                        'mép giấy, đống hạt) không được tính.',
                        style: const TextStyle(
                          color: Color(0xFFB9770E),
                          fontSize: 12.5,
                        ),
                      ),
                    if (a.edgeCutCount > 0)
                      Text(
                        '${a.edgeCutCount} vật thể chạm mép vùng phân tích '
                        'không được tính — rải hạt gọn trong khung.',
                        style: const TextStyle(
                          color: Color(0xFFB9770E),
                          fontSize: 12.5,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        if (slot.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              slot.error!,
              style: const TextStyle(color: Color(0xFFC0392B)),
            ),
          ),
        const SizedBox(height: 12),
        buttons,
      ],
    );
  }
}
