import 'package:dtc_product/features/projects/models/project.dart';
import 'package:dtc_product/features/projects/models/project_acceptance.dart';
import 'package:dtc_product/features/projects/models/project_machine.dart';
import 'package:dtc_product/features/projects/models/project_stage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Project tracking models', () {
    test('project progress is derived from completed stages', () {
      final now = DateTime(2026, 9, 17);
      final project = Project(
        id: 'p1',
        projectName: 'Factory',
        customerName: 'Customer',
        projectCode: 'P-001',
        location: 'Long An',
        startDate: now,
        createdAt: now,
        updatedAt: now,
        completedStages: 7,
        totalStages: 14,
      );

      expect(project.progress, .5);
    });

    test('project and nested machine round-trip through json', () {
      final now = DateTime(2026, 9, 17, 8, 30);
      final project = Project(
        id: 'p1',
        projectName: 'Phúc Long Factory',
        customerName: 'Phúc Long',
        projectCode: 'PL-001',
        location: 'Long An',
        startDate: now,
        createdAt: now,
        updatedAt: now,
        machines: [
          ProjectMachine(
            id: 'm1',
            projectId: 'p1',
            machineName: 'SX8-01',
            model: 'SX8',
            serialNumber: 'SX8-2026-001',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      final decoded = Project.fromJson(project.toJson());
      expect(decoded.projectCode, 'PL-001');
      expect(decoded.machines.single.serialNumber, 'SX8-2026-001');
      expect(
        decoded.trackingTitle,
        'DTCG-Theo dõi dự án-SX8-Phúc Long Factory',
      );
    });

    test('default workflow and future acceptance fields are present', () {
      expect(defaultProjectStageNames, [
        'Giao máy',
        'Khui thùng',
        'Lắp đặt',
        'Nghiệm thu',
      ]);
      final now = DateTime(2026, 9, 17);
      final acceptance = ProjectAcceptance(
        id: 'a1',
        projectId: 'p1',
        customerSignature: 'future-customer-signature',
        dtcSignature: 'future-dtc-signature',
        createdAt: now,
        updatedAt: now,
      );
      final decoded = ProjectAcceptance.fromJson(acceptance.toJson());
      expect(decoded.customerSignature, isNotEmpty);
      expect(decoded.dtcSignature, isNotEmpty);
    });
  });
}
