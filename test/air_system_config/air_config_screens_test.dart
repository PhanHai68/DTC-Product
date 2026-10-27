import 'package:dtc_product/features/air_system_config/data/air_config_database.dart';
import 'package:dtc_product/features/air_system_config/data/air_config_templates.dart';
import 'package:dtc_product/features/air_system_config/diagram/air_diagram.dart';
import 'package:dtc_product/features/air_system_config/l10n/air_strings.dart';
import 'package:dtc_product/features/air_system_config/models/air_result.dart';
import 'package:dtc_product/features/air_system_config/repositories/air_config_repository.dart';
import 'package:dtc_product/features/air_system_config/room/room_drawing.dart';
import 'package:dtc_product/features/air_system_config/room/room_engine.dart';
import 'package:dtc_product/features/air_system_config/room/room_strings.dart';
import 'package:dtc_product/features/air_system_config/screens/air_config_editor_screen.dart';
import 'package:dtc_product/features/air_system_config/services/air_config_export_service.dart';
import 'package:dtc_product/features/data_backup/services/data_backup_engine.dart';
import 'package:dtc_product/screens/acomp/acomp_tech_category_screen.dart';
import 'package:dtc_product/screens/acomp/acomp_oil_free_detail_screen.dart';
import 'package:dtc_product/features/air_system_config/models/air_config.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late AirConfigRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final wrapper = AirConfigDatabase.forTesting(database);
    await wrapper.createSchemaForTesting(database);
    repository = AirConfigRepository(database: wrapper);
  });

  tearDown(() async => database.close());

  test('CSDL nằm trong danh sách sao lưu', () {
    expect(
      DataBackupEngine.databaseFiles,
      contains(AirConfigDatabase.fileName),
    );
    expect(DataBackupEngine.userContentTables[AirConfigDatabase.fileName], [
      'air_configs',
    ]);
  });

  test('lưu, mở lại, tìm, nhân bản, xóa', () async {
    final config = AirConfigTemplate.food.build();
    await repository.save(config);
    final loaded = await repository.get(config.id);
    expect(loaded!.toJson()['lines'], config.toJson()['lines']);
    expect((await repository.list(query: 'phẩm 3')).single.lineCount, 3);
    expect(await repository.list(query: 'không có'), isEmpty);

    final copy = await repository.duplicate(config.id, suffix: '(bản sao)');
    expect(copy!.id, isNot(config.id));
    expect(copy.project.name, 'Thực phẩm 3 line (bản sao)');
    expect(await repository.list(), hasLength(2));

    await repository.delete(config.id);
    expect((await repository.list()).single.id, copy.id);
  });

  test('Excel danh mục: đủ cột, công thức thành tiền', () {
    final config = AirConfigTemplate.workshop.build();
    final result = appAirEngine().compute(config);
    final file = AirConfigExportService.excel(
      config,
      result,
      AirStrings(AirLang.vi),
      'test',
    );
    final sheet = Excel.decodeBytes(file.bytes).tables.values.first;
    final header = sheet.row(3).map((c) => c?.value.toString()).toList();
    expect(header, [
      'STT',
      'Tên thiết bị',
      'Thông số',
      'SL',
      'Đơn giá (VNĐ)',
      'Thành tiền (VNĐ)',
    ]);
    expect(sheet.row(4)[1]?.value.toString(), 'Máy nén khí ACP-100PV');
    expect(sheet.row(4)[5]?.value.toString(), contains('D5*E5'));
    expect(sheet.maxRows, 4 + result.equipment.length + 1);
  });

  testWidgets('PDF A3: một file gồm sơ đồ lắp đặt + mặt bằng phòng', (
    tester,
  ) async {
    final config = AirConfigTemplate.pharma.build();
    final result = appAirEngine().compute(config);
    final strings = AirStrings(AirLang.vi);
    final room = buildRoomDrawing(
      config,
      appRoomEngine().compute(config, result),
      strings,
    );
    final file = await tester.runAsync(
      () async => AirConfigExportService.pdf(
        config,
        strings,
        buildAirDiagram(config, result, strings),
        'test',
        room: room,
        roomHeading: strings.roomDrawingTitle,
      ),
    );
    expect(String.fromCharCodes(file!.bytes.sublist(0, 4)), '%PDF');
    // Trang 1 sơ đồ, trang 2 mặt bằng (không còn trang thông số tổng).
    final doc = PdfDocument(inputBytes: file.bytes);
    expect(doc.pages.count, 2);
    doc.dispose();
  });

  testWidgets(
    'màn cấu hình: tính ngay khi sửa áp suất, không còn ô áp suất cần thiết',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: AirConfigEditorScreen(
            initial: AirConfigTemplate.food.build()..treatment.usePressure = 8,
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Áp sử dụng cao hơn áp máy không còn báo lỗi thiếu áp.
      expect(find.byIcon(Icons.error), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('pressure')),
          matching: find.byType(TextField),
        ),
        '9,2',
      );
      await tester.pump();
      expect(find.byIcon(Icons.error), findsNothing);

      await tester.tap(find.text('Kết quả'));
      await tester.pumpAndSettle();
      // 9,2 bar → lưu lượng mức 10 bar: AFR-175F 20,3 chưa đủ → AFR-200F 24,5.
      expect(find.textContaining('Lưu lượng: 24,5 m³/phút'), findsOneWidget);
      expect(find.text('Áp suất cần thiết'), findsNothing);
      // Không còn tab Sơ đồ, nhóm xử lý khí, danh mục thiết bị: sơ đồ nằm
      // trong tab Kết quả, bấm để xem toàn màn hình.
      expect(find.text('Nhóm xử lý khí'), findsNothing);
      expect(find.text('Danh mục thiết bị'), findsNothing);
      expect(find.widgetWithText(Tab, 'Sơ đồ'), findsNothing);
      // Thẻ thiết bị điện theo model AFR-200F (không dầu) chưa có dữ liệu.
      expect(find.byKey(const Key('air_electrical_card')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('air_diagram_canvas')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('air_config_results')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('air_diagram_canvas')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('air_diagram_zoom')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('air_config_save')));
      await tester.pumpAndSettle();
      expect(await repository.list(), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('đổi ngôn ngữ EN: kết quả đổi theo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(
          initial: AirConfigTemplate.food.build()..treatment.usePressure = 8,
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('air_config_lang')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Results'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Flow: 22.5 m³/min'), findsOneWidget);
    expect(find.text('Diagram'), findsOneWidget);
    expect(find.text('Required pressure'), findsNothing);
  });

  testWidgets('vào chức năng mở thẳng màn nhập liệu, cấu hình trống', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: AirConfigEditorScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cấu hình hệ thống khí nén'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Nhập liệu'), findsOneWidget);
    expect(find.text('Tìm theo tên dự án'), findsNothing);
    // Cấu hình mới: mặc định "Chọn model".
    expect(AirConfig().compressor.source, CompressorSource.catalog);
    expect(
      tester
          .widget<SegmentedButton<CompressorSource>>(
            find.byType(SegmentedButton<CompressorSource>),
          )
          .selected,
      {CompressorSource.catalog},
    );
    await tester.tap(find.byKey(const Key('air_config_save')));
    await tester.pumpAndSettle();
    expect(await repository.list(), hasLength(1));
  });

  testWidgets('mặt bằng toàn màn hình: đo 2 điểm, kéo thiết bị; lưu cùng '
      'cấu hình', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = AirConfigTemplate.workshop.build();
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(
          initial: config,
          repository: repository,
          initialTab: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('room_open_editor')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('air_room_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byKey(const Key('room_open_editor')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_open_editor')));
    await tester.pumpAndSettle();
    expect(find.text('Đo kích thước'), findsOneWidget);

    // Vị trí màn hình của một điểm (mm) trên bản vẽ đang vừa khít chiều ngang.
    final room = appRoomEngine().compute(
      config,
      appAirEngine().compute(config),
    );
    final drawing = buildRoomDrawing(config, room, AirStrings(AirLang.vi));
    Offset screen(Offset mm) {
      final area = tester.getRect(
        find.byKey(const Key('room_editor_gestures')),
      );
      final scale = (area.width / drawing.width).clamp(0.2, 1.5);
      return area.topLeft + drawing.toPx(mm) * scale;
    }

    await tester.tap(find.text('Đo kích thước'));
    await tester.pumpAndSettle();
    // Bắt điểm vào hai góc trước của máy nén.
    final comp = room.of(RoomItemKind.compressor).single;
    await tester.tapAt(screen(comp.rect.bottomLeft));
    await tester.pump();
    expect(find.textContaining('Chạm chọn điểm 2'), findsOneWidget);
    await tester.tapAt(screen(comp.rect.bottomRight));
    await tester.pumpAndSettle();
    final width = comp.rect.width;
    expect(find.text('${AirStrings(AirLang.vi).n0(width)} mm'), findsOneWidget);
    // Đủ 2 điểm: chạm thêm không tạo điểm / phép đo mới.
    await tester.tapAt(screen(comp.rect.center));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã đủ 2 điểm'), findsOneWidget);
    expect(find.text('${AirStrings(AirLang.vi).n0(width)} mm'), findsOneWidget);

    // Chọn nhầm: kéo điểm 2 (chạm gần, không cần trúng) lên góc trên.
    final p2 = screen(comp.rect.bottomRight) + const Offset(8, 6);
    await tester.dragFrom(
      p2,
      screen(comp.rect.topRight) - screen(comp.rect.bottomRight),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('(${AirStrings(AirLang.vi).n0(width)} × '),
      findsOneWidget,
    );

    // Đo lại: xoá 2 điểm, chọn lại từ đầu.
    await tester.tap(find.byKey(const Key('room_remeasure')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room_measure_value')), findsNothing);
    expect(find.textContaining('Chạm chọn điểm 1'), findsOneWidget);
    await tester.tapAt(screen(comp.rect.bottomLeft));
    await tester.pump();
    await tester.tapAt(screen(comp.rect.bottomRight));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Di chuyển'));
    await tester.pumpAndSettle();
    final tank = room.of(RoomItemKind.tank).single;
    final from = screen(tank.rect.center);
    await tester.dragFrom(
      from,
      screen(tank.rect.center + const Offset(0, 900)) - from,
    );
    await tester.pumpAndSettle();

    // Chọn máy sấy rồi xoay 90° quanh tâm.
    final dryer = room.of(RoomItemKind.dryer).single;
    await tester.tapAt(screen(dryer.rect.center));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_rotate')));
    await tester.pumpAndSettle();

    // Nhập kích thước phòng có sẵn ngay trong màn chỉnh sửa.
    await tester.tap(find.byKey(const Key('room_edit_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_size_menu')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('room_size_length')),
        matching: find.byType(TextField),
      ),
      '8',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('room_size_width')),
        matching: find.byType(TextField),
      ),
      '4,5',
    );
    await tester.tap(find.byKey(const Key('room_size_apply')));
    await tester.pumpAndSettle();
    // Nhiệt độ thông gió T1, T2 ngay trong màn chỉnh sửa.
    await tester.tap(find.byKey(const Key('room_edit_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('room_vent_menu')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('room_vent_t1')),
        matching: find.byType(TextField),
      ),
      '30',
    );
    await tester.tap(find.byKey(const Key('room_vent_apply')));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    // Ô nhập ở tab cập nhật theo kích thước vừa nhập.
    await tester.scrollUntilVisible(
      find.text('Phòng thực tế (tuỳ chọn)'),
      -300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('air_room_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.widgetWithText(TextField, '8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('air_config_save')));
    await tester.pumpAndSettle();
    final saved = await repository.get(config.id);
    expect(saved!.room.turned, {'dryer_0'});
    expect([saved.room.lengthM, saved.room.widthM], [8, 4.5]);
    expect([saved.room.outsideTempC, saved.room.inletMaxTempC], [30, 46]);
    // Xoay quanh tâm: tâm máy sấy giữ nguyên (bước 50 mm).
    final dpos = saved.room.positions['dryer_0']!;
    expect(
      dpos.$1 + dryer.rect.height / 2,
      closeTo(dryer.rect.center.dx, 25.01),
    );
    final measure = saved.room.measures.single;
    expect(measure.bx - measure.ax, closeTo(comp.rect.width, 1e-6));
    expect(measure.ay, closeTo(comp.rect.bottom, 1e-6));
    final pos = saved.room.positions['tank_0']!;
    expect(pos.$1, closeTo((tank.rect.left / 50).round() * 50, 1e-6));
    expect(pos.$2, greaterThan(tank.rect.top + 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tab Phòng lắp đặt: mở thẳng từ menu, nhập phòng thực tế, '
      'đổi cách xếp, có bản vẽ', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(
          initial: AirConfigTemplate.workshop.build(),
          repository: repository,
          initialTab: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(Tab, 'Phòng lắp đặt'), findsOneWidget);
    expect(find.text('Phòng thực tế (tuỳ chọn)'), findsOneWidget);
    // 3 phương án lắp đặt (hình có tên thiết bị, không còn kích thước).
    for (final o in RoomStyle.values) {
      expect(find.byKey(Key('room_option_${o.name}')), findsOneWidget);
    }
    expect(find.text('Máy sấy xoay 90°'), findsOneWidget);
    expect(find.text('9 × 3,5 m'), findsNothing);
    final roomList = find
        .descendant(
          of: find.byKey(const PageStorageKey('air_room_view')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('DN50'),
      300,
      scrollable: roomList,
    );
    expect(find.text('9 × 3,5 × 4,5 m'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Phòng thực tế (tuỳ chọn)'),
      -300,
      scrollable: roomList,
    );

    // Phòng nhỏ: không phương án nào lọt, có cảnh báo.
    await tester.enterText(find.widgetWithText(TextField, 'Dài (m)'), '4');
    await tester.enterText(find.widgetWithText(TextField, 'Rộng (m)'), '3');
    await tester.pumpAndSettle();
    expect(find.text('Không lọt'), findsNWidgets(3));
    await tester.scrollUntilVisible(
      find.textContaining('Phòng thực tế không đủ'),
      300,
      scrollable: roomList,
    );
    expect(find.textContaining('Phòng thực tế không đủ'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Phòng thực tế (tuỳ chọn)'),
      -300,
      scrollable: roomList,
    );

    // Phòng rộng: cả 3 lọt; chọn phương án 3.
    await tester.enterText(find.widgetWithText(TextField, 'Dài (m)'), '20');
    await tester.enterText(find.widgetWithText(TextField, 'Rộng (m)'), '10');
    await tester.pumpAndSettle();
    expect(find.text('Lọt phòng'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('room_option_option3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('20 × 10 × '),
      300,
      scrollable: roomList,
    );
    expect(find.textContaining('20 × 10 × '), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('room_drawing_canvas')),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('air_room_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('room_export_pdf')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('cảnh báo: lỗi xếp trên cùng', () {
    final r = appAirEngine().compute(
      AirConfigTemplate.pharma.build()..treatment.usePressure = null,
    );
    final levels = r.warnings.map((w) => w.level.index).toList();
    expect(levels, [...levels]..sort());
    expect(r.warnings.first.level, WarningLevel.error);
  });

  testWidgets(
    'danh mục máy nén khí có thêm OIL-FREE và 2-STAGE (đang cập nhật)',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: AcompTechCategoryScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Máy nén khí không dầu'), findsOneWidget);
      expect(find.text('Máy nén khí trục vít 2 cấp'), findsOneWidget);
      await tester.ensureVisible(find.text('Máy nén khí trục vít 2 cấp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Máy nén khí trục vít 2 cấp'));
      await tester.pumpAndSettle();
      expect(find.textContaining('đang được cập nhật'), findsOneWidget);
    },
  );

  testWidgets('form: không còn Khách hàng/Ngành; Loại máy đủ 5 dòng', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(
          initial: AirConfig(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Khách hàng'), findsNothing);
    expect(find.text('Ngành'), findsNothing);
    await tester.tap(find.text('PM VFD – Trục vít biến tần'));
    await tester.pumpAndSettle();
    for (final label in [
      'FIXED SPEED – Trục vít tốc độ cố định',
      '4 IN 1 – Trục vít 4 trong 1',
      'OIL-FREE – Máy nén khí không dầu',
      '2-STAGE – Trục vít 2 cấp',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('2-STAGE – Trục vít 2 cấp').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa có model'), findsOneWidget);
  });

  testWidgets('thông số máy không dầu AFR-F / AFR-PV', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AcompOilFreeDetailScreen()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biến tần (AFR-PV)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn công suất...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('100 HP (75 kW) - AFR-100PV').last);
    await tester.pumpAndSettle();
    expect(find.text('Thông số Model: AFR-100PV'), findsOneWidget);
    expect(find.text('3,95–12,6 m³/phút'), findsOneWidget);
    expect(find.text('3–9,85 m³/phút'), findsOneWidget);
    expect(find.text('2100x1600x1900 mm'), findsOneWidget);
    expect(find.text('1.750 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lọc đường ống: tiêu chuẩn khóa 3 lọc; Nâng cao có after '
      'cooling và lọc sau bình (mặc định 2)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = AirConfig();
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(initial: config, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lọc đường ống'), findsOneWidget);
    expect(find.text('Tiền xử lý'), findsNothing);
    SwitchListTile tile(String label) => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, label),
    );
    for (final label in [
      'Lọc tách nước 3 µm',
      'Lọc tách thô 1 µm',
      'Lọc tách tinh 0,01 µm',
    ]) {
      expect(tile(label).value, isTrue);
      expect(tile(label).onChanged, isNull); // tiêu chuẩn: không tắt được
    }
    await tester.tap(find.text('Theo tiêu chuẩn lọc đường ống'));
    await tester.pumpAndSettle();
    expect(tile('Lọc tách thô 1 µm').onChanged, isNotNull);

    await tester.tap(find.text('Nâng cao'));
    await tester.pumpAndSettle();
    expect(find.text('After cooling'), findsOneWidget);
    await tester.tap(find.text('Lọc sau bình tích khí'));
    await tester.pumpAndSettle();
    expect(config.pretreat.tankFilter, isTrue);
    expect(config.pretreat.tankFilterQty, 2);
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('tank_filter_qty')),
        matching: find.text('1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(config.pretreat.tankFilterQty, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuộn form rồi đổi tab: mục Nâng cao không đọc nhầm vị trí '
      'cuộn (lỗi double is not bool)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(
          initial: AirConfig(),
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nâng cao'),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('air_config_form')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kết quả'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhập liệu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const PageStorageKey('air_config_form')), findsOneWidget);
  });

  testWidgets('máy nén: nhu cầu + mức dư khách chọn (15/20/25/30%) → '
      'đề xuất ở tab Kết quả; không còn dòng đề xuất / Nhập tay trên form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = AirConfig()..compressor.source = CompressorSource.demand;
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(initial: config, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dự phòng lưu lượng'), findsNothing);
    expect(find.byKey(const ValueKey('manual_entry')), findsNothing);
    expect(find.textContaining('Đề xuất:'), findsNothing);
    expect(
      find.text('Lưu lượng máy lớn hơn so với nhu cầu thực tế'),
      findsOneWidget,
    );
    for (final chip in ['15%', '20%', '25%', '30%']) {
      expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget);
    }
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('customer_demand')),
        matching: find.byType(TextField),
      ),
      '12',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '30%'));
    await tester.pumpAndSettle();
    expect(config.compressor.marginPercent, 30);
    // Ô nhập cũng nhận số khách tự gõ.
    final marginInput = find.descendant(
      of: find.byKey(const ValueKey('margin_percent')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(marginInput).controller!.text, '30');
    await tester.enterText(marginInput, '22');
    await tester.pumpAndSettle();
    expect(config.compressor.marginPercent, 22);
    await tester.tap(find.widgetWithText(ChoiceChip, '30%'));
    await tester.pumpAndSettle();

    // 12 × 1,3 = 15,6 → ACP-150PV 19,8 (dư +65%) hiện ở tab Kết quả.
    await tester.tap(find.text('Kết quả'));
    await tester.pumpAndSettle();
    expect(find.textContaining('19,8 m³/phút'), findsWidgets);
    expect(find.textContaining('ACP-150PV · dư +65%'), findsOneWidget);

    await tester.tap(find.text('Nhập liệu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn model'));
    await tester.pumpAndSettle();
    expect(config.compressor.source, CompressorSource.catalog);
    expect(find.byKey(const ValueKey('customer_demand')), findsNothing);
    expect(find.byKey(const ValueKey('margin_percent')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '2-STAGE (chưa có dữ liệu): nút thứ 2 là "Nhập tay"; nhập máy '
    'xong thì tính theo máy đó; đổi về loại có dữ liệu thì về "Theo nhu cầu"',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final config = AirConfig()..compressor.type = CompressorType.twoStage;
      await tester.pumpWidget(
        MaterialApp(
          home: AirConfigEditorScreen(initial: config, repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final source = find.byKey(const ValueKey('compressor_source'));
      expect(
        find.descendant(of: source, matching: find.text('Nhập tay')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: source, matching: find.text('Chọn model')),
        findsNothing,
      );
      expect(find.textContaining('chọn "Nhập tay"'), findsWidgets);

      await tester.tap(
        find.descendant(of: source, matching: find.text('Nhập tay')),
      );
      await tester.pumpAndSettle();
      expect(config.compressor.source, CompressorSource.manual);
      expect(find.byKey(const ValueKey('back_to_catalog')), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('manual_name')),
          matching: find.byType(TextField),
        ),
        'TS-75',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('manual_fad')),
          matching: find.byType(TextField),
        ),
        '12',
      );
      await tester.pumpAndSettle();
      expect(find.text('TS-75 (12 m³/phút)'), findsOneWidget);

      // Đổi sang loại có dữ liệu: nhập tay không còn là lựa chọn → Theo nhu cầu.
      await tester.tap(find.text('2-STAGE – Trục vít 2 cấp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PM VFD – Trục vít biến tần').last);
      await tester.pumpAndSettle();
      expect(config.compressor.source, CompressorSource.demand);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('line chỉ còn tên; Xử lý khí chung (PDP, áp sử dụng, lọc)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final config = AirConfig()..compressor.demand = 10;
    await tester.pumpWidget(
      MaterialApp(
        home: AirConfigEditorScreen(initial: config, repository: repository),
      ),
    );
    await tester.pumpAndSettle();
    // Line: chỉ ô tên, không còn lưu lượng / áp min-max.
    expect(find.text('Áp min'), findsNothing);
    expect(find.text('Áp max'), findsNothing);
    expect(find.text('Thiết bị sử dụng (vd máy tách màu)'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(ValueKey('${config.lines.single.id}_name')),
        matching: find.byType(TextField),
      ),
      'Máy tách màu',
    );
    await tester.pumpAndSettle();
    expect(config.lines.single.name, 'Máy tách màu');

    // Xử lý khí chung.
    expect(find.text('Xử lý khí'), findsOneWidget);
    expect(find.text('Áp suất sử dụng'), findsOneWidget);
    expect(find.text('Dùng máy sấy tác nhân lạnh'), findsOneWidget);
    expect(find.text('Kiểu tái sinh'), findsNothing);
    // Không còn máy dự phòng, lọc than / vô trùng, dòng "4–16 bar";
    // áp sử dụng mặc định 8 bar; điểm sương sấy lạnh ghi 2–10 °C.
    expect(find.text('Máy dự phòng'), findsNothing);
    expect(find.text('Lọc than hoạt tính'), findsNothing);
    expect(find.text('Lọc vô trùng'), findsNothing);
    expect(find.text('4–16 bar'), findsNothing);
    expect(config.treatment.usePressure, 8);
    expect(find.text('+3 °C'), findsNothing);
    await tester.tap(find.text('2–10 °C').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('−40 °C').last);
    await tester.pumpAndSettle();
    expect(config.treatment.pdp, LinePdp.m40);
    expect(find.text('Dùng máy sấy hấp thụ'), findsOneWidget);
    expect(find.text('Kiểu tái sinh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
