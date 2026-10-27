import 'package:flutter/foundation.dart';

import '../diagram/air_diagram.dart';
import '../engine/air_engine.dart';
import '../l10n/air_strings.dart';
import '../models/air_config.dart';
import '../models/air_result.dart';
import '../repositories/air_config_repository.dart';
import '../room/room_drawing.dart';
import '../room/room_engine.dart';

/// Trạng thái màn cấu hình: mỗi lần sửa thì tính lại ngay (không cần bấm nút).
class AirConfigEditorController extends ChangeNotifier {
  AirConfigEditorController({
    required this._config,
    required this.engine,
    this.roomEngine,
    this._repository,
    this.persisted = false,
    AirLang lang = AirLang.vi,
  }) : _lang = lang,
       _strings = AirStrings(lang) {
    _result = engine.compute(_config);
  }

  final AirEngine engine;

  /// Bộ tính tab "Phòng lắp đặt"; `null` thì tab không có dữ liệu.
  final RoomEngine? roomEngine;
  final AirConfigRepository? _repository;
  final AirConfig _config;
  late AirResult _result;
  AirLang _lang;
  AirStrings _strings;
  AirDiagram? _diagram;
  RoomResult? _room;
  RoomDrawing? _roomDrawing;
  bool _dirty = false;

  /// Đã có trong cơ sở dữ liệu.
  bool persisted;

  AirConfig get config => _config;
  AirResult get result => _result;
  AirLang get lang => _lang;
  AirStrings get strings => _strings;
  bool get dirty => _dirty;
  int get maxLines => engine.constants.maxLines;

  AirDiagram get diagram =>
      _diagram ??= buildAirDiagram(_config, _result, _strings);

  RoomResult? get room => _room ??= roomEngine?.compute(_config, _result);

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

  void _recompute() {
    _result = engine.compute(_config);
    _diagram = null;
    _room = null;
    _roomDrawing = null;
  }

  /// Danh mục thiết bị hiển thị (đã áp phần sửa tay).
  List<(EquipmentItem, String, String)> get equipmentRows => [
    for (final e in _result.equipment)
      (e, _strings.displayName(e, _config), _strings.displaySpec(e, _config)),
  ];
}
