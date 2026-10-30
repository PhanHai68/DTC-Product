import '../models/air_config.dart';
import 'install_kit.dart';
import 'pipe_engine.dart';

/// Các danh sách vật tư của tab "Vật tư lắp đặt"; [name] là khóa lưu phần sửa
/// tay trong `PipeConfig.edits`.
enum MaterialList { kit, drain, electric, pipe }

/// Một dòng vật tư hiển thị / xuất file: dòng tự tính (đã áp phần sửa tay)
/// hoặc vật tư thêm tay.
class MaterialRow {
  const MaterialRow({
    required this.key,
    required this.name,
    required this.unit,
    required this.qty,
    this.code,
    this.spec,
    this.note,
    this.base,
    this.extraId,
  });

  /// Khóa dòng tự tính (để lưu phần sửa); vật tư thêm tay: `extra:<id>`.
  final String key;
  final String? code;
  final String name;

  /// Quy cách; `null` hoặc rỗng = không có.
  final String? spec;
  final String unit;
  final num qty;

  /// Ghi chú (vd "VT tiêu hao").
  final String? note;

  /// Dòng tự tính gốc khi dòng này đã sửa tay.
  final MaterialRow? base;

  /// Id vật tư thêm tay.
  final String? extraId;

  bool get isExtra => extraId != null;
  bool get isEdited => base != null;

  /// Giá trị tự tính để so khi lưu phần sửa (dòng thêm tay: chính nó).
  MaterialRow get auto => base ?? this;
}

/// Dòng tự tính của một danh sách, chưa áp phần sửa tay. Tên vật tư lấy
/// nguyên từ dữ liệu (file PO, định mức 15 m tuyến ống).
List<MaterialRow> autoMaterialRows(
  MaterialList list, {
  InstallKit? kit,
  PipeResult? pipe,
}) {
  if (list == MaterialList.pipe) {
    return [
      for (final i in pipe?.items ?? const <PipeRunLine>[])
        MaterialRow(
          key: i.key,
          code: i.code,
          name: i.name,
          spec: i.spec,
          unit: i.unit,
          qty: i.qty,
          note: i.note,
        ),
    ];
  }
  final section = switch (list) {
    MaterialList.kit => kit?.standard,
    MaterialList.drain => kit?.drain,
    _ => kit?.electric,
  };
  final seen = <String, int>{};
  return [
    for (final i in section?.items ?? const <InstallKitItem>[])
      MaterialRow(
        // Tên trùng trong cùng mục: thêm số thứ tự để khóa không trùng.
        key: switch (seen.update(i.name, (n) => n + 1, ifAbsent: () => 1)) {
          1 => i.name,
          final n => '${i.name}#$n',
        },
        code: i.code,
        name: i.name,
        spec: i.spec,
        unit: i.unit,
        qty: i.qty,
        note: i.note,
      ),
  ];
}

/// Áp phần sửa tay [edit] lên các dòng tự tính [auto]: bỏ dòng đã xoá, thay
/// trường đã sửa, thêm vật tư thêm tay ở cuối.
List<MaterialRow> applyMaterialEdits(
  List<MaterialRow> auto,
  MaterialListEdit? edit,
) {
  String? text(String? v) => v == null || v.isEmpty ? null : v;
  final rows = <MaterialRow>[];
  for (final a in auto) {
    final e = edit?.rows[a.key];
    if (e == null || e.isEmpty) {
      rows.add(a);
    } else if (!e.removed) {
      rows.add(
        MaterialRow(
          key: a.key,
          code: e.code == null ? a.code : text(e.code),
          name: e.name ?? a.name,
          spec: e.spec == null ? a.spec : text(e.spec),
          unit: e.unit ?? a.unit,
          qty: e.qty ?? a.qty,
          note: a.note,
          base: a,
        ),
      );
    }
  }
  return [
    ...rows,
    for (final x in edit?.extras ?? const <MaterialExtra>[])
      MaterialRow(
        key: 'extra:${x.id}',
        code: text(x.code),
        name: x.name,
        spec: text(x.spec),
        unit: x.unit,
        qty: x.qty,
        extraId: x.id,
      ),
  ];
}

