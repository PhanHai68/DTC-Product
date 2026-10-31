import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/product_data.dart';
import '../../air_system_config/data/air_config_templates.dart';
import '../../air_system_config/l10n/air_strings.dart';
import '../../air_system_config/services/air_file_saver.dart';
import '../../air_system_config/services/air_po_excel.dart';
import '../../air_system_config/widgets/po_export_dialog.dart';
import '../engine/survey_plant.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import '../repositories/pipe_survey_repository.dart';
import '../services/survey_export_service.dart';
import '../widgets/survey_canvas.dart';
import '../widgets/survey_info_form.dart';
import '../widgets/survey_materials_view.dart';

enum _ExportKind { pdf, png, po }

/// Khảo sát vật tư ngoại tuyến một công trình: Thông tin | Sơ đồ | Vật tư.
///
/// Mở khảo sát đã lưu bằng [surveyId], hoặc khảo sát mới [initial]; không có
/// gì thì tạo khảo sát trống.
class PipeSurveyEditorScreen extends StatefulWidget {
  const PipeSurveyEditorScreen({
    super.key,
    this.surveyId,
    this.initial,
    this.repository,
    this.initialTab = 0,
  });

  final String? surveyId;
  final PipeSurvey? initial;
  final PipeSurveyRepository? repository;
  final int initialTab;

  @override
  State<PipeSurveyEditorScreen> createState() => _PipeSurveyEditorScreenState();
}

class _PipeSurveyEditorScreenState extends State<PipeSurveyEditorScreen> {
  late final PipeSurveyRepository _repository =
      widget.repository ?? PipeSurveyRepository();
  PipeSurveyController? _ctrl;
  bool _missing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var survey = widget.initial;
    var persisted = false;
    if (survey == null && widget.surveyId != null) {
      survey = await _repository.get(widget.surveyId!);
      persisted = survey != null;
      if (survey == null) {
        if (mounted) setState(() => _missing = true);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _ctrl = PipeSurveyController(
        survey: survey ?? PipeSurvey(),
        constants: pipeSurveyConstants,
        repository: _repository,
        persisted: persisted,
        plantEngine: SurveyPlantEngine(
          air: appAirEngine(),
          room: appRoomEngine(),
        ),
      )..addListener(_rebuild);
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _save(PipeSurveyController ctrl) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ctrl.save();
      messenger.showSnackBar(const SnackBar(content: Text('Đã lưu khảo sát')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  /// Xuất sơ đồ (PDF / PNG) hoặc phiếu đề nghị vật tư (Excel / PDF, form PO
  /// như Cấu hình hệ thống khí nén).
  Future<void> _export(PipeSurveyController ctrl, _ExportKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final po = kind == _ExportKind.po
        ? await showDialog<PoExportChoice>(
            context: context,
            builder: (_) => PoExportDialog(strings: AirStrings(AirLang.vi)),
          )
        : null;
    if (kind == _ExportKind.po && po == null) return;
    setState(() => _busy = true);
    try {
      final survey = ctrl.survey;
      final base = SurveyExportService.baseName(survey, DateTime.now());
      Future<PoTemplate> template() => PoTemplate.load(
        (path) async => (await rootBundle.load(path)).buffer.asUint8List(),
      );
      final file = switch (kind) {
        _ExportKind.pdf => await SurveyExportService.pdf(
          survey,
          ctrl.plants,
          base,
        ),
        _ExportKind.png => await SurveyExportService.png(
          survey,
          ctrl.plants,
          base,
        ),
        _ExportKind.po when po!.pdf => await SurveyExportService.poPdf(
          await template(),
          survey,
          ctrl.materialRows,
          base: base,
          merged: po.merged,
          requester: po.requester,
        ),
        _ExportKind.po => SurveyExportService.po(
          await template(),
          survey,
          ctrl.materialRows,
          base: base,
          merged: po!.merged,
          requester: po.requester,
        ),
      };
      await deliverAirExport(file, origin: origin);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không xuất được file: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave(PipeSurveyController ctrl) async {
    final navigator = Navigator.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu thay đổi?'),
        content: const Text('Khảo sát có thay đổi chưa lưu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Bỏ thay đổi'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      await ctrl.save();
    } else if (choice != 'discard') {
      return;
    }
    if (!mounted) return;
    // Navigator.pop không bị PopScope chặn.
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (ctrl == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Khảo sát vật tư ngoại tuyến')),
        body: Center(
          child: _missing
              ? const Text('Không tìm thấy khảo sát.')
              : const CircularProgressIndicator(),
        ),
      );
    }
    final name = ctrl.survey.name.trim();
    return PopScope(
      canPop: !ctrl.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(ctrl);
      },
      child: DefaultTabController(
        length: 3,
        initialIndex: widget.initialTab,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              name.isEmpty ? 'Khảo sát vật tư ngoại tuyến' : name,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const Key('survey_save'),
                tooltip: 'Lưu',
                onPressed: () => _save(ctrl),
                icon: Badge(
                  isLabelVisible: ctrl.dirty,
                  smallSize: 8,
                  child: const Icon(Icons.save_outlined),
                ),
              ),
              PopupMenuButton<_ExportKind>(
                key: const Key('survey_export'),
                tooltip: 'Xuất file',
                enabled: !_busy,
                icon: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded),
                onSelected: (kind) => _export(ctrl, kind),
                itemBuilder: (_) => [
                  for (final (kind, label, icon) in [
                    (
                      _ExportKind.pdf,
                      'Sơ đồ (PDF)',
                      Icons.picture_as_pdf_outlined,
                    ),
                    (
                      _ExportKind.png,
                      'Sơ đồ (hình ảnh PNG)',
                      Icons.image_outlined,
                    ),
                    (
                      _ExportKind.po,
                      'Đề nghị vật tư (Excel / PDF)',
                      Icons.table_chart_outlined,
                    ),
                  ])
                    PopupMenuItem(
                      key: Key('survey_export_${kind.name}'),
                      value: kind,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(icon),
                        title: Text(label),
                      ),
                    ),
                ],
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Thông tin'),
                Tab(text: 'Sơ đồ'),
                Tab(text: 'Vật tư'),
              ],
            ),
          ),
          body: TabBarView(
            // Không vuốt đổi tab: tránh nhầm với thao tác vẽ.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SurveyInfoForm(ctrl: ctrl),
              SurveyCanvas(ctrl: ctrl),
              SurveyMaterialsView(ctrl: ctrl),
            ],
          ),
        ),
      ),
    );
  }
}
