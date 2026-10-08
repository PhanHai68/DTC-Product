import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../engine/tray_layout.dart';

/// Màu nền tấm khay — chọn màu tương phản với hạt.
enum TrayBackground {
  navy('Xanh dương đậm', 'Gạo trắng, hạt điều, đậu sáng màu', 22, 42, 112),
  black('Đen', 'Gạo trắng, hạt sáng màu', 24, 24, 24),
  white('Trắng', 'Cà phê, đậu đen, hạt sẫm màu', 255, 255, 255);

  const TrayBackground(this.label, this.hint, this.r, this.g, this.b);

  final String label;
  final String hint;
  final int r;
  final int g;
  final int b;
}

/// Sinh file PDF tấm nền chuẩn đúng kích thước [TrayLayout] — in tỉ lệ
/// 100% (Actual size) để khoảng cách giữa các mốc khớp với thuật toán.
abstract final class TrayPdfService {
  static const _ptPerMm = 72 / 25.4;

  static String fileName(TrayLayout layout, TrayBackground background) =>
      'DTC_Khay_chuan_${layout.name}_${background.name}.pdf';

  static Future<Uint8List> build(
    TrayLayout layout, {
    TrayBackground background = TrayBackground.navy,
  }) async {
    final regular = PdfTrueTypeFont(
      (await rootBundle.load('assets/fonts/Roboto-Regular.ttf')).buffer
          .asUint8List(),
      7,
    );
    final bold = PdfTrueTypeFont(
      (await rootBundle.load('assets/fonts/Roboto-Bold.ttf')).buffer
          .asUint8List(),
      8,
    );
    final document = PdfDocument();
    document.pageSettings
      ..size = ui.Size(
        layout.pageWidthMm * _ptPerMm,
        layout.pageHeightMm * _ptPerMm,
      )
      ..margins.all = 0;
    final page = document.pages.add();
    final g = page.graphics;
    ui.Rect rect(MmRect r) => ui.Rect.fromLTRB(
      r.left * _ptPerMm,
      r.top * _ptPerMm,
      r.right * _ptPerMm,
      r.bottom * _ptPerMm,
    );
    ui.Offset pt(double x, double y) => ui.Offset(x * _ptPerMm, y * _ptPerMm);
    final black = PdfSolidBrush(PdfColor(0, 0, 0));
    final white = PdfSolidBrush(PdfColor(255, 255, 255));
    final ink = PdfColor(60, 70, 80);
    final inkBrush = PdfSolidBrush(ink);

    // Nền màu.
    final bg = layout.backgroundRect;
    g.drawRectangle(
      brush: PdfSolidBrush(PdfColor(background.r, background.g, background.b)),
      pen: background == TrayBackground.white
          ? PdfPen(PdfColor(200, 205, 210), width: 0.5)
          : null,
      bounds: rect(bg),
    );

    // Khung vùng rải mẫu: vẽ lùi ra ngoài 1,5 mm để nét đứt không lọt vào
    // vùng phân tích (sẽ bị đếm nhầm thành vật thể chạm mép).
    final dashColor = background == TrayBackground.white
        ? PdfColor(150, 160, 170)
        : PdfColor(150, 165, 200);
    g.drawRectangle(
      pen: PdfPen(dashColor, width: 0.4 * _ptPerMm)
        ..dashStyle = PdfDashStyle.dash,
      bounds: rect(layout.roiRect.inflate(1.5)),
    );

    // Bốn mốc góc: vuông đen, ô trắng ở giữa.
    for (final m in layout.markerRects) {
      g.drawRectangle(brush: black, bounds: rect(m));
      final h = layout.markerHoleMm / 2;
      g.drawRectangle(
        brush: white,
        bounds: rect(
          MmRect(m.centerX - h, m.centerY - h, m.centerX + h, m.centerY + h),
        ),
      );
    }

    // Ô trắng chuẩn (viền mảnh) + hướng dẫn ở dải trên.
    final patch = layout.whitePatchRect;
    g.drawRectangle(
      pen: PdfPen(PdfColor(190, 196, 202), width: 0.3),
      bounds: rect(patch),
    );
    final topTextLeft = patch.right + 4;
    final topTextRight = layout.markerRects[1].left - 3;
    final topWidth = (topTextRight - topTextLeft) * _ptPerMm;
    g.drawString(
      'Ô trắng chuẩn (bên trái): giữ sạch, không che, không đặt hạt.',
      regular,
      brush: inkBrush,
      bounds: ui.Rect.fromLTWH(
        topTextLeft * _ptPerMm,
        (patch.top + 1) * _ptPerMm,
        topWidth,
        14,
      ),
    );
    g.drawString(
      'Rải mẫu MỘT LỚP, hạt nằm gọn trong khung nét đứt. Chụp thẳng từ trên '
      'xuống, thấy đủ 4 mốc đen.',
      regular,
      brush: inkBrush,
      bounds: ui.Rect.fromLTWH(
        topTextLeft * _ptPerMm,
        (patch.top + 5) * _ptPerMm,
        topWidth,
        24,
      ),
    );

    // Dải dưới: tiêu đề + thước kiểm tra tỉ lệ in (nằm bên trái, tránh vùng
    // đối xứng của ô trắng khi khay bị xoay 180°).
    final bottomTop = layout.markerRects[3].top;
    final left = layout.markerRects[3].right + 6;
    g.drawString(
      'DTC — KHAY CHUẨN PHÂN TÍCH MẪU ${layout.name} — IN ĐÚNG TỈ LỆ 100%',
      bold,
      brush: inkBrush,
      bounds: ui.Rect.fromLTWH(
        left * _ptPerMm,
        (bottomTop + 0.5) * _ptPerMm,
        110 * _ptPerMm,
        12,
      ),
    );
    const rulerMm = 80.0;
    final rulerY = bottomTop + layout.markerSizeMm * 0.55;
    final pen = PdfPen(ink, width: 0.6);
    g.drawLine(pen, pt(left, rulerY), pt(left + rulerMm, rulerY));
    for (var i = 0; i <= rulerMm; i += 5) {
      final tick = i % 10 == 0 ? 2.2 : 1.2;
      g.drawLine(
        PdfPen(ink, width: 0.4),
        pt(left + i, rulerY - tick),
        pt(left + i, rulerY),
      );
    }
    g.drawString(
      'Thước kiểm tra: đo đoạn này phải đúng 80 mm',
      regular,
      brush: inkBrush,
      bounds: ui.Rect.fromLTWH(
        left * _ptPerMm,
        (rulerY + 1) * _ptPerMm,
        rulerMm * _ptPerMm,
        12,
      ),
    );

    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return bytes;
  }
}