/// Danh sách vật tư đã áp phần sửa tay của [config].
List<MaterialRow> buildMaterialRows(
  MaterialList list,
  AirConfig config, {
  InstallKit? kit,
  PipeResult? pipe,
}) => applyMaterialEdits(
  autoMaterialRows(list, kit: kit, pipe: pipe),
  config.pipe.edits[list.name],
);

/// Sửa tay các danh sách vật tư theo khóa danh sách — dùng chung cho Cấu
/// hình hệ thống khí nén (`PipeConfig.edits`) và Khảo sát tuyến ống.
extension MaterialEdits on Map<String, MaterialListEdit> {
  MaterialListEdit _list(String list) =>
      putIfAbsent(list, MaterialListEdit.new);

  void _tidy(String list) {
    final e = this[list];
    if (e == null) return;
    e.rows.removeWhere((_, r) => r.isEmpty);
    if (e.isEmpty) remove(list);
  }

  /// Lưu giá trị mới của [row]; trường bằng giá trị tự tính thì không lưu
  /// (để vẫn tự tính lại theo dữ liệu).
  void saveMaterial(
    String list,
    MaterialRow row, {
    String code = '',
    required String name,
    required String spec,
    required String unit,
    required double qty,
  }) {
    final e = _list(list);
    if (row.extraId case final id?) {
      final x = e.extras.firstWhere((x) => x.id == id);
      x
        ..code = code
        ..name = name
        ..spec = spec
        ..unit = unit
        ..qty = qty;
    } else {
      final a = row.auto;
      e.rows[row.key] = MaterialEdit(
        code: code == (a.code ?? '') ? null : code,
        name: name == a.name ? null : name,
        spec: spec == (a.spec ?? '') ? null : spec,
        unit: unit == a.unit ? null : unit,
        qty: qty == a.qty ? null : qty,
      );
    }
    _tidy(list);
  }

  void removeMaterial(String list, MaterialRow row) {
    final e = _list(list);
    if (row.extraId case final id?) {
      e.extras.removeWhere((x) => x.id == id);
    } else {
      e.rows[row.key] = MaterialEdit(removed: true);
    }
    _tidy(list);
  }

  /// Dòng tự tính về lại giá trị tự tính.
  void resetMaterial(String list, MaterialRow row) {
    this[list]?.rows.remove(row.key);
    _tidy(list);
  }

  void addMaterial(
    String list, {
    String code = '',
    required String name,
    required String spec,
    required String unit,
    required double qty,
  }) => _list(list).extras.add(
    MaterialExtra(code: code, name: name, spec: spec, unit: unit, qty: qty),
  );

  /// Bỏ mọi phần sửa tay của danh sách.
  void resetMaterialList(String list) => remove(list);
}

/// Sửa danh sách vật tư [list] của [config] (gọi trong `ctrl.edit`).
extension MaterialEditing on AirConfig {
  void saveMaterial(
    MaterialList list,
    MaterialRow row, {
    String code = '',
    required String name,
    required String spec,
    required String unit,
    required double qty,
  }) => pipe.edits.saveMaterial(
    list.name,
    row,
    code: code,
    name: name,
    spec: spec,
    unit: unit,
    qty: qty,
  );

  void removeMaterial(MaterialList list, MaterialRow row) =>
      pipe.edits.removeMaterial(list.name, row);

  void resetMaterial(MaterialList list, MaterialRow row) =>
      pipe.edits.resetMaterial(list.name, row);

  void addMaterial(
    MaterialList list, {
    String code = '',
    required String name,
    required String spec,
    required String unit,
    required double qty,
  }) => pipe.edits.addMaterial(
    list.name,
    code: code,
    name: name,
    spec: spec,
    unit: unit,
    qty: qty,
  );

  void resetMaterialList(MaterialList list) =>
      pipe.edits.resetMaterialList(list.name);
}
