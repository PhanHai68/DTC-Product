import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../air_system_config/pipe/material_list.dart';
import '../../air_system_config/services/air_config_export_service.dart'
    show AirConfigExportService, AirExportFile;
import '../../air_system_config/services/air_po_excel.dart';
import '../../air_system_config/services/air_po_pdf.dart';
import '../engine/survey_plant.dart';
import '../models/pipe_survey.dart';
import '../widgets/survey_canvas.dart';

/// Xuất Khảo sát vật tư ngoại tuyến: sơ đồ (PNG / PDF A3 ngang) và phiếu
/// "Đề nghị vật tư" (Excel / PDF) cùng form PO với Cấu hình hệ thống khí nén.
abstract final class SurveyExportService {
  static String baseName(PipeSurvey s, DateTime now) {
    final name = s.name.trim().isEmpty
        ? 'KhaoSatVatTu'
        : s.name
              .trim()
              .replaceAll(RegExp(r'[^A-Za-z0-9À-ỹ_-]+'), '_')
              .replaceAll(RegExp(r'_+'), '_');
    return 'DTC_${name}_${DateFormat('yyyyMMdd_HHmm').format(now)}';
  }

  /// Vùng có nội dung trên sơ đồ (m): điểm, hình nền, cụm máy, tường bao.
  static ui.Rect contentBounds(
    PipeSurvey s,
    Map<String, SurveyPlantLayout> plants,
  ) {
    ui.Rect? r;
    void add(ui.Rect b) => r = r == null ? b : r!.expandToInclude(b);
    for (final n in s.nodes) {
      add(ui.Rect.fromLTWH(n.x, n.y, 0, 0));
    }
    for (final h in s.shapes) {
      add(ui.Rect.fromPoints(ui.Offset(h.x1, h.y1), ui.Offset(h.x2, h.y2)));
    }
    for (final p in plants.values) {
      add(p.bounds);
    }
    final bl = s.buildingLengthM, bw = s.buildingWidthM;
    if (bl != null && bw != null && bl > 0 && bw > 0) {
      add(ui.Rect.fromLTWH(0, 0, bl, bw));
    }
    return r ?? const ui.Rect.fromLTWH(0, 0, 20, 12);
  }

