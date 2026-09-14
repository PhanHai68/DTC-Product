import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('Extract PDF to file', () {
    var bytes = File(r'assets\docs\HUONG_DAN_VAN_HANH_5.pdf').readAsBytesSync();
    PdfDocument document = PdfDocument(inputBytes: bytes);
    String text = PdfTextExtractor(document).extractText();
    File(r'assets\docs\manual_text.txt').writeAsStringSync(text);
    document.dispose();
  });
}
