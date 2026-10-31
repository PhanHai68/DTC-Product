import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/product_data.dart';
import '../data/air_config_templates.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../providers/air_config_editor_controller.dart';
import '../repositories/air_config_repository.dart';
import '../services/air_config_export_service.dart';
import '../services/air_file_saver.dart';
import '../services/air_po_excel.dart';
import '../widgets/air_config_form.dart';
import '../pipe/pipe_strings.dart';
import '../room/room_strings.dart';
import '../widgets/air_config_results.dart';
import '../widgets/air_pipe_view.dart';
import '../widgets/air_room_view.dart';
import '../widgets/po_export_dialog.dart';

enum _ExportKind { pdf, po, png }

/// Màn cấu hình hệ thống khí nén: Nhập liệu | Kết quả (kèm sơ đồ) | Phòng
/// lắp đặt.
///
/// Mở cấu hình đã lưu bằng [configId], hoặc cấu hình mới [initial] (mẫu,
/// JSON nhập vào); không có gì thì tạo cấu hình mặc định.
class AirConfigEditorScreen extends StatefulWidget {
  const AirConfigEditorScreen({
    super.key,
    this.configId,
    this.initial,
    this.repository,
    this.initialTab = 0,
  });

  final String? configId;
  final AirConfig? initial;
  final AirConfigRepository? repository;

  /// Tab mở đầu: 0 Nhập liệu, 1 Kết quả, 2 Phòng lắp đặt, 3 Vật tư đường ống.
  final int initialTab;

  @override
  State<AirConfigEditorScreen> createState() => _AirConfigEditorScreenState();
}

class _AirConfigEditorScreenState extends State<AirConfigEditorScreen> {
  late final AirConfigRepository _repository =
      widget.repository ?? AirConfigRepository();
  AirConfigEditorController? _controller;
  bool _missing = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.configId;
    AirConfig? config = widget.initial;
    var persisted = false;
    if (config == null && id != null) {
      config = await _repository.get(id);
      persisted = config != null;
      if (config == null) {
        if (mounted) setState(() => _missing = true);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _controller = AirConfigEditorController(
        config: config ?? AirConfig(),
        engine: appAirEngine(),
        roomEngine: appRoomEngine(),
        pipeEngine: appPipeEngine(),
        installKits: installKits,
        repository: _repository,
        persisted: persisted,
      );
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AirStrings(AirLang.vi).title)),
        body: Center(
          child: _missing
              ? const Text('Không tìm thấy cấu hình.')
              : const CircularProgressIndicator(),
        ),
      );
    }
    return ChangeNotifierProvider.value(
      value: ctrl,
      child: Consumer<AirConfigEditorController>(
        builder: (context, ctrl, _) {
          final s = ctrl.strings;
          final name = ctrl.config.project.name.trim();
          return PopScope(
            canPop: !ctrl.dirty,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _confirmLeave(ctrl);
            },
            child: DefaultTabController(
              length: 4,
              initialIndex: widget.initialTab,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    name.isEmpty ? s.title : name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    _LangToggle(ctrl: ctrl),
                    IconButton(
                      key: const Key('air_config_save'),
                      tooltip: s.save,
                      onPressed: _busy ? null : () => _save(ctrl),
                      icon: Badge(
                        isLabelVisible: ctrl.dirty,
                        smallSize: 8,
                        child: const Icon(Icons.save_outlined),
                      ),
                    ),
                    PopupMenuButton<_ExportKind>(
                      key: const Key('air_config_export'),
                      tooltip: s.export,
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
                            s.exportPdf,
                            Icons.picture_as_pdf_outlined,
                          ),
                          (
                            _ExportKind.po,
                            s.exportPo,
                            Icons.table_chart_outlined,
                          ),
                          (_ExportKind.png, s.exportPng, Icons.image_outlined),
                        ])
                          PopupMenuItem(
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
                  bottom: TabBar(
                    // 4 tab: cuộn ngang trên điện thoại hẹp.
                    isScrollable: MediaQuery.sizeOf(context).width < 600,
                    labelPadding: MediaQuery.sizeOf(context).width < 600
                        ? const EdgeInsets.symmetric(horizontal: 10)
                        : null,
                    tabAlignment: MediaQuery.sizeOf(context).width < 600
                        ? TabAlignment.start
                        : null,
                    tabs: [
                      Tab(text: s.tabInput),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                s.tabResult,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ctrl.result.hasErrors) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.error,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(text: s.tabRoom),
                      Tab(text: s.tabPipe),
                    ],
                  ),
                ),
                body: const TabBarView(
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    AirConfigForm(),
                    AirConfigResults(),
                    AirRoomView(),
                    AirPipeView(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(AirConfigEditorController ctrl) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ctrl.save();
      messenger.showSnackBar(SnackBar(content: Text(ctrl.strings.saved)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _export(AirConfigEditorController ctrl, _ExportKind kind) async {
    final messenger = ScaffoldMessenger.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    // Đề nghị vật tư: chọn Excel / PDF và kiểu theo hạng mục / gộp mã.
    final po = kind == _ExportKind.po
        ? await showDialog<PoExportChoice>(
            context: context,
            builder: (_) => PoExportDialog(strings: ctrl.strings),
          )
        : null;
    if (kind == _ExportKind.po && po == null) return;
    setState(() => _busy = true);
    try {
      final base = AirConfigExportService.baseName(ctrl.config, DateTime.now());
      final s = ctrl.strings;
      Future<PoTemplate> template() => PoTemplate.load(
        (path) async => (await rootBundle.load(path)).buffer.asUint8List(),
      );
      final file = switch (kind) {
        // Một file: sơ đồ lắp đặt + mặt bằng phòng lắp đặt.
        _ExportKind.pdf => await AirConfigExportService.pdf(
          ctrl.config,
          s,
          ctrl.diagram,
          base,
          room: ctrl.roomDrawing,
          roomHeading: s.roomDrawingTitle,
        ),
        // Phiếu đề nghị vật tư theo form PO.
        _ExportKind.po when po!.pdf => await AirConfigExportService.poPdf(
          await template(),
          ctrl.config,
          ctrl.result,
          base: base,
          pipe: ctrl.pipe,
          kits: ctrl.installKits,
          merged: po.merged,
          requester: po.requester,
        ),
        _ExportKind.po => AirConfigExportService.po(
          await template(),
          ctrl.config,
          ctrl.result,
          base: base,
          pipe: ctrl.pipe,
          kits: ctrl.installKits,
          merged: po!.merged,
          requester: po.requester,
        ),
        _ExportKind.png => await AirConfigExportService.png(ctrl.diagram, base),
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

  Future<void> _confirmLeave(AirConfigEditorController ctrl) async {
    final navigator = Navigator.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lưu thay đổi?'),
        content: const Text('Cấu hình có thay đổi chưa lưu.'),
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
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.ctrl});
  final AirConfigEditorController ctrl;

  @override
  Widget build(BuildContext context) {
    final next = ctrl.lang == AirLang.vi ? AirLang.en : AirLang.vi;
    return TextButton(
      key: const Key('air_config_lang'),
      onPressed: () => ctrl.setLang(next),
      child: Text(ctrl.lang == AirLang.vi ? 'VI' : 'EN'),
    );
  }
}
