import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_bom.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sơ đồ mẫu (m):
///
///   C(0,0) ──10── P1(10,0) ──10── J1(20,0)
///                                   │ 5
///                                 J2(20,5) ──10 (DN25)── P3(30,5)
///                                   │ 5
///                                 P2(20,10)
///
/// Ống chính DN50; nhánh tới P3 DN25. Treo ống 4,5 m, đầu nối 2,5 m →
/// mỗi điểm sử dụng ống đứng 2 m.
PipeSurvey _sample() {
  final c = SurveyNode(id: 'C', x: 0, y: 0, kind: SurveyNodeKind.compressor);
  final p1 = SurveyNode(
    id: 'P1',
    x: 10,
    y: 0,
    kind: SurveyNodeKind.usePoint,
    name: 'Máy tách màu 1',
  );
  final j1 = SurveyNode(id: 'J1', x: 20, y: 0);
  final j2 = SurveyNode(id: 'J2', x: 20, y: 5);
  final p2 = SurveyNode(id: 'P2', x: 20, y: 10, kind: SurveyNodeKind.usePoint);
  final p3 = SurveyNode(id: 'P3', x: 30, y: 5, kind: SurveyNodeKind.usePoint);
  return PipeSurvey(
    name: 'Nhà máy gạo A',
    hangHeightM: 4.5,
    defaultDn: 50,
    nodes: [c, p1, j1, j2, p2, p3],
    segments: [
      SurveySegment(a: 'C', b: 'P1'),
      SurveySegment(a: 'P1', b: 'J1'),
      SurveySegment(a: 'J1', b: 'J2'),
      SurveySegment(a: 'J2', b: 'P2'),
      SurveySegment(a: 'J2', b: 'P3', dn: 25),
    ],
  );
}

Map<String, num> _qty(SurveyBom b) => {for (final l in b.lines) l.key: l.qty};

