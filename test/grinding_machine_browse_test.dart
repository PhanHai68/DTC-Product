import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_detail_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_home_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_machine_search_screen.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_series_machines_screen.dart';
import 'package:dtc_product/features/grinding_machine/widgets/grinding_machine_list_tile.dart';
import 'package:dtc_product/widgets/spec_sheet/spec_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Phần thông tin dòng máy (mô tả, nguyên lý, ảnh) đẩy danh sách model
/// xuống dưới màn hình test — cuộn tới ASC-200 trước khi kiểm tra/chạm.
Future<void> _scrollToAsc200(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('grinding_machine_tile_ASC_COARSE__ASC-200')),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester) async {
  sqfliteFfiInit();
  final database = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  addTearDown(database.close);
  await GrindingMachineDatabase.instance.createSchemaForTesting(database);
  final provider = GrindingMachineProvider(
    repository: GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(database),
    ),
  );
  addTearDown(provider.dispose);

  final router = GoRouter(
    initialLocation: '/grinding_machine',
    routes: [
      GoRoute(
        path: '/grinding_machine',
        builder: (_, _) => const GrindingMachineHomeScreen(),
      ),
      GoRoute(
        path: '/grinding_machine/search',
        builder: (_, _) => const GrindingMachineSearchScreen(),
      ),
      GoRoute(
        path: '/grinding_machine/series',
        builder: (_, state) =>
            GrindingSeriesMachinesScreen(seriesCode: state.extra as String),
      ),
      GoRoute(
        path: '/grinding_machine/detail/:machineId',
        builder: (_, state) => GrindingMachineDetailScreen(
          machineId: state.pathParameters['machineId']!,
        ),
      ),
      GoRoute(
        path: '/grinding_machine/asp-3d',
        builder: (_, _) => const Scaffold(body: Text('ASP-350 3D viewer')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // `testWidgets` chạy trong FakeAsync zone, nhưng sqflite_common_ffi gọi
  // SQLite thật qua FFI (không tương thích FakeAsync) — phải bọc bằng
  // `runAsync()` để Future thật (đọc asset JSON + import/query SQLite) được
  // xử lý đúng thay vì treo vô thời hạn.
  await tester.runAsync(() async {
    await tester.pumpWidget(
      ChangeNotifierProvider<GrindingMachineProvider>.value(
        value: provider,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    while (provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home tự seed database thật và hiển thị đúng 12 dòng máy', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Máy nghiền'), findsOneWidget);
    expect(find.textContaining('12 dòng · 57 model'), findsOneWidget);
    expect(
      find.byKey(const Key('grinding_series_card_ASC_COARSE')),
      findsOneWidget,
    );
  });

  testWidgets('Chạm 1 Series mở đúng danh sách model của dòng máy đó', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('grinding_series_card_ASC_COARSE')));
    await tester.pumpAndSettle();

    // Dòng có ảnh: ảnh máy thay cho thẻ ứng dụng, có nguyên lý hoạt động.
    expect(find.byKey(const Key('grinding_series_image')), findsOneWidget);
    expect(find.byType(SpecChipWrap), findsNothing);
    expect(find.byKey(const Key('grinding_series_principle')), findsOneWidget);

    // ASC_COARSE có 5 model ASC-200/300/400/600/1000 theo database.
    await _scrollToAsc200(tester);
    expect(find.textContaining('5 model'), findsOneWidget);
    expect(
      find.byKey(const Key('grinding_machine_tile_ASC_COARSE__ASC-200')),
      findsOneWidget,
    );
    // Model hiện ảnh nhỏ thay cho icon.
    expect(
      find.byKey(const Key('grinding_machine_thumb_ASC_COARSE__ASC-200')),
      findsOneWidget,
    );
  });

  testWidgets('Dòng ASU hiện tên mới, ảnh, nguyên lý và đặc điểm chính', (
    tester,
  ) async {
    await _pumpApp(tester);

    final card = find.byKey(const Key('grinding_series_card_ASU_UNIVERSAL'));
    await tester.scrollUntilVisible(card, 300);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();

    // Thẻ ở Home: dòng phụ là tên tiếng Anh của dòng máy.
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('grinding_series_subtitle_ASU_UNIVERSAL')),
          )
          .data,
      'High Speed Turbine Grinder Dried Jerusalem artichoke chips Grinding Machine',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('grinding_series_subtitle_ASZ_PIN')),
      100,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('grinding_series_subtitle_ASZ_PIN')),
          )
          .data,
      'High speed pin mill',
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();

    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('MÁY NGHIỀN TUA-BIN TỐC ĐỘ CAO'), findsOneWidget);
    expect(find.byKey(const Key('grinding_series_principle')), findsOneWidget);
    expect(find.byKey(const Key('grinding_series_features')), findsOneWidget);
    expect(find.text('Đặc điểm chính'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('grinding_series_image')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('grinding_series_image')), findsOneWidget);
  });

  testWidgets('Dòng ASK: ứng dụng dạng danh sách, nguyên lý thu gọn/mở rộng', (
    tester,
  ) async {
    await _pumpApp(tester);

    final card = find.byKey(const Key('grinding_series_card_ASK_JET'));
    await tester.scrollUntilVisible(card, 300);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('grinding_series_subtitle_ASK_JET')),
          )
          .data,
      'Powder Air Jet Mill',
    );
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('MÁY NGHIỀN PHẢN LỰC KHÍ SIÊU MỊN'), findsOneWidget);
    expect(
      find.byKey(const Key('grinding_series_application')),
      findsOneWidget,
    );
    expect(find.text('Vật liệu có tính mài mòn'), findsOneWidget);
    expect(find.text('Hóa chất nông nghiệp'), findsOneWidget);

    // Nguyên lý dài: mặc định thu gọn, bấm "Xem thêm" mới thấy Bước 5.
    expect(find.text('Bước 1 – Cấp liệu'), findsOneWidget);
    expect(find.text('Bước 5 – Tách bột mịn và bột thô'), findsNothing);
    final toggle = find.byKey(const Key('grinding_series_principle_toggle'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Bước 5 – Tách bột mịn và bột thô'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
  });

  testWidgets('Dòng ASDF: có mục Cấu tạo, danh sách đánh số trong nguyên lý', (
    tester,
  ) async {
    await _pumpApp(tester);

    final card = find.byKey(const Key('grinding_series_card_ASDF_MULTISTAGE'));
    await tester.scrollUntilVisible(card, 300);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('MÁY NGHIỀN BÚA NHIỀU TẦNG'), findsOneWidget);
    expect(find.byKey(const Key('grinding_series_structure')), findsOneWidget);
    expect(find.text('Cấu tạo'), findsOneWidget);
    expect(find.text('Hệ thống thu bụi xung pulse'), findsOneWidget);
    // "1. Vùng nghiền thô" hiện thành số thứ tự + nội dung, không phải tiêu đề.
    expect(find.text('1.  '), findsOneWidget);
    expect(find.text('Vùng nghiền thô'), findsOneWidget);
    expect(
      find.text('Điểm đặc biệt: nghiền 3 tầng trong cùng một buồng'),
      findsOneWidget,
    );
  });

  testWidgets('Dòng máy lạnh sâu giờ có ảnh thay cho thẻ ứng dụng', (
    tester,
  ) async {
    await _pumpApp(tester);

    final card = find.byKey(const Key('grinding_series_card_AS_CRYOGENIC'));
    await tester.scrollUntilVisible(card, 300);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('MÁY NGHIỀN SIÊU LẠNH'), findsOneWidget);
    expect(find.byKey(const Key('grinding_series_image')), findsOneWidget);
    expect(find.byType(SpecChipWrap), findsNothing);
  });

  testWidgets('Model thuộc dòng chưa có ảnh vẫn hiện icon thay ảnh nhỏ', (
    tester,
  ) async {
    // Cả 12 dòng thật đều đã có ảnh -> dùng 1 dòng giả để giữ kiểm tra
    // nhánh dự phòng (thêm dòng mới chưa kịp có ảnh).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrindingMachineListTile(
            machine: const GrindingMachine(
              machineId: 'NEW__X-1',
              seriesCode: 'NEW_SERIES',
              model: 'X-1',
            ),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(
      find.byKey(const Key('grinding_machine_thumb_NEW__X-1')),
      findsNothing,
    );
    expect(find.byIcon(Icons.precision_manufacturing_outlined), findsOneWidget);
  });

  testWidgets(
    'Chạm 1 model mở Detail đúng thông số thật từ database, không rỗng',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(
        find.byKey(const Key('grinding_series_card_ASC_COARSE')),
      );
      await tester.pumpAndSettle();
      await _scrollToAsc200(tester);
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('grinding_machine_tile_ASC_COARSE__ASC-200')),
        );
        await tester.pump();
        // Detail screen tự load (getMachine/getSeries/getExtraSpecs) qua
        // postFrameCallback riêng — cũng là I/O thật nên cần chờ thật trước
        // khi rời runAsync (bên trong FakeAsync zone sẽ không tự chạy).
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('ASC-200'), findsWidgets);
      // Thẻ "Ứng dụng" thay cho các nhãn chọn máy dưới chỉ số nổi bật.
      expect(
        find.byKey(const Key('grinding_detail_application')),
        findsOneWidget,
      );
      expect(find.text('Ứng dụng'), findsOneWidget);
      expect(
        find.text('Được sử dụng rộng rãi trong các ngành:'),
        findsOneWidget,
      );
      expect(find.byType(SpecChipWrap), findsNothing);
      // Ứng dụng của ASC dài (13 dòng) -> thu gọn, "Ớt khô" ở dòng 7.
      expect(find.text('Ớt khô'), findsNothing);
      final toggle = find.byKey(
        const Key('grinding_detail_application_toggle'),
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Ớt khô'), findsOneWidget);
      expect(find.text('Công suất xử lý'), findsOneWidget);
      expect(find.text('80 - 300 kg/h'), findsOneWidget);
      expect(find.text('Độ mịn đầu ra'), findsOneWidget);
      expect(find.text('0.5 - 20 mm'), findsOneWidget);
    },
  );

  testWidgets(
    'Trang thông số: bấm chip model khác trong cùng dòng đổi đúng thông số',
    (tester) async {
      await _pumpApp(tester);

      await tester.tap(
        find.byKey(const Key('grinding_series_card_ASC_COARSE')),
      );
      await tester.pumpAndSettle();
      await _scrollToAsc200(tester);
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('grinding_machine_tile_ASC_COARSE__ASC-200')),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('MÁY NGHIỀN ASC-200'), findsOneWidget);
      expect(
        find.byKey(const Key('grinding_detail_model_ASC-300')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('grinding_detail_model_ASC-300')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(const Key('grinding_detail_model_ASC-300')),
        );
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('MÁY NGHIỀN ASC-300'), findsOneWidget);
      expect(find.text('100 - 800 kg/h'), findsOneWidget);
    },
  );

  testWidgets('Search tìm đúng model theo tên nhập vào', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('grinding_machine_search_bar')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('grinding_machine_search_field')),
      'ASP-350',
    );
    await tester.runAsync(() async {
      await tester.pump(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('grinding_machine_tile_ASP_ULTRAFINE__ASP-350')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Dòng ASP có nút xem 3D đại diện ASP-350 và ASP-1000 ở cuối danh sách',
    (tester) async {
      await _pumpApp(tester);

      final seriesCard = find.byKey(
        const Key('grinding_series_card_ASP_ULTRAFINE'),
      );
      await tester.scrollUntilVisible(seriesCard, 300);
      await tester.ensureVisible(seriesCard);
      await tester.pumpAndSettle();
      await tester.tap(seriesCard);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('grinding_asp_3d_button')), findsOneWidget);
      expect(find.text('Ảnh đại diện: ASP-350'), findsOneWidget);

      final asp1000 = find.byKey(
        const Key('grinding_machine_tile_ASP_ULTRAFINE__ASP-1000'),
      );
      await tester.scrollUntilVisible(asp1000, 250);
      final asp900 = find.byKey(
        const Key('grinding_machine_tile_ASP_ULTRAFINE__ASP-900'),
      );
      expect(
        tester.getTopLeft(asp900).dy,
        lessThan(tester.getTopLeft(asp1000).dy),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('grinding_asp_3d_button')),
        -300,
      );
      await tester.drag(find.byType(ListView), const Offset(0, 140));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('grinding_asp_3d_button')));
      await tester.pumpAndSettle();
      expect(find.text('ASP-350 3D viewer'), findsOneWidget);
    },
  );

  test('video mô hình ASP-350 được khai báo trong asset bundle', () async {
    final data = await rootBundle.load('assets/videos/ASP-350-3D.mp4');
    expect(data.lengthInBytes, greaterThan(3 * 1024 * 1024));
  });
}
