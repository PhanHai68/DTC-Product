import '../l10n/air_strings.dart';
import 'pipe_engine.dart';

/// Chữ của tab "Vật tư lắp đặt", VI/EN. Tên vật tư lắp đặt cụm máy lấy
/// nguyên từ file PO (tiếng Việt).
extension PipeStrings on AirStrings {
  String _r(String vi, String en) => isEn ? en : vi;

  String get tabPipe => _r('Vật tư lắp đặt', 'Installation materials');

  // ── Vật tư lắp đặt cụm máy ───────────────────────────────────────────────
  String get kitTitle =>
      _r('Vật tư lắp đặt cụm máy', 'Compressor package installation');
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

  String get exportPo =>
      _r('Đề nghị vật tư (Excel / PDF)', 'Material request (Excel / PDF)');
  String get poDialogTitle =>
      _r('Xuất đề nghị vật tư', 'Export material request');
  String get poFormat => _r('Định dạng', 'Format');
  String get poStyle => _r('Kiểu', 'Layout');
  String get poGrouped => _r('Theo hạng mục', 'By section');
  String get poMerged => _r('Gộp mã', 'Merged codes');
  String get poGroupedHint => _r(
    'Vật tư chia theo từng hạng mục lắp đặt.',
    'Materials listed per installation section.',
  );
  String get poMergedHint => _r(
    'Gộp chung, mỗi vật tư một dòng (cộng số lượng các hạng mục).',
    'All sections combined, one line per item (quantities added).',
  );
  String get poExport => _r('Xuất file', 'Export');
  String get poRequester => _r('Người đề nghị', 'Requested by');
  String get poEmployeeId => _r('Mã NV', 'Employee ID');
  String get poPosition => _r('Chức vụ', 'Position');
  String get poDepartment => _r('Bộ phận', 'Department');
  String get poProjectCode => _r('Mã dự án', 'Project code');
  String get poRequestNo => _r('Số lần đề nghị/DA', 'Request no. / project');
  String get poClear => _r('Xoá', 'Clear');
  String get poRememberHint => _r(
    'Thông tin trên (trừ số lần đề nghị) được lưu lại cho lần xuất sau.',
    'These details (except the request no.) are remembered for next time.',
  );

  // ── Vật tư từ cụm máy đến thiết bị sử dụng khí nén ───────────────────────
  String get pipeInputTitle => _r(
    'Vật tư từ cụm máy đến thiết bị sử dụng khí nén',
    'Materials from the compressor package to the air consumers',
  );
  String get pipeLength =>
      _r('Tổng chiều dài đường ống (m)', 'Total pipe length (m)');

  // ── Sửa tay danh sách vật tư ─────────────────────────────────────────────
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
  String get matCode => _r('Mã vật tư', 'Item code');
  String get matPick => _r('Chọn từ danh mục', 'Pick from catalog');
  String get matPickSearch =>
      _r('Tìm theo tên hoặc mã', 'Search by name or code');
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
