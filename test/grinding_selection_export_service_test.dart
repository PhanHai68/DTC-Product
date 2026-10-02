import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine_match.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_selection_project.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_series.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_selection_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF tạo thành công, có đủ Project info + Selected Machine, thiếu spec hiện —, null không thành 0', () async {
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
      machineId: 'ASP_ULTRAFINE__ASP-350',
      seriesCode: 'ASP_ULTRAFINE',
      model: 'ASP-350',
      capacityMinKgH: 300,
      capacityMaxKgH: 500,
      // finenessMin/Max/mainMotorKw để trống (null) có chủ đích — phải
      // hiện "—" trong PDF, KHÔNG được hiện "0".
    );
    const selectedSeries = GrindingSeries(
      seriesCode: 'ASP_ULTRAFINE',
      displayCode: 'ASP',
        nameVi: 'Máy nghiền siêu mịn',
    );

    final bytes = await GrindingSelectionExportService.buildPdf(
      project: project,
      selectedMachine: selectedMachine,
      selectedSeries: selectedSeries,
    );

    // File PDF được tạo (đúng header %PDF, có nội dung thật).
    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    // Project info.
    expect(text, contains('DTC PRODUCT'));
    expect(text, contains('BÁO CÁO LỰA CHỌN MÁY NGHIỀN'));
    expect(text, contains('Trà xanh Bảo Lộc'));
    expect(text, contains('Công ty ABC'));

    // Customer requirements — có dữ liệu.
    expect(text, contains('500 kg/h'));
    expect(text, contains('20 µm'));

    // Selected machine.
    expect(text, contains('IV. MÁY ĐÃ CHỌN'));
    expect(text, contains('ASP-350'));
      expect(text, contains('Máy nghiền siêu mịn'));

    // Null không được biến thành 0 — "—" phải xuất hiện (feed size/motor
    // của project VÀ fineness/motor của selected machine đều thiếu).
    expect(text, contains('—'));
    expect(text, isNot(contains(' 0 kg/h')));
    expect(text, isNot(contains(' 0 kW')));
  });

  test(
    'Không có selected machine -> hiện "Chưa chọn máy", không crash',
    () async {
      final now = DateTime(2026, 9, 24, 15, 30);
      final project = GrindingSelectionProject(
        projectName: 'Dự án chưa chọn máy',
        createdAt: now,
        updatedAt: now,
      );

      final bytes = await GrindingSelectionExportService.buildPdf(
        project: project,
      );

      expect(bytes.length, greaterThan(500));
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('Chưa chọn máy'));
    },
  );

  test(
    'Comparison table chỉ xuất hiện khi có >= 2 model, model thiếu spec hiện —',
    () async {
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
        seriesByCode: const {
          'S1': GrindingSeries(
            seriesCode: 'S1',
            displayCode: 'ASC',
            nameVi: 'nghiền thô',
          ),
        },
      );

      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      document.dispose();

      expect(text, contains('V. SO SÁNH MÁY'));
      expect(text, contains('ASC-200'));
      expect(text, contains('ASC-300'));
      expect(text, contains('nghiền thô'));
      expect(text, contains('—'));
    },
  );

  test('Bảng đề xuất phân biệt model AS bằng tên máy tiếng Việt', () async {
    final now = DateTime(2026, 9, 24, 15, 30);
    final project = GrindingSelectionProject(
      projectName: 'Phân biệt model AS',
      createdAt: now,
      updatedAt: now,
    );
    const smallHammer = GrindingSeries(
      seriesCode: 'AS_SMALL_HAMMER',
      displayCode: 'AS',
      nameVi: 'Máy nghiền búa cỡ nhỏ',
    );
    const highEfficiency = GrindingSeries(
      seriesCode: 'ASF_AS_HAMMER',
      displayCode: 'ASF/AS',
      nameVi: 'Máy nghiền hiệu suất cao',
    );
    const as180 = GrindingMachine(
      machineId: 'AS_SMALL_HAMMER__AS-180',
      seriesCode: 'AS_SMALL_HAMMER',
      model: 'AS-180',
    );
    const as200 = GrindingMachine(
      machineId: 'ASF_AS_HAMMER__AS-200',
      seriesCode: 'ASF_AS_HAMMER',
      model: 'AS-200',
    );

    final bytes = await GrindingSelectionExportService.buildPdf(
      project: project,
      recommendations: const [
        GrindingMachineMatch(
          machine: as180,
          series: smallHammer,
          criteria: [],
          matchScore: 100,
          label: GrindingMatchLabel.strong,
        ),
        GrindingMachineMatch(
          machine: as200,
          series: highEfficiency,
          criteria: [],
          matchScore: 80,
          label: GrindingMatchLabel.possible,
        ),
      ],
    );

    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    document.dispose();

    expect(text, contains('III. MÁY ĐƯỢC ĐỀ XUẤT'));
    expect(text, contains('MODEL / TÊN MÁY'));
    expect(text, contains('AS-180'));
    expect(text, contains('Máy nghiền búa cỡ nhỏ'));
    expect(text, contains('AS-200'));
    expect(text, contains('Máy nghiền hiệu suất cao'));
    expect(text, contains('Phù hợp cao'));
    expect(text, contains('Có thể phù hợp'));
  });
}
