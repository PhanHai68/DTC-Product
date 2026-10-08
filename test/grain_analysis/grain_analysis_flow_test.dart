import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/grain_analysis/data/grain_analysis_database.dart';
import 'package:dtc_product/features/grain_analysis/engine/tray_layout.dart';
import 'package:dtc_product/features/grain_analysis/grain_analysis_routes.dart';
import 'package:dtc_product/features/grain_analysis/providers/grain_analysis_provider.dart';
import 'package:dtc_product/features/grain_analysis/repositories/grain_analysis_repository.dart';
import 'package:dtc_product/features/grain_analysis/services/grain_file_storage.dart';
import 'package:dtc_product/features/grain_analysis/services/grain_photo_service.dart';
import 'package:dtc_product/screens/extensions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../tool/grain_analysis/synthetic_tray.dart';

/// Thay camera bằng các ảnh tổng hợp có sẵn, lần lượt theo thứ tự chụp.
class _FakePhotoService extends GrainPhotoService {
  _FakePhotoService(this.images, Directory root)
    : super(storage: GrainFileStorage(rootOverride: root));

  final List<Uint8List> images;
  int _next = 0;

  @override
  Future<String?> pick({
    required ImageSource source,
    required String sessionId,
    required int imageIndex,
  }) async {
    final fileName = '${sessionId}_$imageIndex.jpg';
    await storage.saveImage(fileName, images[_next++]);
    return fileName;
  }
}

