import 'package:shared_preferences/shared_preferences.dart';

import 'air_po_excel.dart';

/// Nhớ thông tin người đề nghị trên máy để lần xuất phiếu sau không phải nhập
/// lại: người đề nghị, mã NV, chức vụ, bộ phận, mã dự án. Số lần đề nghị
/// nhập mỗi lần (mặc định "001"). Lưu trong SharedPreferences nên có trong
/// bản sao lưu dữ liệu.
abstract final class PoRequesterStore {
  static const _requester = 'po_requester_name';
  static const _employeeId = 'po_requester_employee_id';
  static const _position = 'po_requester_position';
  static const _department = 'po_requester_department';
  static const _projectCode = 'po_requester_project_code';

  /// Mã dự án gợi ý khi chưa nhập lần nào (như form PO).
  static const defaultProjectCode = 'DTC-';
  static const defaultRequestNo = '001';

  static Future<PoRequester> load() async {
    final p = await SharedPreferences.getInstance();
    return PoRequester(
      requester: p.getString(_requester) ?? '',
      employeeId: p.getString(_employeeId) ?? '',
      position: p.getString(_position) ?? '',
      department: p.getString(_department) ?? '',
      projectCode: p.getString(_projectCode) ?? defaultProjectCode,
      requestNo: defaultRequestNo,
    );
  }

  /// Lưu 5 ô (không lưu số lần đề nghị); ô để trống thì lưu trống.
  static Future<void> save(PoRequester r) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_requester, r.requester);
    await p.setString(_employeeId, r.employeeId);
    await p.setString(_position, r.position);
    await p.setString(_department, r.department);
    await p.setString(_projectCode, r.projectCode);
  }
}
