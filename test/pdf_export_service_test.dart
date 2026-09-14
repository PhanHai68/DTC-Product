import 'package:dtc_product/data/aux_equip_data.dart';
import 'package:dtc_product/data/specs_data.dart';
import 'package:dtc_product/services/pdf_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'catalog PDF A4 có đủ công nghệ, ứng dụng, liên hệ và địa chỉ',
    () async {
      final specs = colorSorterSpecs.first;
      final bytes = await DtcPdfExportService.buildColorSorterCatalog(
        specs: specs,
        contactName: 'Phan Hải',
        contactPhone: '0945 989 028',
        machineImagePath: 'assets/images/color_sorter/sc12_pro.png',
      );
      expect(bytes.length, greaterThan(10000));
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      expect(document.pages.count, 1);
      expect(text, contains('MÁY TÁCH MÀU SC16 PRO'));
      expect(text, contains('6 ĐẶC TÍNH CÔNG NGHỆ'));
      expect(text, contains('CHI TIẾT ỨNG DỤNG'));
      expect(text, contains('Trụ sở chính'));
      expect(text, contains('Số 86, Đường 65'));
      expect(text, contains('Phan Hải'));
      expect(text, isNot(contains('Lưu lượng khí')));
      document.dispose();
    },
  );

  test('PDF thiết bị phụ trợ có đủ bốn cột và dòng cuối danh sách', () async {
    final bytes = await DtcPdfExportService.buildAuxEquipmentCatalog(
      model: 'SC16',
      items: auxEquipSpecsByModel['SC16']!,
    );

    expect(bytes.length, greaterThan(5000));
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    expect(text, contains('DANH SÁCH THIẾT BỊ PHỤ TRỢ'));
    expect(text, contains('Quy cách tham khảo'));
    expect(text, contains('Đường ống lắp đặt cụm máy'));
    expect(text, contains('2. Hệ thống nén khí'));
    document.dispose();
  });
}
