import '../l10n/air_strings.dart';
import 'install_kit.dart';
import 'pipe_engine.dart';

/// Chữ của tab "Vật tư lắp đặt", VI/EN. Tên vật tư lắp đặt cụm máy lấy
/// nguyên từ file PO (tiếng Việt).
extension PipeStrings on AirStrings {
  String _r(String vi, String en) => isEn ? en : vi;

  String get tabPipe => _r('Vật tư lắp đặt', 'Installation materials');

  // ── Vật tư lắp đặt cụm máy ───────────────────────────────────────────────
  String get kitTitle =>
      _r('Vật tư lắp đặt cụm máy', 'Compressor package installation');
  String kitFor(InstallKit kit, String? model) => _r(
    'Máy nén khí ${kit.hp}HP (${n0(kit.kw)} kW)${model == null ? '' : ' · $model'} — tiêu chuẩn theo sơ đồ',
    '${kit.hp}HP air compressor (${n0(kit.kw)} kW)${model == null ? '' : ' · $model'} — standard per diagram',
  );
  String get kitNotUpdated => _r('Chưa cập nhật', 'Not updated yet');
  String kitNotUpdatedDetail(double? kw, List<int> hps) {
    final list = hps.map((hp) => '${hp}HP').join(', ');
    return kw == null
        ? _r(
            'Chưa chọn được máy nén nên chưa có vật tư lắp đặt cụm máy (đang có: $list).',
            'No compressor selected, so no package materials yet (available: $list).',
          )
        : _r(
            'Máy nén ${n2(kw)} kW: chưa cập nhật vật tư lắp đặt cụm máy (đang có: $list).',
            '${n2(kw)} kW compressor: package materials not updated yet (available: $list).',
          );
  }

  String kitUnitsNote(int units) => _r(
    'Định mức cho 1 cụm máy tiêu chuẩn; hệ có $units máy nén — kiểm tra lại số lượng.',
    'Quantities are for one standard package; this system has $units compressors — check the quantities.',
  );
  String get kitDrain => _r(
    'Van xả tự động đáy bình tích khí',
    'Automatic drain valve for the receiver',
  );
  String get kitElectric =>
      _r('Vật tư điện tạm tính', 'Provisional electrical materials');
  String kitQty(num qty) =>
      qty == qty.roundToDouble() ? '${qty.round()}' : n1(qty);

  String get exportPo => _r('Excel đề nghị vật tư', 'Material request (Excel)');

  // ── Vật tư từ cụm máy đến thiết bị sử dụng khí nén ───────────────────────
  String get pipeInputTitle => _r(
    'Vật tư từ cụm máy đến thiết bị sử dụng khí nén',
    'Materials from the compressor package to the air consumers',
  );
  String pipeInputHint(PipeResult r) => _r(
    'Định mức vật tư cho mỗi ${n0(r.stepM)} m tuyến ống; số lượng nhân theo số bước ${n0(r.stepM)} m (lấy bằng hoặc lớn hơn gần nhất tổng chiều dài).',
    'Quantities per ${n0(r.stepM)} m of pipe run, multiplied by the number of ${n0(r.stepM)} m steps (total length rounded up).',
  );
  String get pipeLength =>
      _r('Tổng chiều dài đường ống (m)', 'Total pipe length (m)');

  /// Dòng ghi dưới bảng: chiều dài tính vật tư, cỡ ống, cách làm tròn.
  String pipeNote(PipeResult r) => _r(
    'Tính cho ${n0(r.coveredM)} m (${r.steps} bước × ${n0(r.stepM)} m)${r.dn == null ? '' : ', ống DN${r.dn}'} · ống kẽm làm tròn lên nguyên cây 6 m, số lẻ làm tròn lên.',
    'Calculated for ${n0(r.coveredM)} m (${r.steps} steps × ${n0(r.stepM)} m)${r.dn == null ? '' : ', DN${r.dn} pipe'} · galvanised pipe rounded up to whole 6 m lengths, fractions rounded up.',
  );

  // ── Sửa tay danh sách vật tư ─────────────────────────────────────────────
  String get matEditHint => _r(
    'Muốn sửa: tick "Cho phép sửa" của bảng rồi chạm vào dòng để sửa hoặc xoá; dòng tô vàng là dòng đã sửa / thêm tay.',
    'To edit: tick "Allow editing" on a table, then tap a row to edit or delete it; yellow rows are edited / added by hand.',
  );
  String get matEditMode => _r('Cho phép sửa', 'Allow editing');
  String get matEdit => _r('Sửa vật tư', 'Edit item');
  String get matAdd => _r('Thêm vật tư', 'Add item');
  String get matDelete => _r('Xoá', 'Delete');
  String get matReset => _r('Về giá trị tự tính', 'Reset to calculated');
  String get matResetList =>
      _r('Khôi phục danh sách gốc', 'Restore original list');
  String get matCancel => _r('Huỷ', 'Cancel');
  String get matSave => _r('Lưu', 'Save');
  String get matQty => _r('Số lượng', 'Quantity');
  String get matEmpty => _r('Chưa có vật tư.', 'No items yet.');
  String get matNameRequired => _r('Nhập tên vật tư', 'Enter the item name');
  String get matQtyInvalid =>
      _r('Số lượng phải lớn hơn 0', 'Quantity must be greater than 0');

  String get pipeTableTitle => _r('Bảng vật tư', 'Bill of materials');
  String get pipeColNo => _r('STT', 'No.');
  String get pipeColName => _r('Vật tư', 'Item');
  String get pipeColSpec => _r('Quy cách', 'Size');
  String get pipeColUnit => _r('ĐVT', 'Unit');
  String get pipeColQty => _r('SL', 'Qty');

  String pipeWarning(PipeWarning w) {
    final p = w.params;
    return switch (w.code) {
      PipeWarningCode.missingLength => _r(
        'Nhập tổng chiều dài đường ống để bóc vật tư.',
        'Enter the total pipe length to build the bill of materials.',
      ),
      PipeWarningCode.noSize => () {
        final sizes = (p['sizes'] as List<int>).map((d) => 'DN$d').join(', ');
        return p['dn'] == null
            ? _r(
                'Chưa xác định được cỡ ống (chưa chọn máy nén): chưa có danh sách vật tư (đang có: $sizes).',
                'Pipe size unknown (no compressor selected): no materials list yet (available: $sizes).',
              )
            : _r(
                'Chưa cập nhật danh sách vật tư cho ống DN${p['dn']} (đang có: $sizes).',
                'No materials list for DN${p['dn']} pipe yet (available: $sizes).',
              );
      }(),
    };
  }
}
