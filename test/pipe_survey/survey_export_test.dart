import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/services/air_po_excel.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:dtc_product/features/pipe_survey/providers/pipe_survey_controller.dart';
import 'package:dtc_product/features/pipe_survey/services/survey_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<PoTemplate> _template() =>
    PoTemplate.load((path) async => File(path).readAsBytesSync());

PipeSurvey _sample() {
  final s = PipeSurvey(name: 'Nhà máy gạo A', hangHeightM: 4.5);
  final mn = SurveyNode(x: 2, y: 2, kind: SurveyNodeKind.compressor);
  final b = SurveyNode(x: 12, y: 2);
  final u = SurveyNode(
    x: 12,
    y: 8,
    kind: SurveyNodeKind.usePoint,
    name: 'Máy 1',
  );
  s.nodes.addAll([mn, b, u]);
  s.segments
    ..add(SurveySegment(a: mn.id, b: b.id))
    ..add(SurveySegment(a: b.id, b: u.id));
  s.shapes.add(
    SurveyShape(kind: SurveyShapeKind.area, x1: 6, y1: 6, label: 'Xưởng sấy'),
  );
  return s;
}

void main() {
  final ctrl = PipeSurveyController(
    survey: _sample(),
    constants: pipeSurveyConstants,
  );

  test('phiếu đề nghị vật tư: form PO như Cấu hình khí nén, một mục vật tư '
      'ngoại tuyến', () async {
    final rows = ctrl.materialRows;
    expect(rows, isNotEmpty);
    final doc = SurveyExportService.poDocument(
      ctrl.survey,
      rows,
      now: DateTime(2026, 10, 31),
    );
    expect(doc.equipment, isEmpty);
    expect(doc.sections.single.title, contains('VẬT TƯ TỪ CỤM MÁY'));
    expect(doc.sections.single.lines, hasLength(rows.length));
    expect(doc.projectTitle, contains('Nhà máy gạo A'));

    final file = SurveyExportService.po(
      await _template(),
      ctrl.survey,
      rows,
      base: 'KS',
      requester: const PoRequester(requester: 'Hải'),
    );
    expect(file.name, 'KS_DeNghiVatTu.xlsx');
    final archive = ZipDecoder().decodeBytes(file.bytes);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    // Cùng tiêu đề, cột và chữ ký như form PO.
    expect(sheet, contains('ĐỀ NGHỊ VẬT TƯ'));
    expect(sheet, contains('Nhà máy gạo A'));
    expect(sheet, contains(rows.first.name));
    expect(sheet, contains('Hải'));

    final merged = SurveyExportService.po(
      await _template(),
      ctrl.survey,
      rows,
      base: 'KS',
      merged: true,
    );
    expect(merged.name, 'KS_DeNghiVatTu_GopMa.xlsx');
  });

  testWidgets('sơ đồ: PNG và PDF A3', (tester) async {
    await tester.runAsync(() async {
      final png = await SurveyExportService.png(ctrl.survey, ctrl.plants, 'KS');
      expect(png.name, 'KS_SoDo.png');
      // Chữ ký file PNG.
      expect(png.bytes.sublist(1, 4), utf8.encode('PNG'));
      final pdf = await SurveyExportService.pdf(ctrl.survey, ctrl.plants, 'KS');
      expect(pdf.name, 'KS_SoDo.pdf');
      expect(utf8.decode(pdf.bytes.sublist(0, 4)), '%PDF');
    });
  });
}
