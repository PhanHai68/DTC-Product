import 'package:flutter/material.dart';

import '../../../data/product_data.dart';
import '../models/pipe_survey.dart';
import '../providers/pipe_survey_controller.dart';
import '../repositories/pipe_survey_repository.dart';
import '../widgets/survey_canvas.dart';
import '../widgets/survey_info_form.dart';
import '../widgets/survey_materials_view.dart';

/// Khảo sát tuyến ống một công trình: Thông tin | Sơ đồ | Vật tư.
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
        appBar: AppBar(title: const Text('Khảo sát tuyến ống')),
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
              name.isEmpty ? 'Khảo sát tuyến ống' : name,
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
