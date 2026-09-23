import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../data/maintenance_report_database.dart';
import '../models/maintenance_activity.dart';
import '../models/maintenance_checklist_task.dart';
import '../models/maintenance_item.dart';
import '../models/maintenance_part.dart';
import '../models/maintenance_photo.dart';
import '../models/maintenance_report.dart';
import '../services/maintenance_file_storage.dart'
    if (dart.library.io) '../services/maintenance_file_storage_io.dart'
    if (dart.library.js_interop) '../services/maintenance_file_storage_web.dart';

/// Truy cập dữ liệu cho "Báo cáo bảo trì" — gộp CRUD của report + toàn bộ
/// bảng con (item/photo/checklist/part/activity) và các quy tắc nghiệp vụ
/// đơn giản (sinh Mã phiên bảo trì, sinh Photo ID, xác minh SHA-256).
class MaintenanceReportRepository {
  MaintenanceReportRepository({MaintenanceReportDatabase? database})
    : _db = database ?? MaintenanceReportDatabase.instance;

  final MaintenanceReportDatabase _db;

  Map<String, dynamic> _map(Map<String, Object?> row) =>
      Map<String, dynamic>.from(row);

  // Bộ đếm tăng dần kèm theo mốc giờ để tránh trùng id khi tạo nhiều dòng
  // liên tiếp trong 1 vòng lặp (VD seedDefaultChecklist) — độ phân giải của
  // DateTime.now() không đủ để tự đảm bảo duy nhất trong trường hợp đó.
  static int _idSequence = 0;

  String _id(String prefix) {
    _idSequence++;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idSequence';
  }

  // ---------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------

