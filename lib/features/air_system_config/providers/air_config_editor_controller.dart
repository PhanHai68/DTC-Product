import 'package:flutter/foundation.dart';

import '../diagram/air_diagram.dart';
import '../diagram/custom_equipment.dart';
import '../engine/air_engine.dart';
import '../engine/custom_calc.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import '../repositories/air_config_repository.dart';
import '../pipe/install_kit.dart';
import '../pipe/material_list.dart';
import '../pipe/pipe_engine.dart';
import '../room/room_drawing.dart';
import '../room/room_engine.dart';

/// Trạng thái màn cấu hình: mỗi lần sửa thì tính lại ngay (không cần bấm nút).
class AirConfigEditorController extends ChangeNotifier {
  AirConfigEditorController({
    required this._config,
    required this.engine,
    this.roomEngine,
    this.pipeEngine,
    this.installKits,
    this._repository,
    this.persisted = false,
    AirLang lang = AirLang.vi,
  }) : _lang = lang,
       _strings = AirStrings(lang) {
    _compute();
  }

  final AirEngine engine;

  /// Bộ tính tab "Phòng lắp đặt"; `null` thì tab không có dữ liệu.
  final RoomEngine? roomEngine;

  /// Bộ bóc vật tư đường ống tab "Vật tư đường ống".
  final PipeMaterialEngine? pipeEngine;

  /// Vật tư lắp đặt cụm máy theo công suất; `null` thì không có mục này.
  final InstallKits? installKits;
  final AirConfigRepository? _repository;
  final AirConfig _config;
  late AirResult _result;

  /// Kết quả của cấu hình tự động (model mặc định cho sơ đồ tuỳ chỉnh).
  late AirResult _auto;
  AirLang _lang;
  AirStrings _strings;
  AirDiagram? _diagram;
  RoomResult? _room;
  PipeResult? _pipe;
  RoomDrawing? _roomDrawing;
  bool _dirty = false;

  /// Đã có trong cơ sở dữ liệu.
  bool persisted;

  AirConfig get config => _config;
  AirResult get result => _result;

  /// Kết quả của cấu hình tự động (bỏ qua sơ đồ tuỳ chỉnh) — cho ô nhập.
  AirResult get autoResult => _auto;
  AirLang get lang => _lang;
  AirStrings get strings => _strings;
  bool get dirty => _dirty;
  int get maxLines => engine.constants.maxLines;

  /// Sơ đồ lắp đặt: sơ đồ tuỳ chỉnh khi đang bật, không thì sơ đồ tự động.
  AirDiagram get diagram => _diagram ??= _config.custom.active
      ? buildCustomAirDiagram(_config, _result, _strings, customEquipment)
      : buildAirDiagram(_config, _result, _strings);

  /// Model, thông số thiết bị cho sơ đồ tuỳ chỉnh.
  CustomEquipment get customEquipment =>
      CustomEquipment(engine, _config, _auto, _strings);

  /// Bật sơ đồ tuỳ chỉnh; chưa có tầng nào thì dựng từ cấu hình tự động.
  void enableCustom(bool on) => edit((c) {
    if (on && c.custom.stages.isEmpty) {
      c.custom.stages.addAll(customLayoutFromResult(c, _auto).stages);
    }
    c.custom.enabled = on;
  });

  /// Dựng lại sơ đồ tuỳ chỉnh từ cấu hình tự động (bỏ phần đã sửa).
  void resetCustom() => edit((c) {
    c.custom.stages
      ..clear()
      ..addAll(customLayoutFromResult(c, _auto).stages);
  });

  RoomResult? get room => _room ??= roomEngine?.compute(_config, _result);

  /// Vật tư đường ống (tab 4); `null` khi không có [pipeEngine].
  PipeResult? get pipe => _pipe ??= pipeEngine?.compute(_config, _result);

  /// Vật tư lắp đặt cụm máy theo công suất máy nén đã chọn; `null` khi chưa
  /// chọn máy hoặc công suất chưa cập nhật.
  InstallKit? get installKit =>
      installKits?.forPowerKw(_result.compressor?.powerKw);

  /// Danh sách vật tư [list] của tab "Vật tư lắp đặt", đã áp phần sửa tay.
  List<MaterialRow> materialRows(MaterialList list) =>
      buildMaterialRows(list, _config, kit: installKit, pipe: pipe);

  /// Bản vẽ mặt bằng phòng lắp đặt; `null` khi không có [roomEngine].
  RoomDrawing? get roomDrawing {
    final room = this.room;
    if (room == null) return null;
    return _roomDrawing ??= buildRoomDrawing(_config, room, _strings);
  }

  /// Tăng mỗi lần đổi kích thước phòng từ màn chỉnh sửa, để ô nhập ở tab
  /// Phòng lắp đặt dựng lại với giá trị mới.
  int roomSizeRevision = 0;

  void setRoomSize(double? lengthM, double? widthM, double? heightM) {
    roomSizeRevision++;
    edit(
      (c) => c.room
        ..lengthM = lengthM
        ..widthM = widthM
        ..heightM = heightM,
    );
  }

  /// Đổi T1, T2 thông gió từ màn chỉnh sửa; ô nhập ở tab dựng lại theo.
  void setVentTemps(double? outsideC, double? inletMaxC) {
    roomSizeRevision++;
    edit(
      (c) => c.room
        ..outsideTempC = outsideC
        ..inletMaxTempC = inletMaxC,
    );
  }

  /// Sửa cấu hình rồi tính lại kết quả và sơ đồ.
  void edit(void Function(AirConfig config) change) {
    change(_config);
    _recompute();
    _dirty = true;
    notifyListeners();
  }

  void setLang(AirLang lang) {
    if (lang == _lang) return;
    _lang = lang;
    _strings = AirStrings(lang);
    _diagram = null;
    _roomDrawing = null;
    notifyListeners();
  }

  void addLine() {
    if (_config.lines.length >= maxLines) return;
    edit((c) => c.lines.add(AirLine(name: 'Line ${c.lines.length + 1}')));
  }

  void removeLine(String id) {
    if (_config.lines.length <= 1) return;
    edit((c) => c.lines.removeWhere((l) => l.id == id));
  }

  void setOverride(String key, {String? name, String? spec}) => edit((c) {
    final o = EquipmentOverride(name: name, spec: spec);
    if (o.isEmpty) {
      c.overrides.remove(key);
    } else {
      c.overrides[key] = o;
    }
  });

  Future<void> save() async {
    final repository = _repository;
    if (repository == null) return;
    await repository.save(_config);
    persisted = true;
    _dirty = false;
    notifyListeners();
  }

  /// Kết quả tự động; sơ đồ tuỳ chỉnh đang bật thì tính lại máy nén, bình,
  /// máy sấy, lọc, tổn áp, cảnh báo theo sơ đồ.
  void _compute() {
    _auto = engine.compute(_config);
    _result = applyCustomLayout(engine, _config, _auto);
  }

  void _recompute() {
    _compute();
    _diagram = null;
    _room = null;
    _pipe = null;
    _roomDrawing = null;
  }

  /// Danh mục thiết bị hiển thị (đã áp phần sửa tay).
  List<(EquipmentItem, String, String)> get equipmentRows => [
    for (final e in _result.equipment)
      (e, _strings.displayName(e, _config), _strings.displaySpec(e, _config)),
  ];
}
