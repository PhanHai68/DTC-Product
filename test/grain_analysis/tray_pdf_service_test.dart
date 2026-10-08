import 'dart:io';

import 'package:dtc_product/features/grain_analysis/engine/tray_layout.dart';
import 'package:dtc_product/features/grain_analysis/services/tray_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Đặt biến môi trường `GRAIN_TRAY_PDF_OUT=<thư mục>` để ghi luôn các file
/// PDF tấm nền ra thư mục đó (dùng cho giai đoạn 0).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bố cục khay: mốc, nền, vùng rải mẫu, ô trắng không chồng nhau', () {
    for (final l in TrayLayout.printable) {
      final bg = l.backgroundRect;
      final roi = l.roiRect;
      final markers = l.markerRects;
      // Mốc nằm trong trang, cách nền màu một khoảng trắng.
      expect(markers[0].left, l.marginMm);
      expect(markers[2].right, closeTo(l.pageWidthMm - l.marginMm, 1e-9));
      expect(bg.top - markers[0].bottom, l.gapMm);
      expect(markers[3].top - bg.bottom, closeTo(l.gapMm, 1e-9));
      // Vùng rải mẫu nằm trong nền.
      expect(roi.left, greaterThan(bg.left));
      expect(roi.bottom, lessThan(bg.bottom));
      // Ô trắng nằm trong dải trên, giữa hai mốc.
      final patch = l.whitePatchRect;
      expect(patch.left, greaterThan(markers[0].right));
      expect(patch.right, lessThan(markers[1].left));
      expect(patch.bottom, lessThan(bg.top));
    }
    expect(TrayLayout.a4.markerSpacingXMm, 176);
    expect(TrayLayout.a4.markerSpacingYMm, 263);
  });

  test('sinh PDF tấm nền đúng khổ giấy A4 và A3', () async {
    final out = Platform.environment['GRAIN_TRAY_PDF_OUT'];
    for (final layout in TrayLayout.printable) {
      for (final bg in TrayBackground.values) {
        final bytes = await TrayPdfService.build(layout, background: bg);
        expect(bytes.length, greaterThan(1000));
        final doc = PdfDocument(inputBytes: bytes);
        expect(doc.pages.count, 1);
        final size = doc.pages[0].size;
        expect(size.width / (72 / 25.4), closeTo(layout.pageWidthMm, 0.2));
        expect(size.height / (72 / 25.4), closeTo(layout.pageHeightMm, 0.2));
        doc.dispose();
        if (out != null) {
          await Directory(out).create(recursive: true);
          await File('$out/${TrayPdfService.fileName(layout, bg)}')
              .writeAsBytes(bytes);
        }
      }
    }
  });
}
