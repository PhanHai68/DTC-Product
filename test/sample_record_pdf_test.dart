import 'dart:typed_data';

import 'package:dtc_product/models/sample_record.dart';
import 'package:dtc_product/services/sample_record_pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tạo PDF lưu mẫu song ngữ gồm nhiều trang', () async {
    final photoData = await rootBundle.load(
      'assets/images/DTCGroup-Slogan.png',
    );
    final photo = Uint8List.sublistView(photoData);
    final streams = SampleStreamType.values
        .map(
          (type) => SampleStreamData(
            type: type,
            measuredWeightKg: 25,
            seconds: 6,
            sampleWeightGram: 1000,
            defectWeightsGram: const [4, 6, 2, 0, 0],
            photoPath: '/local/${type.name}.jpg',
          ),
        )
        .toList();
    final record = SampleRecordData(
      factoryName: 'Nhà máy Thành Tín',
      tagName: 'SC16PRO-JX26010333',
      machineOperator: 'Kỹ thuật viên A',
      preparedBy: 'Kỹ sư B',
      createdAt: DateTime(2026, 6, 18, 9, 15),
      streams: streams,
      conclusion: 'Đạt',
      note: 'Vận hành ổn định.',
    );

    final bytes = await SampleRecordPdfService.build(
      record: record,
      photos: {for (final type in SampleStreamType.values) type: photo},
    );

    expect(bytes.length, greaterThan(10000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
