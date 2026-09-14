import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  var bytes = File(r'assets\docs\HUONG_DAN_VAN_HANH_5.pdf').readAsBytesSync();
  PdfDocument document = PdfDocument(inputBytes: bytes);
  String text = PdfTextExtractor(document).extractText();
  File(r'assets\docs\manual_text.txt').writeAsStringSync(text);
  print("Extracted to manual_text.txt");
  document.dispose();
}
