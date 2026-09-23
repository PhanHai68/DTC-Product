import 'package:dtc_product/features/maintenance_report/models/maintenance_checklist_task.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_item.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_parameter.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_part.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_photo.dart';
import 'package:dtc_product/features/maintenance_report/models/maintenance_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaintenanceReport', () {
    test('toJson / fromJson round-trip giữ nguyên toàn bộ dữ liệu', () {
      final now = DateTime(2026, 9, 23, 9, 20);
      final report = MaintenanceReport(
        id: 'report_1',
        status: MaintenanceReportStatus.completed,
        customerName: 'ABC Factory',
        factorySite: 'KCN Long An',
        contactPerson: 'Mr. A',
        contactPhone: '0900000000',
        machineName: 'Air Compressor 100 HP',
        machineType: 'Screw',
        machineModel: 'OPA-75PM',
        machineSerial: 'SN123',
        machineRunningHours: '5000',
        machineLocation: 'Xưởng 1',
        maintenanceDate: DateTime(2026, 9, 23),
        engineerName: 'Kevin',
        sessionId: 'MNT-20260923-0015',
        startTime: now,
        endTime: now.add(const Duration(hours: 2)),
        overallResult: MaintenanceOverallResult.completed,
        finalComment: 'Máy chạy tốt',
        recommendation: 'Thay dây curoa lần sau',
        nextMaintenanceDate: DateTime(2026, 12, 23),
        nextMaintenanceRunningHours: '5500',
        createdAt: now,
        updatedAt: now,
      );

      final restored = MaintenanceReport.fromJson(report.toJson());

      expect(restored.id, report.id);
      expect(restored.status, MaintenanceReportStatus.completed);
      expect(restored.customerName, 'ABC Factory');
      expect(restored.sessionId, 'MNT-20260923-0015');
      expect(restored.startTime, now);
      expect(restored.overallResult, MaintenanceOverallResult.completed);
      expect(restored.nextMaintenanceDate, DateTime(2026, 12, 23));
      expect(restored.hasStarted, isTrue);
      expect(restored.isCompleted, isTrue);
    });

    test('mặc định: draft, chưa Start Maintenance, không có kết quả', () {
      final report = MaintenanceReport(
        id: 'report_2',
        maintenanceDate: DateTime(2026, 9, 23),
        createdAt: DateTime(2026, 9, 23),
        updatedAt: DateTime(2026, 9, 23),
      );

      expect(report.isDraft, isTrue);
      expect(report.hasStarted, isFalse);
      expect(report.overallResult, isNull);
    });

    test('copyWith clearOverallResult/clearNextMaintenanceDate trả về null', () {
      final base = MaintenanceReport(
        id: 'report_3',
        overallResult: MaintenanceOverallResult.repairRecommended,
        nextMaintenanceDate: DateTime(2026, 12, 1),
        maintenanceDate: DateTime(2026, 9, 23),
        createdAt: DateTime(2026, 9, 23),
        updatedAt: DateTime(2026, 9, 23),
      );

      final cleared = base.copyWith(
        clearOverallResult: true,
        clearNextMaintenanceDate: true,
      );

      expect(cleared.overallResult, isNull);
      expect(cleared.nextMaintenanceDate, isNull);
    });
  });

  group('MaintenanceItem', () {
    test('toJson / fromJson round-trip', () {
      final now = DateTime(2026, 9, 23);
      final item = MaintenanceItem(
        id: 'item_1',
        reportId: 'report_1',
        name: 'Air Filter',
        orderIndex: 2,
        beforeFinding: 'Bẩn nhiều',
        actionTaken: 'Thay mới',
        afterResult: 'Đã thay xong',
        status: MaintenanceItemStatus.completed,
        createdAt: now,
        updatedAt: now,
      );

      final restored = MaintenanceItem.fromJson(item.toJson());

      expect(restored.name, 'Air Filter');
      expect(restored.status, MaintenanceItemStatus.completed);
      expect(restored.orderIndex, 2);
    });
  });

  group('MaintenancePhoto', () {
    test('toJson / fromJson round-trip, verified cờ boolean 0/1', () {
      final now = DateTime(2026, 9, 23, 9, 35, 18);
      final photo = MaintenancePhoto(
        id: 'MNT-20260923-0015-B01',
        reportId: 'report_1',
        itemId: 'item_1',
        kind: MaintenancePhotoKind.before,
        sequence: 1,
        originalPath: '/data/original/B01.jpg',
        reportPath: '/data/before/B01.jpg',
        sha256: 'abc123',
        verified: false,
        capturedAt: now,
      );

      final restored = MaintenancePhoto.fromJson(photo.toJson());

      expect(restored.id, 'MNT-20260923-0015-B01');
      expect(restored.kind, MaintenancePhotoKind.before);
      expect(restored.verified, isFalse);
      expect(restored.capturedAt, now);
    });

    test('MaintenancePhotoKind.prefix đúng B/A', () {
      expect(MaintenancePhotoKind.before.prefix, 'B');
      expect(MaintenancePhotoKind.after.prefix, 'A');
    });
  });

  group('MaintenanceChecklistTask / MaintenancePart / MaintenanceParameter', () {
    test('toJson / fromJson round-trip', () {
      final task = MaintenanceChecklistTask(
        id: 'task_1',
        reportId: 'report_1',
        label: 'Replace air filter',
        isChecked: true,
        isCustom: false,
        orderIndex: 0,
      );
      expect(
        MaintenanceChecklistTask.fromJson(task.toJson()).isChecked,
        isTrue,
      );

      final part = MaintenancePart(
        id: 'part_1',
        reportId: 'report_1',
        partName: 'Air Filter',
        partNumber: 'AF-001',
        quantity: 1,
        unit: 'pcs',
      );
      final restoredPart = MaintenancePart.fromJson(part.toJson());
      expect(restoredPart.partName, 'Air Filter');
      expect(restoredPart.quantity, 1);

      final parameter = MaintenanceParameter(
        id: 'param_1',
        reportId: 'report_1',
        label: 'Running Pressure',
        value: '7.2',
        unit: 'bar',
      );
      final restoredParameter = MaintenanceParameter.fromJson(
        parameter.toJson(),
      );
      expect(restoredParameter.value, '7.2');
      expect(restoredParameter.unit, 'bar');
    });
  });
}