void main() {
  test('quy tắc khảo sát đọc từ pipe_survey_constants.json', () {
    final c = pipeSurveyConstants;
    expect(
      [c.barLengthM, c.reservePercent, c.defaultConnectionHeightM],
      [6, 15, 2.5],
    );
    expect(c.clampSpacingFor(25), 2.0);
    expect(c.clampSpacingFor(50), 2.5);
    expect(c.clampSpacingFor(65), 3.0);
    expect(c.clampSpacingFor(100), 3.5);
    expect(c.od(50), 60);
  });

  test('bóc vật tư sơ đồ mẫu: ống, co, tê, côn giảm, van, cùm, băng keo', () {
    final bom = computeSurveyBom(_sample(), pipeSurveyConstants);
    expect(bom.warnings, isEmpty);
    // DN50: 10 + 10 + 5 + 5 + ống đứng P1, P2 (2 + 2) = 34 m; DN25: 10 + 2.
    expect(bom.lengthByDn, {50: 34, 25: 12});
    expect(_qty(bom), {
      // Làm tròn nguyên cây 6 m.
      'pipe50': 36,
      'pipe25': 12,
      // Nối kép: đoạn 10 m 1 mối (2 đoạn DN50, 1 đoạn DN25), +15%.
      'coupling50': 3,
      'coupling25': 2,
      // Co: góc J1 + đầu ống đứng P1, P2 = 3 → 4; DN25: ống đứng P3 1 → 2.
      'elbow50': 4,
      'elbow25': 2,
      // Tê: J2 (3 nhánh) + lấy khí P1 = 2 → 3.
      'tee50': 3,
      // Côn giảm DN50 → DN25 tại J2: 1 → 2.
      'reducer50x25': 2,
      // Van bi mỗi điểm sử dụng, không dự phòng.
      'ballValve50': 2,
      'ballValve25': 1,
      // Cùm DN50 (2,5 m): 4 + 4 + 2 + 2 + ống đứng 1 + 1 = 14 → 17;
      // DN25 (2 m): 5 + 1 = 6 → 7.
      'clamp50': 17,
      'clamp25': 7,
      // Mối ren DN50 22 → 3 cuộn, DN25 6 → 1 cuộn; 4 → 5.
      'tape': 5,
    });
    final names = {for (final l in bom.lines) l.key: (l.code, l.name)};
    expect(names['pipe50'], ('THEPO.60*3.2*6000', 'Ống kẽm Ø60 *3.2mm*6000'));
    expect(names['pipe25'], (null, 'Ống kẽm Ø34 *3.2mm*6000'));
    expect(names['elbow50'], ('COREN90-50', 'Co ren 90°'));
    expect(names['tee50'], ('NTRT-50', 'Ngã chữ T'));
    expect(names['ballValve50']!.$1, 'VANBID50-16');
    expect(names['clamp50']!.$1, 'CUMU-RM8-O60');
    // Côn giảm cỡ không có trong PO: tên chung theo đường kính ngoài.
    expect(names['reducer50x25'], (null, 'Co giảm ren 60/34'));
    expect(names['tape'], ('BKN', 'Băng keo non'));
    // Bảng đoạn: 5 đoạn ngang + 3 ống đứng.
    expect(bom.runs.where((r) => r.drop), hasLength(3));
    expect(bom.runs.first.label, 'Cụm máy → Máy tách màu 1');
  });

  test('chiều dài đo thực tế thay hình vẽ; đầu ống cụt có nút bịt', () {
    final s = _sample();
    s.segments.first.measuredM = 12.5;
    // Đoạn cụt từ J1 sang phải 4 m.
    s.nodes.add(SurveyNode(id: 'E', x: 24, y: 0));
    s.segments.add(SurveySegment(a: 'J1', b: 'E'));
    final bom = computeSurveyBom(s, pipeSurveyConstants);
    expect(bom.lengthByDn[50], 34 + 2.5 + 4);
    // J1 thành 3 nhánh: không còn co góc, thêm tê.
    expect(_qty(bom)['cap50'], 2);
    expect(bom.runs.first.measured, isTrue);
  });

  test('chưa nhập độ cao treo: cảnh báo, không tính ống đứng', () {
    final s = _sample()..hangHeightM = null;
    final bom = computeSurveyBom(s, pipeSurveyConstants);
    expect(
      bom.warnings.map((w) => w.code),
      contains(SurveyWarningCode.noHangHeight),
    );
    expect(bom.lengthByDn, {50: 30, 25: 10});
    // Treo thấp hơn đầu nối tại một điểm: cảnh báo riêng điểm đó.
    final low = _sample();
    low.nodes.firstWhere((n) => n.id == 'P1').hangHeightM = 2;
    expect(
      computeSurveyBom(low, pipeSurveyConstants).warnings.single.params['name'],
      'Máy tách màu 1',
    );
  });

  test('cao độ riêng tại điểm: ống đứng đổi cao độ + 2 co mỗi chỗ', () {
    final s = _sample();
    // J1 treo 6 m, hai điểm kề (P1, J2) theo công trình 4,5 m.
    s.nodes.firstWhere((n) => n.id == 'J1').hangHeightM = 6;
    final bom = computeSurveyBom(s, pipeSurveyConstants);
    final risers = bom.runs.where((r) => r.vertical).toList();
    expect(risers, hasLength(2));
    expect(risers.first.lengthM, 1.5);
    expect(risers.first.label, contains('đổi cao độ 4,5 → 6 m'));
    expect(bom.lengthByDn[50], 34 + 3);
    // Co DN50: 3 + 2 × 2 = 7 → +15% = 9.
    expect(_qty(bom)['elbow50'], 9);
    expect(_qty(bom)['pipe50'], 42);
  });

  test('vượt chướng ngại: mỗi lần 2 × chênh cao + 4 co', () {
    final s = _sample();
    s.segments.first
      ..obstacles = 2
      ..obstacleRiseM = -0.5;
    final bom = computeSurveyBom(s, pipeSurveyConstants);
    final run = bom.runs.singleWhere((r) => r.vertical);
    expect(run.lengthM, 2);
    expect(run.label, contains('vượt chướng ngại ×2, xuống 0,5 m'));
    expect(bom.lengthByDn[50], 36);
    // Co DN50: 3 + 4 × 2 = 11 → 13.
    expect(_qty(bom)['elbow50'], 13);
    // Lưu / đọc giữ thông tin vượt chướng ngại.
    final back = PipeSurvey.fromJson(s.toJson());
    expect(back.segments.first.obstacles, 2);
    expect(back.segments.first.obstacleRiseM, -0.5);
  });

  test('lưu / đọc JSON giữ nguyên sơ đồ', () {
    final s = _sample()..nodes.first.photos.add('a.jpg');
    final back = PipeSurvey.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });
}
