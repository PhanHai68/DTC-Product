import 'package:flutter/foundation.dart';

import '../models/maintenance_activity.dart';
import '../models/maintenance_checklist_task.dart';
import '../models/maintenance_item.dart';
import '../models/maintenance_parameter.dart';
import '../models/maintenance_part.dart';
import '../models/maintenance_photo.dart';
import '../models/maintenance_report.dart';
import '../repositories/maintenance_report_repository.dart';
import '../services/maintenance_photo_service.dart';
import '../services/maintenance_report_pdf_service.dart';

/// Quản lý danh sách "Báo cáo bảo trì" và trạng thái của report đang mở.
class MaintenanceReportProvider extends ChangeNotifier {
  MaintenanceReportProvider({
    MaintenanceReportRepository? repository,
    MaintenancePhotoService? photoService,
  }) : _repository = repository ?? MaintenanceReportRepository(),
       _photoService = photoService ?? MaintenancePhotoService();

  final MaintenanceReportRepository _repository;
  final MaintenancePhotoService _photoService;

  List<MaintenanceReport> _reports = const [];
  bool _isLoadingList = false;
  String? _listError;

  MaintenanceReport? _currentReport;
  List<MaintenanceItem> _items = const [];
  List<MaintenancePhoto> _photos = const [];
  List<MaintenanceChecklistTask> _checklist = const [];
  List<MaintenancePart> _parts = const [];
  List<MaintenanceParameter> _parameters = const [];
  List<MaintenanceActivity> _activities = const [];
  bool _isLoadingDetail = false;
  bool _isCapturingPhoto = false;
  String? _detailError;

  List<MaintenanceReport> get reports => _reports;
  bool get isLoadingList => _isLoadingList;
  String? get listError => _listError;

  MaintenanceReport? get currentReport => _currentReport;
  List<MaintenanceItem> get items => _items;
  List<MaintenancePhoto> get photos => _photos;
  List<MaintenanceChecklistTask> get checklist => _checklist;
  List<MaintenancePart> get parts => _parts;
  List<MaintenanceParameter> get parameters => _parameters;
  List<MaintenanceActivity> get activities => _activities;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isCapturingPhoto => _isCapturingPhoto;
  String? get detailError => _detailError;

  List<MaintenancePhoto> photosForItem(String itemId) =>
      _photos.where((photo) => photo.itemId == itemId).toList();

