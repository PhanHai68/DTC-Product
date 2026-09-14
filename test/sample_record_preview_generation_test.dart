import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/models/sample_record.dart';
import 'package:dtc_product/services/sample_record_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generate classification preview', () async {
    const media = 'build/analysis/sample_workbook_media/FORM LUU MAU GAO';
    SampleStreamData stream(
      SampleStreamType type,
      double kg,
      List<double> defects,
      String overview,
      List<(String, String?)> categories,
    ) => SampleStreamData(
      type: type,
      measuredWeightKg: kg,
      seconds: 6,
      sampleWeightGram: 1000,
      defectWeightsGram: defects,
      photoPath: '$media/$overview',
      categoryImages: categories
          .map(
            (item) => SampleCategoryImageData(
              label: item.$1,
              photoPath: item.$2 == null ? null : '$media/${item.$2}',
            ),
          )
          .toList(),
    );
    final streams = [
      stream(SampleStreamType.rawMaterial, 25.5, [4, 14, 0, 0, 0], 'image1.jpeg', [('Hạt tốt', 'image2.jpeg'), ('Vàng, đen hư', 'image3.jpeg'), ('Bạc bụng', 'image4.jpeg')]),
      stream(SampleStreamType.accepted, 25, [3, 9, 0, 0, 0], 'image5.jpeg', [('Hạt tốt', 'image6.jpeg'), ('Vàng, đen hư', 'image7.jpeg'), ('Bạc bụng', 'image8.jpeg')]),
      stream(SampleStreamType.rejected, .5, [820, 110, 20, 6, 0], 'image9.jpeg', [('Hạt tốt', 'image10.jpeg'), ('Hạt phế', 'image11.jpeg'), ('', null)]),
    ];
    final record = SampleRecordData(
      factoryName: 'Nhà máy Thành Tín',
      materialName: 'Gạo',
      tagName: 'SC16PRO-JX26010333',
      machineOperator: 'Đỗ Phạm Hoài Linh',
      preparedBy: 'Nguyễn Cảnh Liêm',
      createdAt: DateTime(2026, 6, 18, 9, 15, 30),
      streams: streams,
      conclusion: 'Máy vận hành ổn định. Chất lượng thành phẩm đáp ứng yêu cầu nghiệm thu của nhà máy.',
      note: 'Tiếp tục theo dõi chất lượng trong ca sản xuất.',
    );
    Future<Uint8List> read(String path) => File(path).readAsBytes();
    final photos = {for (final item in streams) item.type: await read(item.photoPath!)};
    final categoryPhotos = <SampleStreamType, List<Uint8List?>>{};
    for (final item in streams) {
      categoryPhotos[item.type] = [
        for (final category in item.categoryImages)
          category.photoPath == null ? null : await read(category.photoPath!),
      ];
    }
    final bytes = await SampleRecordPdfService.build(record: record, photos: photos, categoryPhotos: categoryPhotos);
    final output = File('build/previews/form-luu-mau-classification-preview.pdf');
    await output.parent.create(recursive: true);
    await output.writeAsBytes(bytes);
  });
}
