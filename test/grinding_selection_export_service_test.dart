import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_selection_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PDF tạo thành công, có đủ Project info + Selected Machine, thiếu spec hiện —, null không thành 0',
    () async {
      final now = DateTime(2026, 9, 24, 15, 30);
      final project = GrindingSelectionProject(
        id: 1,
        projectName: 'Trà xanh Bảo Lộc',
        customerName: 'Công ty ABC',
        materialName: 'Trà xanh',
        requiredCapacityKgH: 500,
        requiredFinenessValue: 20,
        requiredFinenessUnit: 'µm',
        // feedSizeMm/maxMotorKw/application để trống (null) có chủ đích.
        status: GrindingProjectStatus.selected,
        createdAt: now,
        updatedAt: now,
      );

      const selectedMachine = GrindingMachine(
        machineId: 'BSP_ULTRAFINE__ASP-350',
        seriesCode: 'BSP_ULTRAFINE',
        model: 'ASP-350',
        capacityMinKgH: 300,
        capacityMaxKgH: 500,
        // finenessMin/Max/mainMotorKw để trống (null) có chủ đích — phải
        // hiện "—" trong PDF, KHÔNG được hiện "0".
      );

      final bytes = await GrindingSelectionExportService.buildPdf(
        project: project,
        selectedMachine: selectedMachine,
        selectedSeries: null,
      );

      // File PDF được tạo (đúng header %PDF, có nội dung thật).
      expect(bytes.length, greaterThan(500));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');

      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      // Project info.
      expect(text, contains('DTC Product'));
      expect(text, contains('Grinding Machine Selection Report'));
      expect(text, contains('Trà xanh Bảo Lộc'));
      expect(text, contains('Công ty ABC'));

      // Customer requirements — có dữ liệu.
      expect(text, contains('500 kg/h'));
      expect(text, contains('20 µm'));

      // Selected machine.
      expect(text, contains('SELECTED MACHINE'));
      expect(text, contains('ASP-350'));

      // Null không được biến thành 0 — "—" phải xuất hiện (feed size/motor
      // của project VÀ fineness/motor của selected machine đều thiếu).
      expect(text, contains('—'));
      expect(text, isNot(contains(' 0 kg/h')));
      expect(text, isNot(contains(' 0 kW')));
    },
  );

  test('Không có selected machine -> hiện "No machine selected", không crash', () async {
    final now = DateTime(2026, 9, 24, 15, 30);
    final project = GrindingSelectionProject(
      projectName: 'Dự án chưa chọn máy',
      createdAt: now,
      updatedAt: now,
    );

    final bytes = await GrindingSelectionExportService.buildPdf(project: project);

    expect(bytes.length, greaterThan(500));
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    expect(text, contains('No machine selected'));
  });

  test('Comparison table chỉ xuất hiện khi có >= 2 model, model thiếu spec hiện —', () async {
    final now = DateTime(2026, 9, 24, 15, 30);
    final project = GrindingSelectionProject(
      projectName: 'So sánh 2 model',
      createdAt: now,
      updatedAt: now,
    );
    const machineA = GrindingMachine(
      machineId: 'A',
      seriesCode: 'S1',
      model: 'ASC-200',
      capacityMinKgH: 80,
      capacityMaxKgH: 300,
    );
    const machineB = GrindingMachine(
      machineId: 'B',
      seriesCode: 'S1',
      model: 'ASC-300',
      // capacity để trống có chủ đích.
    );

    final bytes = await GrindingSelectionExportService.buildPdf(
      project: project,
      comparisonMachines: const [machineA, machineB],
    );

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    expect(text, contains('COMPARISON'));
    expect(text, contains('ASC-200'));
    expect(text, contains('ASC-300'));
    expect(text, contains('—'));
  });
}
