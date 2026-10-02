import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:dtc_product/features/site_layout/models/site_layout_models.dart';
import 'package:dtc_product/features/site_layout/services/site_layout_image_service.dart';
import 'package:dtc_product/features/site_layout/services/site_layout_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 9, 25);
  final bundle = SiteLayoutBundle(
    project: SiteLayoutProject(
      id: 'project_export',
      name: 'Nhà máy thử nghiệm',
      customer: 'Khách hàng DTC',
      location: 'Cần Thơ',
      surveyor: 'Kỹ sư DTC',
      surveyDate: now,
      siteWidthMm: 10000,
      siteLengthMm: 8000,
      ceilingHeightMm: 5000,
      notes: 'Khảo sát bố trí dây chuyền.',
      createdAt: now,
      updatedAt: now,
    ),
    layout: SiteLayoutVariant(
      id: 'layout_a',
      projectId: 'project_export',
      name: 'Phương án A',
      isPreferred: true,
      createdAt: now,
      updatedAt: now,
    ),
    objects: const [
      SiteLayoutObject(
        id: 'wall_1',
        layoutId: 'layout_a',
        type: SiteObjectType.wall,
        xMm: 500,
        yMm: 4925,
        widthMm: 3500,
        lengthMm: 150,
        rotationDeg: 12,
        label: 'Tường',
      ),
      SiteLayoutObject(
        id: 'door_1',
        layoutId: 'layout_a',
        type: SiteObjectType.door,
        xMm: 4200,
        yMm: 4500,
        widthMm: 1200,
        lengthMm: 120,
        rotationDeg: 35,
        label: 'Cửa',
      ),
      SiteLayoutObject(
        id: 'column_1',
        layoutId: 'layout_a',
        type: SiteObjectType.column,
        xMm: 6500,
        yMm: 1800,
        widthMm: 500,
        lengthMm: 600,
        rotationDeg: 20,
        label: 'Cột',
      ),
      SiteLayoutObject(
        id: 'restricted_1',
        layoutId: 'layout_a',
        type: SiteObjectType.restrictedArea,
        xMm: 6500,
        yMm: 4200,
        widthMm: 1800,
        lengthMm: 1200,
        label: 'Vùng cấm',
      ),
    ],
    machines: const [
      MachinePlacement(
        id: 'machine_asp',
        layoutId: 'layout_a',
        sourceType: 'grinding',
        sourceId: 'asp-1000',
        category: 'Máy nghiền',
        model: 'ASP-1000',
        displayName: 'ASP-1000 · Máy nghiền siêu mịn',
        xMm: 1200,
        yMm: 1600,
        lengthMm: 2200,
        widthMm: 1200,
        heightMm: 2300,
        clearanceFrontMm: 800,
        clearanceRearMm: 600,
        clearanceLeftMm: 500,
        clearanceRightMm: 500,
        clearanceTopMm: 600,
        clearanceVerified: true,
      ),
    ],
    measurements: const [
      LayoutMeasurement(
        id: 'measure_1',
        layoutId: 'layout_a',
        x1Mm: 0,
        y1Mm: 0,
        x2Mm: 3000,
        y2Mm: 4000,
      ),
    ],
  );

  testWidgets('xuất PNG toàn bộ mặt bằng, không phụ thuộc viewport', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => SiteLayoutImageService.buildPng(bundle),
    );
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(1000));
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  testWidgets('PDF có logo, thông tin dự án và tên máy tiếng Việt', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => SiteLayoutPdfService.build(bundle),
    );
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.take(4)), '%PDF');
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    expect(text, contains('Nhà máy thử nghiệm'));
    expect(text, contains('ASP-1000'));
    expect(text, contains('BÁO CÁO KHẢO SÁT'));
    expect(text, contains('10 × 8 m'));
    final layoutPageSize = document.pages[1].getClientSize();
    expect(layoutPageSize.width, greaterThan(layoutPageSize.height));
    document.dispose();
  });

  testWidgets('trang sơ đồ PDF dọc khi chiều dài lớn hơn chiều rộng', (
    tester,
  ) async {
    final portraitBundle = bundle.copyWith(
      project: bundle.project.copyWith(siteWidthMm: 8000, siteLengthMm: 10000),
    );
    final bytes = await tester.runAsync(
      () => SiteLayoutPdfService.build(portraitBundle),
    );
    final document = PdfDocument(inputBytes: bytes!);
    final layoutPageSize = document.pages[1].getClientSize();
    expect(layoutPageSize.height, greaterThan(layoutPageSize.width));
    document.dispose();
  });
}
