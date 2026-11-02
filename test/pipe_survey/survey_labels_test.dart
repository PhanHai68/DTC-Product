import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_bom.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:dtc_product/features/pipe_survey/widgets/survey_labels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('đoạn 1 cao 4 m, đoạn 2 cao 3 m: tổng ống = 7 m ngang + 1 m nối', () {
    final s = PipeSurvey();
    final a = SurveyNode(x: 0, y: 0, kind: SurveyNodeKind.compressor);
    final m = SurveyNode(x: 4, y: 0);
    final b = SurveyNode(x: 4, y: 3);
    s.nodes.addAll([a, m, b]);
    s.segments.addAll([
      SurveySegment(a: a.id, b: m.id, heightM: 4),
      SurveySegment(a: m.id, b: b.id, heightM: 3),
    ]);
    final bom = computeSurveyBom(s, pipeSurveyConstants);
    expect(bom.totalLengthM, 8);
    expect(bom.runs.where((r) => r.vertical).single.lengthM, 1);
  });

  test('bản cũ nhập cao độ theo điểm: chuyển sang cao độ đoạn ống', () {
    final s = PipeSurvey();
    final a = SurveyNode(x: 0, y: 0, kind: SurveyNodeKind.compressor);
    final m = SurveyNode(x: 6, y: 0, hangHeightM: 3.5);
    final b = SurveyNode(x: 6, y: 8, hangHeightM: 4);
    final c = SurveyNode(x: 12, y: 8);
    s.nodes.addAll([a, m, b, c]);
    s.segments.addAll([
      SurveySegment(a: a.id, b: m.id),
      SurveySegment(a: m.id, b: b.id),
      SurveySegment(a: b.id, b: c.id),
    ]);
    final back = PipeSurvey.fromJson(s.toJson());
    // Đoạn lấy cao độ điểm đầu (không có thì điểm cuối).
    expect([for (final g in back.segments) g.heightM], [3.5, 3.5, 4]);
    expect(back.nodes.every((n) => n.hangHeightM == null), isTrue);
    // Đổi cao độ tại điểm nối giữa đoạn 2 và 3: 0,5 m.
    expect(surveyNodeRiser(back, back.node(b.id)!), (3.5, 4.0, 2));
  });

  test('nhãn chiều dài, cao độ, ống đứng không chồng lên nhau', () {
    // Tuyến dày: đoạn ngắn 1,5 m, góc đổi cao độ, điểm sử dụng sát nhau.
    final s = PipeSurvey();
    final pts = [
      SurveyNode(x: 0, y: 0, kind: SurveyNodeKind.compressor),
      SurveyNode(x: 1.5, y: 0),
      SurveyNode(x: 1.5, y: 1.5),
      SurveyNode(x: 3, y: 1.5, kind: SurveyNodeKind.usePoint, name: 'Máy 1'),
      SurveyNode(x: 3, y: 3, kind: SurveyNodeKind.usePoint, name: 'Máy 2'),
      SurveyNode(x: 4.5, y: 3),
    ];
    s.nodes.addAll(pts);
    for (var k = 0; k + 1 < pts.length; k++) {
      s.segments.add(
        SurveySegment(a: pts[k].id, b: pts[k + 1].id, heightM: 3.0 + k / 2),
      );
    }
    final labels = surveyLayoutLabels(s, 24);
    final rects = [
      for (final l in [...labels.segments.values, ...labels.risers.values])
        l.rect,
    ];
    expect(labels.segments, hasLength(5));
    expect(labels.risers, hasLength(4));
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        expect(
          rects[i].overlaps(rects[j]),
          isFalse,
          reason: 'nhãn $i và $j chồng nhau',
        );
      }
    }
  });
}
