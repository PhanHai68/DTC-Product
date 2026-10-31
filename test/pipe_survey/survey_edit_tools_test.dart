import 'package:dtc_product/features/pipe_survey/data/pipe_survey_database.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_geometry.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:dtc_product/features/pipe_survey/repositories/pipe_survey_repository.dart';
import 'package:dtc_product/features/pipe_survey/screens/pipe_survey_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SurveyShape _wall(double x1, double y1, double x2, double y2) =>
    SurveyShape(kind: SurveyShapeKind.wall, x1: x1, y1: y1, x2: x2, y2: y2);

List<List<double>> _walls(PipeSurvey s) => [
  for (final h in s.shapes)
    if (h.kind == SurveyShapeKind.wall) [h.x1, h.y1, h.x2, h.y2],
];

void main() {
  group('Cắt tường (Trim)', () {
    test('cắt tới giao điểm gần nhất hai phía', () {
      final w = _wall(0, 0, 10, 0);
      final s = PipeSurvey(shapes: [w, _wall(5, -2, 5, 2), _wall(8, -2, 8, 2)]);
      expect(surveyTrimWall(s, w, 6.5, 0.1), isTrue);
      expect(_walls(s), [
        [0.0, 0.0, 5.0, 0.0],
        [8.0, 0.0, 10.0, 0.0],
        [5.0, -2.0, 5.0, 2.0],
        [8.0, -2.0, 8.0, 2.0],
      ]);
    });

    test('phía không có giao điểm: cắt tới đầu tường; cột, phòng cụm máy '
        'là cạnh cắt', () {
      final w = _wall(0, 0, 10, 0);
      final s = PipeSurvey(
        shapes: [
          w,
          SurveyShape(kind: SurveyShapeKind.column, x1: 3, y1: 0),
        ],
      );
      expect(surveyTrimWall(s, w, 6, 0), isTrue);
      expect(_walls(s), [
        [0.0, 0.0, 3.2, 0.0],
      ]);
      final w2 = _wall(0, 5, 10, 5);
      final s2 = PipeSurvey(shapes: [w2]);
      expect(
        surveyTrimWall(s2, w2, 5, 5, rects: [const Rect.fromLTWH(4, 3, 3, 4)]),
        isTrue,
      );
      expect(_walls(s2), [
        [0.0, 5.0, 4.0, 5.0],
        [7.0, 5.0, 10.0, 5.0],
      ]);
    });

    test('không giao cạnh nào: không cắt', () {
      final w = _wall(0, 0, 10, 0);
      final s = PipeSurvey(shapes: [w, _wall(0, 3, 10, 3)]);
      expect(surveyTrimWall(s, w, 5, 0), isFalse);
      expect(s.shapes, hasLength(2));
    });
  });

  group('Xoá điểm (Erase)', () {
    test('điểm giữa hai đoạn thẳng hàng: nối lại, cộng chiều dài đo', () {
      final s = PipeSurvey();
      final a = SurveyNode(x: 0, y: 0);
      final m = SurveyNode(x: 4, y: 0, kind: SurveyNodeKind.usePoint);
      final b = SurveyNode(x: 10, y: 0);
      s.nodes.addAll([a, m, b]);
      s.segments.addAll([
        SurveySegment(a: a.id, b: m.id, measuredM: 4.2),
        SurveySegment(a: m.id, b: b.id, measuredM: 6.1),
      ]);
      surveyEraseNode(s, m);
      expect(s.nodes, hasLength(2));
      expect(s.segments.single.measuredM, closeTo(10.3, 1e-9));
    });

    test('điểm dùng ở góc / cuối ống: thành điểm nối, giữ ống', () {
      final s = PipeSurvey();
      final a = SurveyNode(x: 0, y: 0);
      final u = SurveyNode(
        x: 5,
        y: 0,
        kind: SurveyNodeKind.usePoint,
        name: 'Máy 1',
      );
      s.nodes.addAll([a, u]);
      s.segments.add(SurveySegment(a: a.id, b: u.id));
      surveyEraseNode(s, u);
      expect(u.kind, SurveyNodeKind.junction);
      expect(s.segments, hasLength(1));
    });
  });

  group('màn hình', () {
    late Database database;
    late PipeSurveyRepository repository;
    setUp(() async {
      sqfliteFfiInit();
      database = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      final wrapper = PipeSurveyDatabase.forTesting(database);
      await wrapper.createSchemaForTesting(database);
      repository = PipeSurveyRepository(database: wrapper);
    });
    tearDown(() async => database.close());

    testWidgets('Di chuyển, Cắt, Xoá, mũi tên, tên vùng, khung tên', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final survey = PipeSurvey(name: 'Nhà máy C', hangHeightM: 4);
      final a = SurveyNode(x: 2, y: 2);
      final u = SurveyNode(
        x: 12,
        y: 2,
        kind: SurveyNodeKind.usePoint,
        name: 'Máy 1',
      );
      survey.nodes.addAll([a, u]);
      survey.segments.add(SurveySegment(a: a.id, b: u.id));
      survey.shapes.addAll([_wall(2, 8, 20, 8), _wall(10, 5, 10, 12)]);
      await tester.pumpWidget(
        MaterialApp(
          home: PipeSurveyEditorScreen(
            initial: survey,
            repository: repository,
            initialTab: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final origin = tester.getTopLeft(find.byKey(const Key('survey_canvas')));
      Future<void> tapM(double x, double y) async {
        await tester.tapAt(origin + Offset(x * 24, y * 24));
        await tester.pumpAndSettle();
      }

      Future<void> tool(String label) async {
        // Di chuyển, Cắt, Xoá, Ghi chú, Mũi tên, Tên vùng nằm trong menu Edit.
        const edit = {
          'Di chuyển': 'move',
          'Cắt': 'trim',
          'Xoá': 'erase',
          'Ghi chú': 'note',
          'Mũi tên': 'leader',
          'Tên vùng': 'area',
        };
        if (edit[label] case final name?) {
          await tester.tap(find.byKey(const Key('survey_edit')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key('survey_edit_$name')));
        } else {
          await tester.tap(find.text(label).first);
        }
        await tester.pumpAndSettle();
      }

      // Di chuyển điểm dùng xuống 3 m: ống kéo giãn theo.
      // Nhấn giữ rồi rê (chạm thường chỉ nhắc cách dùng).
      Future<void> drag(Offset fromM, Offset toM) async {
        final g = await tester.startGesture(origin + fromM * 24);
        await tester.pump(const Duration(milliseconds: 700));
        // Rê từng bước nhỏ như ngón tay.
        for (var k = 1; k <= 6; k++) {
          await g.moveTo(origin + (fromM + (toM - fromM) * (k / 6)) * 24);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await g.up();
        await tester.pumpAndSettle();
      }

      await tool('Di chuyển');
      await tapM(12, 2);
      expect(find.text('Nhấn giữ vật rồi rê để di chuyển.'), findsOneWidget);
      expect([u.x, u.y], [12.0, 2.0]);
      await drag(const Offset(12, 2), const Offset(12.1, 5));
      expect([u.x, u.y], [12.0, 5.0]);
      expect(survey.segments.single.b, u.id);
      // Dời tường dọc sang phải 2 m.
      await drag(const Offset(10, 11), const Offset(12, 11));
      // Undo / Redo bước dời tường.
      await tester.tap(find.byKey(const Key('survey_undo')));
      await tester.pumpAndSettle();
      expect(_walls(survey)[1], [10.0, 5.0, 10.0, 12.0]);
      await tester.tap(find.byKey(const Key('survey_redo')));
      await tester.pumpAndSettle();
      expect(_walls(survey)[1], [12.0, 5.0, 12.0, 12.0]);

      // Cắt phần tường ngang bên phải tường dọc.
      await tool('Cắt');
      await tapM(16, 8);
      expect(_walls(survey), [
        [2.0, 8.0, 12.0, 8.0],
        [12.0, 5.0, 12.0, 12.0],
      ]);

      // Xoá đoạn ống rồi hoàn tác.
      await tool('Xoá');
      await tapM(7, 3.5);
      expect(survey.segments, isEmpty);
      await tester.tap(find.byKey(const Key('survey_undo')));
      await tester.pumpAndSettle();
      expect(survey.segments, hasLength(1));

      // Chú thích mũi tên: điểm chỉ rồi chỗ đặt chữ.
      await tool('Mũi tên');
      await tapM(12, 9);
      await tapM(16, 11);
      expect(find.text('Chú thích mũi tên'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('survey_shape_label')),
        'Lỗ xuyên tường',
      );
      await tester.tap(find.byKey(const Key('survey_shape_save')));
      await tester.pumpAndSettle();
      final leader = survey.shapes.singleWhere(
        (h) => h.kind == SurveyShapeKind.leader,
      );
      expect([leader.x1, leader.y1, leader.x2, leader.y2], [12, 9, 16, 11]);

      // Tên vùng, chữ cao 1,5 m.
      await tool('Tên vùng');
      await tapM(6, 14);
      await tester.enterText(
        find.byKey(const Key('survey_shape_label')),
        'Xưởng sấy',
      );
      await tester.enterText(find.byKey(const Key('survey_shape_size')), '1,5');
      await tester.tap(find.byKey(const Key('survey_shape_save')));
      await tester.pumpAndSettle();
      final area = survey.shapes.singleWhere(
        (h) => h.kind == SurveyShapeKind.area,
      );
      expect([area.label, area.sizeM], ['Xưởng sấy', 1.5]);

      // Khung tên góc dưới phải vùng vẽ: sửa tên bản vẽ.
      await tool('Chọn');
      final size = tester.getSize(find.byKey(const Key('survey_canvas')));
      await tester.tapAt(origin + Offset(size.width - 100, size.height - 60));
      await tester.pumpAndSettle();
      expect(find.text('Khung tên bản vẽ'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('survey_title_0')),
        'MẶT BẰNG TUYẾN ỐNG XƯỞNG 2',
      );
      await tester.tap(find.byKey(const Key('survey_title_save')));
      await tester.pumpAndSettle();
      expect(survey.drawingTitle, 'MẶT BẰNG TUYẾN ỐNG XƯỞNG 2');
      expect(survey.name, 'Nhà máy C');
    });
  });
}
