import 'package:flutter/foundation.dart';

import '../../air_system_config/pipe/material_list.dart';
import '../engine/survey_bom.dart';
import '../models/pipe_survey.dart';
import '../repositories/pipe_survey_repository.dart';

/// Trạng thái màn khảo sát: sửa là tính lại vật tư ngay; mỗi thao tác vẽ lưu
/// một bản để hoàn tác.
class PipeSurveyController extends ChangeNotifier {
  PipeSurveyController({
    required this._survey,
    required this.constants,
    this._repository,
    this.persisted = false,
  });

  /// Khóa danh sách vật tư trong [PipeSurvey.edits].
  static const materialList = 'survey';
  static const _maxUndo = 50;

  final SurveyConstants constants;
  final PipeSurveyRepository? _repository;
  final PipeSurvey _survey;
  final List<PipeSurvey> _undo = [];
  SurveyBom? _bom;
  bool _dirty = false;

  /// Đã có trong cơ sở dữ liệu.
  bool persisted;

  PipeSurvey get survey => _survey;
  bool get dirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;

  SurveyBom get bom => _bom ??= computeSurveyBom(_survey, constants);

  /// Vật tư bóc từ sơ đồ, đã áp phần sửa tay.
  List<MaterialRow> get materialRows => applyMaterialEdits([
    for (final l in bom.lines)
      MaterialRow(
        key: l.key,
        code: l.code,
        name: l.name,
        spec: l.spec,
        unit: l.unit,
        qty: l.qty,
      ),
  ], _survey.edits[materialList]);

  /// Sửa khảo sát; [undoable] = lưu bản trước để hoàn tác (thao tác vẽ).
  void edit(void Function(PipeSurvey s) change, {bool undoable = true}) {
    if (undoable) {
      _undo.add(_survey.copy());
      if (_undo.length > _maxUndo) _undo.removeAt(0);
    }
    change(_survey);
    _changed();
  }

  /// Hoàn tác thao tác vẽ: chỉ khôi phục sơ đồ (điểm, đoạn ống); thông tin
  /// công trình và phần sửa vật tư giữ nguyên.
  void undo() {
    if (_undo.isEmpty) return;
    final previous = _undo.removeLast();
    _survey.nodes
      ..clear()
      ..addAll(previous.nodes);
    _survey.segments
      ..clear()
      ..addAll(previous.segments);
    _changed();
  }

  void _changed() {
    _bom = null;
    _dirty = true;
    notifyListeners();
  }

  Future<void> save() async {
    await _repository?.save(_survey);
    persisted = true;
    _dirty = false;
    notifyListeners();
  }
}
