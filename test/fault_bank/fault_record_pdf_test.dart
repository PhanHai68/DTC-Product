import 'package:dtc_product/features/fault_bank/models/fault_record.dart';
import 'package:dtc_product/features/fault_bank/services/fault_record_pdf_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

FaultRecord _record({List<SolutionStep>? steps, String cause = 'Kẹt bụi'}) =>
    FaultRecord(
      id: 'KS3F2B9A1C-1',
      machineModelId: 'm1',
      machineModelName: 'SC16 Pro',
      serialNumber: 'CS-01',
      faultGroup: 'ĐIỆN NGUỒN',
      symptom: 'Động cơ quá nhiệt, máy dừng sau 10 phút',
      cause: cause,
      steps:
          steps ??
          const [
            SolutionStep(
              id: 's1',
              order: 1,
              content: 'Ngắt điện',
              photo: FaultAttachment(
                id: 'p1',
                fileName: 'step.png',
                stepId: 's1',
              ),
            ),
            SolutionStep(id: 's2', order: 2, content: 'Vệ sinh quạt'),
          ],
      photos: const [FaultAttachment(id: 'p2', fileName: 'chung.png')],
      parts: 'Quạt 24V',
      tools: 'Tua vít',
      durationMinutes: 45,
      authorCode: 'KS3F2B9A1C',
      authorName: 'An',
      source: FaultRecordSource.mine,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 3),
    );

String _allText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  final text = PdfTextExtractor(document).extractText();
  document.dispose();
  return text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF có đủ mô tả lỗi, nguyên nhân, các bước, vật tư — có ảnh', () async {
    final image = Uint8List.sublistView(
      await rootBundle.load('assets/images/DTCGroup-Slogan.png'),
    );
    final bytes = await FaultRecordPdfService.build(
      _record(),
      photoBytes: {'step.png': image, 'chung.png': image},
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    final text = _allText(bytes);
    for (final expected in [
      'HƯỚNG DẪN KHẮC PHỤC LỖI',
      'SC16 Pro',
      'Tagname: CS-01',
      'MÔ TẢ LỖI',
      'Động cơ quá nhiệt',
      'NGUYÊN NHÂN',
      'CÁC BƯỚC KHẮC PHỤC',
      'Ngắt điện',
      'Vệ sinh quạt',
      'Vật tư cần thay thế',
      'Quạt 24V',
      '0,75 giờ',
      'Người ghi: An',
    ]) {
      expect(text, contains(expected), reason: expected);
    }
    expect(text, isNot(contains('KS3F2B9A1C')));
  });

  test('nội dung dài tự sang trang, thiếu ảnh không lỗi', () async {
    final steps = [
      for (var i = 1; i <= 40; i++)
        SolutionStep(
          id: 's$i',
          order: i,
          content:
              'Bước số $i: kiểm tra và siết lại các đầu cos, đo điện áp '
              'nguồn cấp, ghi lại kết quả vào sổ bảo trì.',
          photo: FaultAttachment(id: 'p$i', fileName: 'mat_$i.jpg'),
        ),
    ];
    final bytes = await FaultRecordPdfService.build(
      _record(steps: steps, cause: 'Nguyên nhân dài. ' * 200),
    );
    final document = PdfDocument(inputBytes: bytes);
    expect(document.pages.count, greaterThan(2));
    document.dispose();
    expect(_allText(bytes), contains('Bước số 40'));
  });

  test('tên file theo model và ngày cập nhật', () {
    expect(
      FaultRecordPdfService.fileName(_record()),
      'KhacPhucLoi_SC16Pro_20261003.pdf',
    );
  });
}