  Future<List<MaintenanceReport>> getReports() async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_reports',
      orderBy: 'updatedAt DESC',
    );
    return rows.map((row) => MaintenanceReport.fromJson(_map(row))).toList();
  }

  Future<MaintenanceReport?> getReport(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return MaintenanceReport.fromJson(_map(rows.first));
  }

  /// Tạo report mới (status = draft). Không còn chèn checklist mặc định —
  /// người dùng tự thêm từng công việc qua "Thêm công việc".
  Future<MaintenanceReport> createReport({
    required String customerName,
    required String factorySite,
    required String machineModel,
    required String machineTagName,
    required String machineRunningHours,
    required DateTime maintenanceDate,
    required List<String> engineerNames,
  }) async {
    final now = DateTime.now();
    final report = MaintenanceReport(
      id: _id('report'),
      customerName: customerName,
      factorySite: factorySite,
      machineModel: machineModel,
      machineTagName: machineTagName,
      machineRunningHours: machineRunningHours,
      maintenanceDate: maintenanceDate,
      engineerNames: engineerNames,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _db.database;
    await db.insert('maintenance_reports', report.toJson());
    return report;
  }

  Future<void> updateReport(MaintenanceReport report) async {
    final db = await _db.database;
    final updated = report.copyWith(updatedAt: DateTime.now());
    await db.update(
      'maintenance_reports',
      updated.toJson(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  /// Xoá report và TOÀN BỘ dữ liệu/ảnh/PDF liên quan — không thể hoàn tác.
  Future<void> deleteReport(String id) async {
    final db = await _db.database;
    await db.delete(
      'maintenance_items',
      where: 'reportId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'maintenance_photos',
      where: 'reportId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'maintenance_checklist',
      where: 'reportId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'maintenance_parts',
      where: 'reportId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'maintenance_activity_log',
      where: 'reportId = ?',
      whereArgs: [id],
    );
    await db.delete('maintenance_reports', where: 'id = ?', whereArgs: [id]);
    await deleteMaintenanceReportFiles(id);
  }

  /// Bấm "Start Maintenance" — sinh Mã phiên bảo trì
  /// (`TTM-{viết tắt tên kỹ sư}-{tên khách hàng}-{ngày tạo}`), cũng chính là
  /// tên file PDF khi xuất ra (xem `maintenanceReportFileName`), ghi
  /// startTime = hiện tại.
  Future<MaintenanceReport> startMaintenance(String reportId) async {
    final report = await getReport(reportId);
    if (report == null) throw StateError('Không tìm thấy report.');
    if (report.hasStarted) return report;

    final now = DateTime.now();
    final initials = _sessionInitials(report.engineerNames);
    final customerPart = _sessionCustomerPart(report.customerName);
    final datePart = DateFormat('yyyyMMdd').format(now);
    final sessionId = await _uniqueSessionId(
      'TTM-$initials-$customerPart-$datePart',
    );

    final updated = report.copyWith(sessionId: sessionId, startTime: now);
    await updateReport(updated);
    await logActivity(reportId, 'Bắt đầu bảo trì');
    return updated;
  }

  /// Cùng viết tắt kỹ sư + cùng ngày có thể trùng (VD 2 report do cùng kỹ sư
  /// Start Maintenance trong ngày, hoặc nhiều report không ghi kỹ sư) — thêm
  /// hậu tố "-2", "-3"... chỉ khi thật sự trùng, giữ nguyên định dạng gốc ở
  /// trường hợp bình thường.
  Future<String> _uniqueSessionId(String base) async {
    final db = await _db.database;
    var candidate = base;
    var suffix = 2;
    while (true) {
      final rows = await db.query(
        'maintenance_reports',
        where: 'sessionId = ?',
        whereArgs: [candidate],
        limit: 1,
      );
      if (rows.isEmpty) return candidate;
      candidate = '$base-$suffix';
      suffix++;
    }
  }

  /// Viết tắt chữ cái đầu mỗi từ trong tên (các) kỹ sư, bỏ dấu để đảm bảo an
  /// toàn khi hiển thị trong watermark ảnh (font bitmap chỉ hỗ trợ ASCII).
  /// VD: ["Nguyễn Văn An"] → "NVA"; ["Kevin", "An"] → "KA".
  static String _sessionInitials(List<String> engineerNames) {
    final buffer = StringBuffer();
    for (final name in engineerNames) {
      for (final word in name.trim().split(RegExp(r'\s+'))) {
        if (word.isEmpty) continue;
        buffer.write(_stripDiacritics(word[0]).toUpperCase());
      }
    }
    return buffer.isEmpty ? 'XX' : buffer.toString();
  }

  /// Rút gọn tên khách hàng để ghép vào Mã phiên bảo trì / tên file PDF: bỏ
  /// dấu, bỏ khoảng trắng và ký tự đặc biệt (an toàn cho tên file trên mọi
  /// hệ điều hành), giới hạn độ dài để Mã phiên không quá dài với khách hàng
  /// có tên đầy đủ dạng công ty. VD: "ABC Factory" → "ABCFactory".
  static String _sessionCustomerPart(String customerName) {
    final cleaned = _stripDiacritics(
      customerName,
    ).replaceAll(RegExp(r'[^A-Za-z0-9]+'), '');
    if (cleaned.isEmpty) return 'KH';
    return cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
  }

  static const _accented =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  static const _plain =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

  static String _stripDiacritics(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final index = _accented.indexOf(char);
      buffer.write(index >= 0 ? _plain[index] : char);
    }
    return buffer.toString();
  }

  /// Bấm "Complete Maintenance" — khoá report (không cho đổi ảnh Original
  /// nữa), ghi endTime = hiện tại.
  Future<MaintenanceReport> completeMaintenance(String reportId) async {
    final report = await getReport(reportId);
    if (report == null) throw StateError('Không tìm thấy report.');
    final updated = report.copyWith(
      status: MaintenanceReportStatus.completed,
      endTime: DateTime.now(),
    );
    await updateReport(updated);
    await logActivity(reportId, 'Hoàn tất bảo trì');
    return updated;
  }

  // ---------------------------------------------------------------------
  // Maintenance Items
  // ---------------------------------------------------------------------

  Future<List<MaintenanceItem>> getItems(String reportId) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_items',
      where: 'reportId = ?',
      whereArgs: [reportId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((row) => MaintenanceItem.fromJson(_map(row))).toList();
  }

  Future<MaintenanceItem> addItem(String reportId, String name) async {
    final db = await _db.database;
    final existing = await db.query(
      'maintenance_items',
      where: 'reportId = ?',
      whereArgs: [reportId],
    );
    final now = DateTime.now();
    final item = MaintenanceItem(
      id: _id('item'),
      reportId: reportId,
      name: name,
      orderIndex: existing.length,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('maintenance_items', item.toJson());
    return item;
  }

  Future<void> updateItem(MaintenanceItem item) async {
    final db = await _db.database;
    final updated = item.copyWith(updatedAt: DateTime.now());
    await db.update(
      'maintenance_items',
      updated.toJson(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(String itemId) async {
    final db = await _db.database;
    final photos = await db.query(
      'maintenance_photos',
      where: 'itemId = ?',
      whereArgs: [itemId],
    );
    for (final row in photos) {
      final photo = MaintenancePhoto.fromJson(_map(row));
      await deleteMaintenanceFile(photo.originalPath);
      await deleteMaintenanceFile(photo.reportPath);
    }
    await db.delete(
      'maintenance_photos',
      where: 'itemId = ?',
      whereArgs: [itemId],
    );
    await db.delete('maintenance_items', where: 'id = ?', whereArgs: [itemId]);
  }

  // ---------------------------------------------------------------------
  // Photos
  // ---------------------------------------------------------------------

  Future<List<MaintenancePhoto>> getPhotos(String reportId) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_photos',
      where: 'reportId = ?',
      whereArgs: [reportId],
      orderBy: 'kind ASC, sequence ASC',
    );
    return rows.map((row) => MaintenancePhoto.fromJson(_map(row))).toList();
  }

  /// Sinh Photo ID kế tiếp cho 1 report+loại (before/after), VD B01, B02...
  /// dựa trên Session ID hiện có của report.
  Future<(String photoId, int sequence)> nextPhotoId({
    required String reportId,
    required String sessionId,
    required MaintenancePhotoKind kind,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_photos',
      where: 'reportId = ? AND kind = ?',
      whereArgs: [reportId, kind.name],
    );
    final sequence = rows.length + 1;
    final photoId =
        '$sessionId-${kind.prefix}${sequence.toString().padLeft(2, '0')}';
    return (photoId, sequence);
  }

  Future<void> insertPhoto(MaintenancePhoto photo) async {
    final db = await _db.database;
    await db.insert('maintenance_photos', photo.toJson());
    await logActivity(
      photo.reportId,
      '${photo.kind == MaintenancePhotoKind.before ? "Ảnh Trước" : "Ảnh Sau"} '
      '${photo.id}',
    );
  }

  /// Xoá 1 ảnh cụ thể (chỉ dùng khi report còn Draft — chụp lại ảnh).
  Future<void> deletePhoto(MaintenancePhoto photo) async {
    final db = await _db.database;
    await db.delete(
      'maintenance_photos',
      where: 'id = ?',
      whereArgs: [photo.id],
    );
    await deleteMaintenanceFile(photo.originalPath);
    await deleteMaintenanceFile(photo.reportPath);
  }

  Future<void> updatePhotoVerified(String photoId, bool verified) async {
    final db = await _db.database;
    await db.update(
      'maintenance_photos',
      {'verified': verified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  // ---------------------------------------------------------------------
  // Checklist
  // ---------------------------------------------------------------------

  Future<List<MaintenanceChecklistTask>> getChecklist(String reportId) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_checklist',
      where: 'reportId = ?',
      whereArgs: [reportId],
      orderBy: 'orderIndex ASC',
    );
    return rows
        .map((row) => MaintenanceChecklistTask.fromJson(_map(row)))
        .toList();
  }

  Future<MaintenanceChecklistTask> addChecklistTask(
    String reportId,
    String label,
  ) async {
    final db = await _db.database;
    final existing = await db.query(
      'maintenance_checklist',
      where: 'reportId = ?',
      whereArgs: [reportId],
    );
    final task = MaintenanceChecklistTask(
      id: _id('task'),
      reportId: reportId,
      label: label,
      orderIndex: existing.length,
    );
    await db.insert('maintenance_checklist', task.toJson());
    return task;
  }

  Future<void> toggleChecklistTask(String taskId, bool checked) async {
    final db = await _db.database;
    await db.update(
      'maintenance_checklist',
      {'isChecked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  Future<void> deleteChecklistTask(String taskId) async {
    final db = await _db.database;
    await db.delete(
      'maintenance_checklist',
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  // ---------------------------------------------------------------------
  // Parts Used
  // ---------------------------------------------------------------------

  Future<List<MaintenancePart>> getParts(String reportId) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_parts',
      where: 'reportId = ?',
      whereArgs: [reportId],
      orderBy: 'orderIndex ASC',
    );
    return rows.map((row) => MaintenancePart.fromJson(_map(row))).toList();
  }

  Future<MaintenancePart> addPart({
    required String reportId,
    required String partName,
    String partNumber = '',
    double quantity = 1,
    String unit = 'pcs',
    String note = '',
  }) async {
    final db = await _db.database;
    final existing = await db.query(
      'maintenance_parts',
      where: 'reportId = ?',
      whereArgs: [reportId],
    );
    final part = MaintenancePart(
      id: _id('part'),
      reportId: reportId,
      partName: partName,
      partNumber: partNumber,
      quantity: quantity,
      unit: unit,
      note: note,
      orderIndex: existing.length,
    );
    await db.insert('maintenance_parts', part.toJson());
    return part;
  }

  Future<void> deletePart(String partId) async {
    final db = await _db.database;
    await db.delete('maintenance_parts', where: 'id = ?', whereArgs: [partId]);
  }

  // ---------------------------------------------------------------------
  // Activity Log
  // ---------------------------------------------------------------------

  Future<List<MaintenanceActivity>> getActivities(String reportId) async {
    final db = await _db.database;
    final rows = await db.query(
      'maintenance_activity_log',
      where: 'reportId = ?',
      whereArgs: [reportId],
      orderBy: 'timestamp ASC',
    );
    return rows
        .map((row) => MaintenanceActivity.fromJson(_map(row)))
        .toList();
  }

  /// Đọc bytes 1 file ảnh (Original hoặc Report Photo) đã lưu trên đĩa —
  /// dùng khi Generate PDF hoặc xác minh SHA-256.
  Future<Uint8List?> readPhotoBytes(String path) => readMaintenanceFile(path);

  Future<void> logActivity(String reportId, String message) async {
    final db = await _db.database;
    final activity = MaintenanceActivity(
      id: _id('activity'),
      reportId: reportId,
      timestamp: DateTime.now(),
      message: message,
    );
    await db.insert('maintenance_activity_log', activity.toJson());
  }
}