  Future<void> loadReports() async {
    _isLoadingList = true;
    _listError = null;
    notifyListeners();
    try {
      _reports = await _repository.getReports();
    } catch (error) {
      _listError = 'Không thể tải danh sách báo cáo: $error';
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  Future<MaintenanceReport> createReport({
    required String customerName,
    required String factorySite,
    required String contactPerson,
    required String contactPhone,
    required String machineName,
    required String machineType,
    required String machineModel,
    required String machineSerial,
    required String machineRunningHours,
    required String machineLocation,
    required DateTime maintenanceDate,
    required String engineerName,
  }) async {
    final report = await _repository.createReport(
      customerName: customerName,
      factorySite: factorySite,
      contactPerson: contactPerson,
      contactPhone: contactPhone,
      machineName: machineName,
      machineType: machineType,
      machineModel: machineModel,
      machineSerial: machineSerial,
      machineRunningHours: machineRunningHours,
      machineLocation: machineLocation,
      maintenanceDate: maintenanceDate,
      engineerName: engineerName,
    );
    await loadReports();
    return report;
  }

  Future<void> deleteReport(String id) async {
    await _repository.deleteReport(id);
    await loadReports();
  }

  Future<void> loadReportDetail(String reportId) async {
    _isLoadingDetail = true;
    _detailError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getReport(reportId),
        _repository.getItems(reportId),
        _repository.getPhotos(reportId),
        _repository.getChecklist(reportId),
        _repository.getParts(reportId),
        _repository.getParameters(reportId),
        _repository.getActivities(reportId),
      ]);
      _currentReport = results[0] as MaintenanceReport?;
      _items = results[1] as List<MaintenanceItem>;
      _photos = results[2] as List<MaintenancePhoto>;
      _checklist = results[3] as List<MaintenanceChecklistTask>;
      _parts = results[4] as List<MaintenancePart>;
      _parameters = results[5] as List<MaintenanceParameter>;
      _activities = results[6] as List<MaintenanceActivity>;
    } catch (error) {
      _detailError = 'Không thể tải báo cáo: $error';
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> _refreshDetail() async {
    final reportId = _currentReport?.id;
    if (reportId == null) return;
    await loadReportDetail(reportId);
  }

  Future<void> updateReport(MaintenanceReport report) async {
    await _repository.updateReport(report);
    await _refreshDetail();
  }

  Future<void> startMaintenance() async {
    final reportId = _currentReport?.id;
    if (reportId == null) return;
    await _repository.startMaintenance(reportId);
    await _refreshDetail();
  }

  Future<void> completeMaintenance() async {
    final reportId = _currentReport?.id;
    if (reportId == null) return;
    await _repository.completeMaintenance(reportId);
    await _refreshDetail();
  }

  Future<MaintenanceItem?> addItem(String name) async {
    final reportId = _currentReport?.id;
    if (reportId == null || name.trim().isEmpty) return null;
    final item = await _repository.addItem(reportId, name.trim());
    await _refreshDetail();
    return item;
  }

  Future<void> updateItem(MaintenanceItem item) async {
    await _repository.updateItem(item);
    await _refreshDetail();
  }

  Future<void> deleteItem(String itemId) async {
    await _repository.deleteItem(itemId);
    await _refreshDetail();
  }

  /// Chụp 1 ảnh Before/After bằng Verified Camera cho report đang mở. Report
  /// phải đã Start Maintenance (có sessionId) trước khi gọi. Trả về `false`
  /// nếu người dùng huỷ chụp hoặc chưa Start Maintenance.
  Future<bool> captureVerifiedPhoto({
    required MaintenancePhotoKind kind,
    String? itemId,
  }) async {
    final report = _currentReport;
    final sessionId = report?.sessionId;
    if (report == null || sessionId == null) return false;

    _isCapturingPhoto = true;
    notifyListeners();
    try {
      final (photoId, sequence) = await _repository.nextPhotoId(
        reportId: report.id,
        sessionId: sessionId,
        kind: kind,
      );
      final photo = await _photoService.captureVerifiedPhoto(
        reportId: report.id,
        photoId: photoId,
        kind: kind,
        sequence: sequence,
        itemId: itemId,
      );
      if (photo == null) return false;
      await _repository.insertPhoto(photo);
      await _refreshDetail();
      return true;
    } finally {
      _isCapturingPhoto = false;
      notifyListeners();
    }
  }

  /// Xoá 1 ảnh đã chụp (chỉ dùng khi report còn Draft — chụp lại).
  Future<void> deletePhoto(MaintenancePhoto photo) async {
    await _repository.deletePhoto(photo);
    await _refreshDetail();
  }

  /// Tính lại SHA-256 của toàn bộ ảnh gốc trong report và cập nhật cờ
  /// `verified`. Trả về (số ảnh hợp lệ, tổng số ảnh).
  Future<(int verifiedCount, int total)> verifyAllPhotos() async {
    final reportId = _currentReport?.id;
    if (reportId == null) return (0, 0);
    var verifiedCount = 0;
    for (final photo in _photos) {
      final isValid = await _photoService.verifyOriginal(photo);
      if (isValid) verifiedCount++;
      if (isValid != photo.verified) {
        await _repository.updatePhotoVerified(photo.id, isValid);
      }
    }
    await _refreshDetail();
    return (verifiedCount, _photos.length);
  }

  Future<void> addCustomTask(String label) async {
    final reportId = _currentReport?.id;
    if (reportId == null || label.trim().isEmpty) return;
    await _repository.addCustomTask(reportId, label.trim());
    await _refreshDetail();
  }

  Future<void> toggleChecklistTask(String taskId, bool checked) async {
    await _repository.toggleChecklistTask(taskId, checked);
    await _refreshDetail();
  }

  Future<void> deleteChecklistTask(String taskId) async {
    await _repository.deleteChecklistTask(taskId);
    await _refreshDetail();
  }

  Future<void> addPart({
    required String partName,
    String partNumber = '',
    double quantity = 1,
    String unit = 'pcs',
    String note = '',
  }) async {
    final reportId = _currentReport?.id;
    if (reportId == null || partName.trim().isEmpty) return;
    await _repository.addPart(
      reportId: reportId,
      partName: partName.trim(),
      partNumber: partNumber.trim(),
      quantity: quantity,
      unit: unit.trim().isEmpty ? 'pcs' : unit.trim(),
      note: note.trim(),
    );
    await _refreshDetail();
  }

  Future<void> deletePart(String partId) async {
    await _repository.deletePart(partId);
    await _refreshDetail();
  }

  Future<void> addParameter({
    required String label,
    String value = '',
    String unit = '',
  }) async {
    final reportId = _currentReport?.id;
    if (reportId == null || label.trim().isEmpty) return;
    await _repository.addParameter(
      reportId: reportId,
      label: label.trim(),
      value: value.trim(),
      unit: unit.trim(),
    );
    await _refreshDetail();
  }

  Future<void> deleteParameter(String parameterId) async {
    await _repository.deleteParameter(parameterId);
    await _refreshDetail();
  }

  /// Sinh PDF cho 1 report bất kỳ (không phụ thuộc report đang mở trong
  /// workspace) — dùng cho nút "Generate PDF"/"Share PDF" ngay ở màn danh
  /// sách. Tự đọc lại toàn bộ dữ liệu + bytes ảnh Report Photo cần thiết.
  Future<Uint8List> generatePdfBytes(String reportId) async {
    final report = await _repository.getReport(reportId);
    if (report == null) throw StateError('Không tìm thấy báo cáo.');
    final results = await Future.wait([
      _repository.getItems(reportId),
      _repository.getPhotos(reportId),
      _repository.getChecklist(reportId),
      _repository.getParts(reportId),
      _repository.getParameters(reportId),
    ]);
    final items = results[0] as List<MaintenanceItem>;
    final photos = results[1] as List<MaintenancePhoto>;
    final checklist = results[2] as List<MaintenanceChecklistTask>;
    final parts = results[3] as List<MaintenancePart>;
    final parameters = results[4] as List<MaintenanceParameter>;

    final photoBytes = <String, Uint8List>{};
    for (final photo in photos) {
      final bytes = await _repository.readPhotoBytes(photo.reportPath);
      if (bytes != null) photoBytes[photo.id] = bytes;
    }

    return MaintenanceReportPdfService.build(
      report: report,
      items: items,
      photos: photos,
      checklist: checklist,
      parts: parts,
      parameters: parameters,
      photoBytes: photoBytes,
    );
  }
}