  /// Ảnh sơ đồ: vùng có nội dung + lề, lưới mét, khung tên góc dưới phải.
  /// [ppm] px / m (tự giảm để cạnh dài không quá [maxSide] px).
  static Future<Uint8List> diagramPng(
    PipeSurvey s,
    Map<String, SurveyPlantLayout> plants, {
    double ppm = 40,
    double maxSide = 7000,
  }) async {
    final b = contentBounds(s, plants);
    // Gốc nguyên mét để lưới khớp; lề 2 m (chữ, nhãn), dưới chừa khung tên.
    final left = (b.left - 2).floorToDouble();
    final top = (b.top - 2).floorToDouble();
    var widthM = (b.right + 2).ceilToDouble() - left;
    var heightM = (b.bottom + 2).ceilToDouble() - top;
    final scale = math.min(ppm, maxSide / math.max(widthM, heightM));
    // Khung tên 300 × 92 px + lề: không đè lên nội dung.
    widthM = math.max(widthM, 340 / scale);
    heightM += 120 / scale;
    final size = ui.Size(widthM * scale, heightM * scale);
    final recorder = ui.PictureRecorder();
    SurveyPainter(
      survey: s,
      ppm: scale,
      widthM: widthM,
      heightM: heightM,
      plants: plants,
      originM: ui.Offset(-left, -top),
    ).paint(ui.Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(
      size.width.ceil(),
      size.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<AirExportFile> png(
    PipeSurvey s,
    Map<String, SurveyPlantLayout> plants,
    String base,
  ) async => AirExportFile(
    '${base}_SoDo.png',
    'image/png',
    await diagramPng(s, plants),
  );

  /// Sơ đồ trên một trang PDF A3 ngang: logo, tên bản vẽ, công trình, ngày;
  /// sơ đồ căn giữa giữ tỉ lệ.
  static Future<AirExportFile> pdf(
    PipeSurvey s,
    Map<String, SurveyPlantLayout> plants,
    String base,
  ) async {
    Future<Uint8List> asset(String path) async =>
        Uint8List.sublistView(await rootBundle.load(path));
    final png = await diagramPng(s, plants, ppm: 60);
    final regular = await asset('assets/fonts/Roboto-Regular.ttf');
    final boldBytes = await asset('assets/fonts/Roboto-Bold.ttf');
    final logo = await asset('assets/images/DTCGroup-Slogan.png');
    final navy = PdfColor(10, 39, 64);
    final green = PdfColor(20, 129, 71);
    final muted = PdfColor(96, 119, 134);

    final document = PdfDocument();
    document.pageSettings
      ..size = PdfPageSize.a3
      ..orientation = PdfPageOrientation.landscape
      ..margins.all = 0;
    final page = document.pages.add();
    final g = page.graphics;
    final size = page.getClientSize();
    const margin = 28.0;
    final width = size.width - 2 * margin;
    g.drawRectangle(
      brush: PdfSolidBrush(green),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, 7),
    );
    const logoH = 44.0;
    g.drawImage(
      PdfBitmap(logo),
      ui.Rect.fromLTWH(margin, 16, logoH * 2048 / 713, logoH),
    );
    final center = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );
    g.drawString(
      s.drawingTitleOrDefault.toUpperCase(),
      PdfTrueTypeFont(boldBytes, 20),
      brush: PdfSolidBrush(navy),
      bounds: ui.Rect.fromLTWH(margin, 14, width, 28),
      format: center,
    );
    if (s.name.trim().isNotEmpty) {
      g.drawString(
        s.name.trim(),
        PdfTrueTypeFont(regular, 12),
        brush: PdfSolidBrush(muted),
        bounds: ui.Rect.fromLTWH(margin, 42, width, 18),
        format: center,
      );
    }
    g.drawString(
      'Ngày khảo sát: ${DateFormat('dd/MM/yyyy').format(s.surveyDate)}',
      PdfTrueTypeFont(regular, 11),
      brush: PdfSolidBrush(muted),
      bounds: ui.Rect.fromLTWH(margin, 20, width, 18),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.right,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
    g.drawLine(
      PdfPen(PdfColor(220, 231, 235), width: 0.7),
      const ui.Offset(margin, 70),
      ui.Offset(size.width - margin, 70),
    );
    final image = PdfBitmap(png);
    const top = 80.0;
    final availH = size.height - margin - top;
    final k = math.min(width / image.width, availH / image.height);
    final w = image.width * k, h = image.height * k;
    g.drawImage(
      image,
      ui.Rect.fromLTWH(margin + (width - w) / 2, top + (availH - h) / 2, w, h),
    );
    final bytes = Uint8List.fromList(await document.save());
    document.dispose();
    return AirExportFile('${base}_SoDo.pdf', 'application/pdf', bytes);
  }

  // ── Đề nghị vật tư (form PO) ────────────────────────────────────────────

  /// Phiếu đề nghị vật tư: một mục "Vật tư từ cụm máy đến thiết bị sử dụng
  /// khí nén" gồm danh sách vật tư đã sửa tay như trên app.
  static PoDocument poDocument(
    PipeSurvey s,
    List<MaterialRow> rows, {
    DateTime? now,
  }) {
    String cap(String v) => v.isEmpty ? v : v[0].toUpperCase() + v.substring(1);
    final name = s.name.trim();
    return PoDocument(
      projectTitle: [
        'Vật tư ngoại tuyến hệ thống khí nén',
        if (name.isNotEmpty) name,
      ].join(' – '),
      date: DateFormat('dd/MM/yyyy').format(now ?? DateTime.now()),
      equipment: const [],
      sections: [
        PoSection(
          title: 'VẬT TƯ TỪ CỤM MÁY ĐẾN THIẾT BỊ SỬ DỤNG KHÍ NÉN',
          band: PoBand.blue,
          numbered: rows.isNotEmpty,
          lines: rows.isEmpty
              ? const [
                  PoLine(name: 'Chưa có vật tư — vẽ tuyến ống ở tab Sơ đồ.'),
                ]
              : [
                  for (final r in rows)
                    PoLine(
                      code: r.code,
                      name: r.name,
                      unit: cap(r.unit),
                      qty: r.qty,
                      spec: r.spec,
                    ),
                ],
        ),
      ],
    );
  }

  static AirExportFile po(
    PoTemplate template,
    PipeSurvey s,
    List<MaterialRow> rows, {
    required String base,
    DateTime? now,
    bool merged = false,
    PoRequester requester = const PoRequester(),
  }) {
    final doc = poDocument(s, rows, now: now).withRequester(requester);
    return AirExportFile(
      '${base}_DeNghiVatTu${merged ? '_GopMa' : ''}.xlsx',
      AirConfigExportService.excelMime,
      buildPoWorkbook(template, merged ? doc.merged() : doc),
    );
  }

  static Future<AirExportFile> poPdf(
    PoTemplate template,
    PipeSurvey s,
    List<MaterialRow> rows, {
    required String base,
    DateTime? now,
    bool merged = false,
    PoRequester requester = const PoRequester(),
  }) async {
    Future<Uint8List> asset(String path) async =>
        Uint8List.sublistView(await rootBundle.load(path));
    final doc = poDocument(s, rows, now: now).withRequester(requester);
    return AirExportFile(
      '${base}_DeNghiVatTu${merged ? '_GopMa' : ''}.pdf',
      'application/pdf',
      buildPoPdf(
        merged ? doc.merged() : doc,
        company: template.company,
        regular: await asset('assets/fonts/Roboto-Regular.ttf'),
        bold: await asset('assets/fonts/Roboto-Bold.ttf'),
        logo: await asset('assets/images/DTCGroup-Slogan.png'),
      ),
    );
  }
}