Future<void> _settle(WidgetTester tester, {int ms = 150}) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Chờ isolate phân tích xong (I/O thật) tới khi [finder] xuất hiện.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
    await _settle(tester, ms: 200);
  }
  expect(finder, findsOneWidget);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  late Database db;
  late Directory root;

  Future<GoRouter> setUpModule(
    WidgetTester tester,
    List<img.Image> captures,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    late List<Uint8List> jpegs;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await GrainAnalysisDatabase.instance.createSchemaForTesting(db);
      root = await Directory.systemTemp.createTemp('grain_analysis_test');
      jpegs = [for (final c in captures) img.encodeJpg(c, quality: 95)];
    });
    addTearDown(() async {
      await db.close();
      await root.delete(recursive: true);
    });
    final repository = GrainAnalysisRepository(
      database: GrainAnalysisDatabase.forTesting(db),
    );
    // Khay test nhỏ cho nhanh: lưu sẵn lựa chọn khay = khay test.
    return GoRouter(
      initialLocation: '/grain-analysis',
      routes: [
        buildGrainAnalysisRoutes(
          createProvider: () => _TestProvider(
            repository: repository,
            photoService: _FakePhotoService(jpegs, root),
          ),
        ),
      ],
    );
  }

  testWidgets('đếm hạt: chụp → phân tích → thêm/xóa hạt → xác nhận', (
    tester,
  ) async {
    final router = await setUpModule(tester, [
      renderTray(grains: gridGrains(count: 40, seed: 21)),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);

    expect(find.text('Phân tích mẫu AI'), findsOneWidget);
    expect(find.text('Chưa có phiên phân tích nào.'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('grain_new_count')));
    await tester.enterText(find.byKey(const Key('grain_lot_code')), 'LO-77');
    await tester.enterText(find.byKey(const Key('grain_operator')), 'QC Hải');
    await _tap(tester, find.byKey(const Key('grain_camera_0')));
    await _waitFor(tester, find.text('40 hạt'));
    expect(find.textContaining('Thấy đủ 4 mốc'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('grain_submit')));
    await _waitFor(tester, find.byKey(const Key('grain_result_total')));
    expect(
      tester.widget<Text>(find.byKey(const Key('grain_result_total'))).data,
      '40 hạt',
    );

    // Thêm một hạt bị sót: chạm vào giữa ảnh ở chế độ "Thêm hạt".
    await _tap(tester, find.text('Thêm hạt'));
    final viewer = find.byType(InteractiveViewer);
    await tester.tapAt(tester.getCenter(viewer));
    await _waitFor(tester, find.text('41 hạt'));
    expect(find.textContaining('1 hạt thêm tay'), findsOneWidget);

    // Xóa đúng hạt vừa thêm.
    await _tap(tester, find.text('Xóa hạt'));
    await tester.tapAt(tester.getCenter(viewer));
    await _waitFor(tester, find.text('40 hạt'));

    await _tap(tester, find.byKey(const Key('grain_session_confirm')));
    await _waitFor(tester, find.text('Đã xác nhận và lưu phiên.'));

    // Quay về danh sách: phiên đã lưu.
    router.go('/grain-analysis');
    await _settle(tester);
    expect(find.text('40 hạt'), findsOneWidget);
    expect(find.textContaining('Lô LO-77'), findsOneWidget);
    await tester.runAsync(() async {
      final rows = await db.query('sessions');
      expect(rows.single['created_by'], 'QC Hải');
      expect(rows.single['status'], 'confirmed');
      expect(rows.single['algorithm_version'], isNotEmpty);
    });
  });

  testWidgets('đếm nhanh: 12 hạt nhóm trên 40 hạt cả mẫu = 30,0%', (
    tester,
  ) async {
    final router = await setUpModule(tester, [
      renderTray(grains: gridGrains(count: 40, seed: 31)),
      renderTray(grains: gridGrains(count: 12, seed: 32)),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);

    await _tap(tester, find.byKey(const Key('grain_new_quick')));
    await _tap(tester, find.byKey(const Key('grain_camera_0')));
    await _waitFor(tester, find.byKey(const Key('grain_slot_count_0')));
    await _tap(tester, find.byKey(const Key('grain_camera_1')));
    await _waitFor(tester, find.byKey(const Key('grain_slot_count_1')));

    await _tap(tester, find.byKey(const Key('grain_submit')));
    await _waitFor(tester, find.byKey(const Key('grain_result_count_percent')));
    expect(find.text('30,0% số hạt'), findsOneWidget);
    expect(find.text('12 hạt nhóm / 40 hạt cả mẫu'), findsOneWidget);
    expect(find.text('Nhóm đã tách'), findsWidgets);
  });

  testWidgets('ảnh không thấy mốc: báo lý do, "Vẫn tiếp tục" gắn cờ ảnh kém', (
    tester,
  ) async {
    final router = await setUpModule(tester, [
      // Tờ giấy tràn khung ảnh (tablePx 0): không thấy mốc lẫn viền khay.
      renderTray(
        grains: gridGrains(count: 20, seed: 41),
        drawMarkers: false,
        tablePx: 0,
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);

    await _tap(tester, find.byKey(const Key('grain_new_count')));
    await _tap(tester, find.byKey(const Key('grain_camera_0')));
    await _waitFor(tester, find.text('Ảnh chưa đạt chất lượng'));
    expect(find.textContaining('Không thấy đủ bốn góc khay'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('grain_quality_continue')));
    expect(find.text('20 hạt'), findsOneWidget);
    expect(find.textContaining('Ảnh kém: Mốc khay'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('grain_submit')));
    await _waitFor(tester, find.byKey(const Key('grain_result_total')));
    expect(
      find.textContaining('không nhận ra khay — không có số đo mm'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      final rows = await db.query('sessions');
      expect(rows.single['poor_quality'], 1);
    });
  });

  testWidgets('Công cụ & Tiện ích có mục Phân tích mẫu AI', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ExtensionsScreen()));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('extension_grain_analysis'));
    await tester.scrollUntilVisible(entry, 200);
    expect(entry, findsOneWidget);
    expect(find.text('Phân tích mẫu AI'), findsOneWidget);
    // Các mục cũ vẫn còn.
    expect(find.byKey(const Key('extension_sample_record')), findsOneWidget);
  });
}

/// Provider dùng khay test nhỏ (ảnh tổng hợp nhỏ để test chạy nhanh).
class _TestProvider extends GrainAnalysisProvider {
  _TestProvider({super.repository, super.photoService});

  @override
  TrayLayout get tray => testLayout;
}
