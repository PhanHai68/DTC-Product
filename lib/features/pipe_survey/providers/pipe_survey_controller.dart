import 'package:flutter/foundation.dart';

import '../../air_system_config/pipe/material_list.dart';
import '../engine/survey_bom.dart';
import '../engine/survey_plant.dart';
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
    this.plantEngine,
  });

  /// Khóa danh sách vật tư trong [PipeSurvey.edits].
  static const materialList = 'survey';
  static const _maxUndo = 50;

  final SurveyConstants constants;

  /// Bộ tính cụm máy theo kích thước thật; `null` thì luôn vẽ ký hiệu MN.
  final SurveyPlantEngine? plantEngine;
  final PipeSurveyRepository? _repository;
  final PipeSurvey _survey;
  final List<PipeSurvey> _undo = [];
  final List<PipeSurvey> _redo = [];
  SurveyBom? _bom;
  Map<String, SurveyPlantLayout>? _plants;
  bool _dirty = false;

  /// Đã có trong cơ sở dữ liệu.
  bool persisted;

  PipeSurvey get survey => _survey;
  bool get dirty => _dirty;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  SurveyBom get bom => _bom ??= computeSurveyBom(_survey, constants);

  /// Cụm máy vẽ theo kích thước thật, theo id điểm.
  Map<String, SurveyPlantLayout> get plants => _plants ??= {
    if (plantEngine case final engine?)
      for (final n in _survey.nodes)
        if (n.kind == SurveyNodeKind.compressor)
          n.id: ?engine.layout(_survey, n),
  };

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
    if (undoable) checkpoint();
    change(_survey);
    _changed();
  }

  /// Lưu bản hiện tại để hoàn tác (trước một chuỗi sửa không lưu bản, vd
  /// kéo rê); thao tác mới thì bỏ các bước "Làm lại".
  void checkpoint() {
    _push(_undo, _survey.copy());
    _redo.clear();
  }

  void _push(List<PipeSurvey> stack, PipeSurvey s) {
    stack.add(s);
    if (stack.length > _maxUndo) stack.removeAt(0);
  }

  /// Sửa có thể không làm gì ([change] trả `false`): chỉ lưu bản hoàn tác
  /// và báo thay đổi khi có sửa.
  bool tryEdit(bool Function(PipeSurvey s) change) {
    final before = _survey.copy();
    if (!change(_survey)) return false;
    _push(_undo, before);
    _redo.clear();
    _changed();
    return true;
  }

  /// Hoàn tác thao tác vẽ: chỉ khôi phục sơ đồ (điểm, đoạn ống, hình nền);
  /// thông tin công trình và phần sửa vật tư giữ nguyên.
  void undo() {
    if (_undo.isEmpty) return;
    _push(_redo, _survey.copy());
    _restore(_undo.removeLast());
  }

  /// Bỏ thao tác vừa làm (vd đặt điểm rồi huỷ): khôi phục bản trước, không
  /// thêm vào "Làm lại".
  void discardLast() {
    if (_undo.isEmpty) return;
    _restore(_undo.removeLast());
  }

  /// Làm lại bước vừa hoàn tác.
  void redo() {
    if (_redo.isEmpty) return;
    _push(_undo, _survey.copy());
    _restore(_redo.removeLast());
  }

  void _restore(PipeSurvey from) {
    _survey.nodes
      ..clear()
      ..addAll(from.nodes);
    _survey.segments
      ..clear()
      ..addAll(from.segments);
    _survey.shapes
      ..clear()
      ..addAll(from.shapes);
    _changed();
  }

  void _changed() {
    _bom = null;
    _plants = null;
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
