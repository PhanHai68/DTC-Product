import 'package:dtc_product/features/projects/models/project.dart';
import 'package:dtc_product/features/projects/models/project_stage.dart';
import 'package:dtc_product/features/projects/models/project_stage_submission.dart';
import 'package:dtc_product/features/projects/services/project_report_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('báo cáo dự án tạo PDF có dữ liệu xác nhận và dấu Verified', () async {
    final now = DateTime(2026, 9, 17, 10, 30);
    final project = Project(
      id: 'p1',
      projectName: 'Phúc Long Factory',
      customerName: 'Phúc Long',
      projectCode: 'PL-2026-001',
      location: 'Long An',
      startDate: now,
      technicalEngineer: 'Kevin',
      createdAt: now,
      updatedAt: now,
    );
    final stages = defaultProjectStageNames.indexed
        .map(
          (entry) => ProjectStage(
            id: 'stage_${entry.$1}',
            projectId: project.id,
            stageName: entry.$2,
            stageOrder: entry.$1,
            status: entry.$1 == 0
                ? ProjectStageStatus.completed
                : ProjectStageStatus.notStarted,
            startDate: entry.$1 == 0 ? now : null,
            completedDate: entry.$1 == 0
                ? now.add(const Duration(hours: 2))
                : null,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
    final submissions = [
      ProjectStageSubmission(
        id: 'submission_1',
        projectId: project.id,
        stageId: stages.first.id,
        submissionType: ProjectSubmissionType.delivery,
        data: const {'photoIds': <String>[]},
        workDate: now,
        result: 'Đã giao máy và đưa vào đúng vị trí tập kết.',
        confirmedBy: 'Kevin',
        confirmedAt: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final bytes = await ProjectReportPdfService.build(
      project: project,
      stages: stages,
      submissions: submissions,
      attachments: const [],
    );

    expect(bytes.length, greaterThan(10000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    final document = PdfDocument(inputBytes: bytes);
    expect(document.pages.count, 5);
    document.dispose();
  });
}
