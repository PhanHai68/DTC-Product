import 'package:dtc_product/data/product_data.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart'
    show RoomStyle;
import 'package:dtc_product/features/pipe_survey/data/pipe_survey_database.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_bom.dart';
import 'package:dtc_product/features/pipe_survey/engine/survey_geometry.dart';
import 'package:dtc_product/features/pipe_survey/models/pipe_survey.dart';
import 'package:dtc_product/features/pipe_survey/repositories/pipe_survey_repository.dart';
import 'package:dtc_product/features/pipe_survey/screens/pipe_survey_editor_screen.dart';
import 'package:dtc_product/features/pipe_survey/screens/pipe_survey_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('hình học sơ đồ', () {
    test('bắt lưới 0,5 m; vẽ ngang / dọc', () {
      expect(surveySnap(3.26), 3.5);
      expect(surveySnap(3.2), 3.0);
      final from = SurveyNode(x: 2, y: 2);
      expect(surveyOrthogonal(from, 9.1, 3.2), (9.0, 2.0));
      expect(surveyOrthogonal(from, 2.6, 7.8), (2.0, 8.0));
    });

    test('chạm lên ống: chèn điểm, chia chiều dài đo thực tế theo tỉ lệ', () {
      final s = PipeSurvey();
      final a = surveyNodeForTap(s, 0, 0);
      final b = surveyNodeForTap(s, 10, 0);
      surveyAddPipe(s, a, b)!.measuredM = 12;
      final mid = surveyNodeForTap(s, 4.1, 0.3);
      expect([mid.x, mid.y], [4.0, 0.0]);
      expect(s.segments, hasLength(2));
      final lens = [for (final g in s.segments) g.measuredM];
      expect(lens[0]! + lens[1]!, closeTo(12, 1e-9));
      expect(lens[0], closeTo(4.8, 1e-9));
      // Chạm sát điểm có sẵn: dùng lại điểm đó.
      expect(surveyNodeForTap(s, 4.3, 0.2).id, mid.id);
      // Xoá đoạn: điểm nối không còn ống bị bỏ.
      surveyDeleteSegment(s, s.segments.first.id);
      expect(s.nodes.map((n) => n.id), isNot(contains(a.id)));
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

    testWidgets('cụm máy theo kích thước thật: chạm vào cụm máy, đổi cách '
        'xếp thiết bị', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final survey = PipeSurvey(name: 'Nhà máy gạo B', hangHeightM: 4.5);
      final mn = SurveyNode(
        x: 14,
        y: 3,
        kind: SurveyNodeKind.compressor,
        name: 'Cụm máy',
        plant: SurveyPlant(modelCode: 'ACP-100PV'),
      );
      final end = SurveyNode(x: 24, y: 3);
      survey.nodes.addAll([mn, end]);
      survey.segments.add(SurveySegment(a: mn.id, b: end.id));
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
      await tester.tap(find.text('Chọn'));
      await tester.pumpAndSettle();
      // Phòng máy nằm bên trái điểm Cụm máy (ống ra sang phải).
      await tester.tapAt(origin + const Offset(8 * 24, 5 * 24));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('survey_node_name')), findsOneWidget);
      expect(find.textContaining('ACP-100PV'), findsOneWidget);
      expect(find.textContaining('Phương án 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('survey_node_plant')));
      await tester.pumpAndSettle();
      expect(find.text('Cụm máy theo kích thước thật'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('survey_plant_style_option3')),
      );
      await tester.tap(find.byKey(const Key('survey_plant_style_option3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('survey_plant_save')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Phương án 3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('survey_node_save')));
      await tester.pumpAndSettle();
      expect(mn.plant!.style, RoomStyle.option3);
      expect(mn.plant!.modelCode, 'ACP-100PV');
    });

    testWidgets('vẽ ống, đặt điểm sử dụng + cụm máy, hoàn tác, xem vật tư, '
        'lưu', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final survey = PipeSurvey(name: 'Nhà máy gạo A', hangHeightM: 4.5);
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

      // Công cụ mặc định: Vẽ ống. (2,2) → (12,2) → (12,8), chạm lại để dừng.
      await tapM(2, 2);
      await tapM(12, 2.2);
      await tapM(12.3, 8);
      await tapM(12, 8);
      expect(survey.segments, hasLength(2));
      // Hoàn tác đoạn cuối rồi vẽ lại.
      await tester.tap(find.byKey(const Key('survey_undo')));
      await tester.pumpAndSettle();
      expect(survey.segments, hasLength(1));
      await tapM(12, 2);
      await tapM(12, 8);
      // Thanh nhập chiều dài đoạn vừa vẽ: 6 m theo hình, đo thực tế 6,5 m.
      await tester.enterText(
        find.byKey(const Key('survey_last_length')),
        '6,5',
      );
      await tester.tap(find.byKey(const Key('survey_last_length_save')));
      await tester.pumpAndSettle();
      expect(survey.segments.last.measuredM, 6.5);
      expect(find.byKey(const Key('survey_last_length')), findsNothing);
      await tapM(12, 8);
      expect(survey.segments, hasLength(2));
      // Chạm số chiều dài của đoạn đầu (nhãn phía trên giữa đoạn): mở hộp
      // sửa đoạn.
      await tester.tapAt(origin + const Offset(7 * 24 + 6, 2 * 24 - 10));
      await tester.pumpAndSettle();
      expect(find.text('Đoạn ống'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(survey.segments, hasLength(2));

      // Điểm sử dụng giữa đoạn đầu: hộp sửa điểm mở ra.
      await tester.tap(find.text('Điểm sử dụng').first);
      await tester.pumpAndSettle();
      await tapM(7, 2);
      expect(find.byKey(const Key('survey_node_name')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('survey_node_name')),
        'Máy tách màu 1',
      );
      await tester.tap(find.byKey(const Key('survey_node_save')));
      await tester.pumpAndSettle();
      expect(survey.usePoints.single.name, 'Máy tách màu 1');
      expect(survey.segments, hasLength(3));

      // Điểm trên sơ đồ: chỗ trống → huỷ thì không thêm điểm.
      await tester.tap(find.text('Điểm trên sơ đồ').first);
      await tester.pumpAndSettle();
      final count = survey.nodes.length;
      await tapM(20, 14);
      expect(find.byKey(const Key('survey_node_name')), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(survey.nodes, hasLength(count));
      expect(find.byKey(const Key('survey_redo')), findsOneWidget);
      // Cụm máy ở đầu tuyến: chạm điểm có sẵn, chọn loại Cụm máy.
      await tapM(2, 2);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('survey_node_kind')),
          matching: find.text('Cụm máy'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('survey_node_save')));
      await tester.pumpAndSettle();
      expect(
        survey.nodes.firstWhere((n) => n.x == 2 && n.y == 2).name,
        'Cụm máy',
      );
      expect(
        survey.nodes.where((n) => n.kind == SurveyNodeKind.compressor),
        hasLength(1),
      );

      // Tab Vật tư: 10 + 6,5 m ngang + ống đứng 2 m = 18,5 m DN50 → 24 m.
      await tester.tap(find.text('Vật tư'));
      await tester.pumpAndSettle();
      expect(find.text('Ống DN50: 18,5 m'), findsOneWidget);
      expect(find.byKey(const Key('survey_bom_table')), findsOneWidget);
      final bom = computeSurveyBom(survey, pipeSurveyConstants);
      expect({for (final l in bom.lines) l.key: l.qty}['pipe50'], 24);

      await tester.tap(find.byKey(const Key('survey_save')));
      await tester.pumpAndSettle();
      final saved = await repository.get(survey.id);
      expect(saved!.segments, hasLength(3));
      expect(saved.usePoints.single.name, 'Máy tách màu 1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('hình nền: tường, cột, chướng ngại, ghi chú; không tính vật '
        'tư; hoàn tác', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final survey = PipeSurvey(hangHeightM: 4.5);
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

      // Tường chữ L: (1,1) → (20,1) → (20,10), chạm lại để dừng.
      await tool('Tường');
      await tapM(1, 1);
      await tapM(20, 1.3);
      await tapM(20.2, 10);
      await tapM(20, 10);
      final walls = survey.shapes.where((h) => h.kind == SurveyShapeKind.wall);
      expect(walls, hasLength(2));
      expect([walls.last.x2, walls.last.y2], [20.0, 10.0]);

      await tool('Cột');
      await tapM(10, 6);
      expect(
        survey.shapes.where((h) => h.kind == SurveyShapeKind.column),
        hasLength(1),
      );

      // Chướng ngại: 2 góc rồi đặt tên.
      await tool('Chướng ngại');
      await tapM(4, 4);
      await tapM(8, 7);
      expect(find.text('Chướng ngại vật'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('survey_shape_label')),
        'Bồn nước',
      );
      await tester.tap(find.byKey(const Key('survey_shape_save')));
      await tester.pumpAndSettle();
      final obstacle = survey.shapes.singleWhere(
        (h) => h.kind == SurveyShapeKind.obstacle,
      );
      expect(
        [obstacle.x1, obstacle.y1, obstacle.x2, obstacle.y2],
        [4.0, 4.0, 8.0, 7.0],
      );
      expect(obstacle.label, 'Bồn nước');

      // Ghi chú: huỷ khi chưa nhập chữ thì không giữ lại.
      await tool('Ghi chú');
      await tapM(12, 12);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(
        survey.shapes.where((h) => h.kind == SurveyShapeKind.note),
        isEmpty,
      );
      await tapM(12, 12);
      await tester.enterText(
        find.byKey(const Key('survey_shape_label')),
        'Lối xe nâng',
      );
      await tester.tap(find.byKey(const Key('survey_shape_save')));
      await tester.pumpAndSettle();
      expect(
        survey.shapes.singleWhere((h) => h.kind == SurveyShapeKind.note).label,
        'Lối xe nâng',
      );

      // Công cụ Chọn: chạm cột → xoá.
      await tool('Chọn');
      await tapM(10, 6);
      expect(find.text('Cột'), findsWidgets);
      await tester.tap(find.byKey(const Key('survey_shape_delete')));
      await tester.pumpAndSettle();
      expect(
        survey.shapes.where((h) => h.kind == SurveyShapeKind.column),
        isEmpty,
      );
      // Hoàn tác: cột trở lại.
      await tester.tap(find.byKey(const Key('survey_undo')));
      await tester.pumpAndSettle();
      expect(
        survey.shapes.where((h) => h.kind == SurveyShapeKind.column),
        hasLength(1),
      );
      // Hình nền không sinh vật tư.
      expect(computeSurveyBom(survey, pipeSurveyConstants).lines, isEmpty);
      final back = PipeSurvey.fromJson(survey.toJson());
      expect(back.shapes.length, survey.shapes.length);
      expect(tester.takeException(), isNull);
    });

    testWidgets('danh sách: tạo mới, mở, nhân bản, xoá', (tester) async {
      await repository.save(PipeSurvey(name: 'Kho B', customer: 'Cty X'));
      // Chờ thao tác cơ sở dữ liệu (bất đồng bộ thật) rồi vẽ lại.
      Future<void> settle() async {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        MaterialApp(home: PipeSurveyListScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kho B'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhân bản'));
      await settle();
      expect(find.text('Kho B (bản sao)'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xoá'));
      await settle();
      expect(await tester.runAsync(repository.list), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });
}
