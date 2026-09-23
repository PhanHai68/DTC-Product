import 'package:dtc_product/features/maintenance_report/models/maintenance_report.dart';
import 'package:dtc_product/features/maintenance_report/services/maintenance_report_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Tên file PDF trùng đúng quy cách với Mã phiên bảo trì', () {
    final now = DateTime(2026, 9, 23);
    final report = MaintenanceReport(
      id: 'report_1',
      customerName: 'ABC Factory',
      maintenanceDate: now,
      sessionId: 'TTM-PLH-ABCFactory-20260923',
      createdAt: now,
      updatedAt: now,
    );

    expect(
      maintenanceReportFileName(report),
      'TTM-PLH-ABCFactory-20260923.pdf',
    );
  });

  test('Tên file PDF vẫn hợp lệ khi chưa có Session ID (dự phòng)', () {
    final now = DateTime(2026, 9, 23);
    final report = MaintenanceReport(
      id: 'report_2',
      customerName: 'ABC Factory',
      maintenanceDate: now,
      createdAt: now,
      updatedAt: now,
    );

    expect(maintenanceReportFileName(report), 'TTM-ABCFactory-20260923.pdf');
  });
}
