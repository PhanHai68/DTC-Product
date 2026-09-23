import 'package:dtc_product/features/maintenance_report/models/maintenance_checklist_task.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_item.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_part.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_photo.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_report.dart';
import 'package:dtc_product/features/maintenance_report/services/maintenance_report_pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tạo PDF báo cáo bảo trì đủ overview, item, checklist và verification', () async {
    final photoData = await rootBundle.load(
      'assets/images/DTCGroup-Slogan.png',
    );
    final photo = Uint8List.sublistView(photoData);
    final now = DateTime(2026, 9, 23, 9, 20);

    final report = MaintenanceReport(
      id: 'report_1',
      status: MaintenanceReportStatus.completed,
      customerName: 'ABC Factory',
      factorySite: 'KCN Long An',
      machineModel: 'OPA-75PM',
      machineTagName: 'SC16PRO-JX26010333',
      machineRunningHours: '5000',
      maintenanceDate: DateTime(2026, 9, 23),
      engineerNames: const ['Kevin'],
      sessionId: 'TTM-K-ABCFactory-20260923',
      startTime: now,
      endTime: now.add(const Duration(hours: 2)),
      machineCondition: 'Máy chạy êm, áp suất ổn định, không rò rỉ.',
      overallResult: MaintenanceOverallResult.completed,
      finalComment: 'Máy chạy tốt sau bảo trì.',
      recommendation: 'Thay dây curoa vào lần bảo trì sau.',
      nextMaintenanceRunningHours: '5500',
      createdAt: now,
      updatedAt: now,
    );

    final item = MaintenanceItem(
      id: 'item_1',
      reportId: report.id,
      name: 'Air Filter',
      beforeFinding: 'Lọc gió bẩn nhiều.',
      actionTaken: 'Thay lọc gió mới.',
      afterResult: 'Đã thay xong, hoạt động bình thường.',
      status: MaintenanceItemStatus.completed,
      createdAt: now,
      updatedAt: now,
    );

    final beforePhoto = MaintenancePhoto(
      id: 'MNT-20260923-0015-B01',
      reportId: report.id,
      itemId: item.id,
      kind: MaintenancePhotoKind.before,
      sequence: 1,
      originalPath: '/data/original/B01.jpg',
      reportPath: '/data/before/B01.jpg',
      sha256: 'hash-before',
      capturedAt: now,
    );
    final afterPhoto = MaintenancePhoto(
      id: 'MNT-20260923-0015-A01',
      reportId: report.id,
      itemId: item.id,
      kind: MaintenancePhotoKind.after,
      sequence: 1,
      originalPath: '/data/original/A01.jpg',
      reportPath: '/data/after/A01.jpg',
      sha256: 'hash-after',
      capturedAt: now.add(const Duration(hours: 1)),
    );

    final checklist = [
      const MaintenanceChecklistTask(
        id: 'task_1',
        reportId: 'report_1',
        label: 'Replace air filter',
        isChecked: true,
      ),
      const MaintenanceChecklistTask(
        id: 'task_2',
        reportId: 'report_1',
        label: 'Check belt',
        isChecked: false,
      ),
    ];
    final parts = [
      const MaintenancePart(
        id: 'part_1',
        reportId: 'report_1',
        partName: 'Air Filter',
        partNumber: 'AF-001',
        quantity: 1,
        unit: 'pcs',
      ),
    ];
    final bytes = await MaintenanceReportPdfService.build(
      report: report,
      items: [item],
      photos: [beforePhoto, afterPhoto],
      checklist: checklist,
      parts: parts,
      photoBytes: {
        beforePhoto.id: photo,
        afterPhoto.id: photo,
      },
    );

    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    // "Vật tư thay thế" và "Công việc đã thực hiện" phải cùng nằm trên trang
    // tổng quan (trang 1) ngay dưới nhau, không còn để trống 1 trang riêng
    // cho checklist như trước.
    final document = PdfDocument(inputBytes: bytes);
    final page1Text = PdfTextExtractor(
      document,
    ).extractText(startPageIndex: 0, endPageIndex: 0);
    expect(page1Text, contains('VẬT TƯ THAY THẾ'));
    expect(page1Text, contains('CÔNG VIỆC ĐÃ THỰC HIỆN'));
    document.dispose();
  });

  test('PDF đưa vào TẤT CẢ ảnh Before/After của 1 hạng mục, không chỉ ảnh đầu tiên', () async {
    final photoData = await rootBundle.load(
      'assets/images/DTCGroup-Slogan.png',
    );
    final photo = Uint8List.sublistView(photoData);
    final now = DateTime(2026, 9, 23, 9, 20);

    final report = MaintenanceReport(
      id: 'report_multi',
      customerName: 'ABC Factory',
      maintenanceDate: DateTime(2026, 9, 23),
      createdAt: now,
      updatedAt: now,
    );
    final item = MaintenanceItem(
      id: 'item_multi',
      reportId: report.id,
      name: 'Air Filter',
      status: MaintenanceItemStatus.completed,
      createdAt: now,
      updatedAt: now,
    );

    MaintenancePhoto makePhoto(MaintenancePhotoKind kind, int sequence) {
      final prefix = kind == MaintenancePhotoKind.before ? 'B' : 'A';
      return MaintenancePhoto(
        id: 'MNT-20260923-item_multi-$prefix${sequence.toString().padLeft(2, '0')}',
        reportId: report.id,
        itemId: item.id,
        kind: kind,
        sequence: sequence,
        originalPath: '/data/original/$prefix$sequence.jpg',
        reportPath: '/data/report/$prefix$sequence.jpg',
        sha256: 'hash-$prefix$sequence',
        capturedAt: now,
      );
    }

    final onePairPhotos = [
      makePhoto(MaintenancePhotoKind.before, 1),
      makePhoto(MaintenancePhotoKind.after, 1),
    ];
    final sixPhotos = [
      for (var i = 1; i <= 3; i++) makePhoto(MaintenancePhotoKind.before, i),
      for (var i = 1; i <= 3; i++) makePhoto(MaintenancePhotoKind.after, i),
    ];

    Map<String, Uint8List> photoBytesFor(List<MaintenancePhoto> photos) => {
      for (final p in photos) p.id: photo,
    };

    final onePairBytes = await MaintenanceReportPdfService.build(
      report: report,
      items: [item],
      photos: onePairPhotos,
      checklist: const [],
      parts: const [],
      photoBytes: photoBytesFor(onePairPhotos),
    );
    final sixPhotoBytes = await MaintenanceReportPdfService.build(
      report: report,
      items: [item],
      photos: sixPhotos,
      checklist: const [],
      parts: const [],
      photoBytes: photoBytesFor(sixPhotos),
    );

    expect(String.fromCharCodes(onePairBytes.take(4)), '%PDF');
    expect(String.fromCharCodes(sixPhotoBytes.take(4)), '%PDF');

    // 1 cặp Before/After chỉ cần 1 trang cho hạng mục (280 < 800), trong khi
    // 3 cặp phải tràn sang nhiều trang — chứng tỏ tất cả ảnh đều được vẽ vào,
    // không chỉ ảnh đầu tiên của mỗi loại (đây chính là lỗi người dùng báo cáo).
    final onePairDoc = PdfDocument(inputBytes: onePairBytes);
    final sixPhotoDoc = PdfDocument(inputBytes: sixPhotoBytes);
    expect(sixPhotoDoc.pages.count, greaterThan(onePairDoc.pages.count));
    onePairDoc.dispose();
    sixPhotoDoc.dispose();
  });

  test('vẫn tạo được PDF khi report chưa có item/checklist/parts nào', () async {
    final now = DateTime(2026, 9, 23);
    final report = MaintenanceReport(
      id: 'report_2',
      maintenanceDate: now,
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await MaintenanceReportPdfService.build(
      report: report,
      items: const [],
      photos: const [],
      checklist: const [],
      parts: const [],
      photoBytes: const {},
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
