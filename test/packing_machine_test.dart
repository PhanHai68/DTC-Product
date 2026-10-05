import 'dart:io';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_menu_screen.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_spec_sheet_pdf_service.dart';
import 'package:dtc_product/features/packing_machine/models/packing_catalog.dart';
import 'package:dtc_product/features/packing_machine/providers/packing_machine_provider.dart';
import 'package:dtc_product/features/packing_machine/screens/packing_machine_compare_screen.dart';
import 'package:dtc_product/features/packing_machine/screens/packing_machine_detail_screen.dart';
import 'package:dtc_product/features/packing_machine/screens/packing_machine_home_screen.dart';
import 'package:dtc_product/features/packing_machine/screens/packing_series_machines_screen.dart';
import 'package:dtc_product/features/packing_machine/screens/packing_machine_selector_screen.dart';
import 'package:dtc_product/features/packing_machine/services/packing_machine_selection_service.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine_match.dart';
import 'package:dtc_product/features/packing_machine/utils/packing_spec_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _catalogPath = 'assets/database/packing_machine_catalog.json';

PackingMachineProvider _provider() => PackingMachineProvider(
  loadSource: () async => File(_catalogPath).readAsStringSync(),
);

Future<PackingMachineProvider> _pumpPacking(
  WidgetTester tester, {
  String initialLocation = '/packing_machine',
}) async {
  final provider = _provider();
  addTearDown(provider.dispose);
  await provider.load();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/packing_machine',
        builder: (_, _) => const PackingMachineHomeScreen(),
      ),
      GoRoute(
        path: '/packing_machine/series',
        builder: (_, state) =>
            PackingSeriesMachinesScreen(seriesCode: state.extra as String),
      ),
      GoRoute(
        path: '/packing_machine/detail/:machineId',
        builder: (_, state) => PackingMachineDetailScreen(
          machineId: state.pathParameters['machineId']!,
        ),
      ),
      GoRoute(
        path: '/packing_machine/selector',
        builder: (_, _) => const PackingMachineSelectorScreen(),
      ),
      GoRoute(
        path: '/packing_machine/compare',
        builder: (_, state) => PackingMachineCompareScreen(
          initialMachineIds: state.extra as List<String>?,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<PackingMachineProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catalog máy đóng gói', () {
    final catalog = PackingCatalog.parse(File(_catalogPath).readAsStringSync());

    test('7 dòng máy, 20 model, đúng số model mỗi dòng', () {
      expect(catalog.series, hasLength(7));
      expect(catalog.machines, hasLength(20));
      final counts = <String, int>{};
      for (final m in catalog.machines) {
        counts[m.seriesCode] = (counts[m.seriesCode] ?? 0) + 1;
      }
      expect(counts, {
        'ASPM_VERTICAL': 6,
        'SCREW_SCALE': 3,
        'HOPPER_SCALE': 2,
        'ASPM_F': 1,
        'ASPM_ABC': 3,
        'TEA_BAG': 3,
        'BIG_BAG': 2,
      });
      final ids = catalog.machines.map((m) => m.machineId).toSet();
      expect(ids, hasLength(20), reason: 'machineId không trùng');
    });

    test('tên model đã đổi B -> A, không còn tên nhà cung cấp', () {
      for (final m in catalog.machines) {
        expect(m.model, isNot(startsWith('B')), reason: m.model);
      }
      // Mọi chữ khách hàng nhìn thấy (verificationNote là ghi chú nội bộ,
      // được phép trích nguyên văn catalog).
      final shown = [
        for (final s in catalog.series) ...[
          s.displayCode,
          s.nameVi,
          s.nameEn,
          s.applicationVi,
          s.structureVi,
          s.workingPrincipleVi,
          s.featuresVi,
          s.imageCaption ?? '',
        ],
        for (final m in catalog.machines) ...[
          m.model,
          m.imageCaption ?? '',
          for (final h in m.highlights) '${h.title} ${h.value}',
          for (final spec in m.specs) '${spec.label} ${spec.value}',
        ],
      ].join('\n').toLowerCase();
      expect(shown, isNot(contains('brightsail')));
      expect(shown, isNot(contains('bspm')));
    });

    test('mỗi model có 3 chỉ số nổi bật và đủ khối lượng + tốc độ', () {
      for (final m in catalog.machines) {
        expect(m.highlights, hasLength(3), reason: m.model);
        expect(m.valueOf('pack_weight'), isNotNull, reason: m.model);
        expect(m.valueOf('speed'), isNotNull, reason: m.model);
        expect(
          m.specsOf(PackingSpecGroup.technical),
          isNotEmpty,
          reason: m.model,
        );
      }
    });

    test('ảnh dòng máy và ảnh riêng từng model đều có trong assets', () async {
      final paths = {
        for (final s in catalog.series)
          if (s.image case final p?) p,
        for (final m in catalog.machines)
          if (m.image case final p?) p,
      };
      expect(paths, hasLength(10));
      for (final path in paths) {
        final bytes = await rootBundle.load(path);
        expect(bytes.lengthInBytes, greaterThan(1000), reason: path);
      }
    });
  });

  group('PackingMachineProvider', () {
    test(
      'sắp model theo số, tìm không dấu, ảnh model ưu tiên hơn ảnh dòng',
      () async {
        final provider = _provider();
        await provider.load();
        expect(
          provider.machinesOf('ASPM_VERTICAL').map((m) => m.model).toList(),
          [
            'ASPM-320',
            'ASPM-420',
            'ASPM-520',
            'ASPM-620',
            'ASPM-720',
            'ASPM-820',
          ],
        );
        expect(provider.search('tra tui loc').map((m) => m.model), [
          'AS-20D',
          'AS-C12',
          'AS-NW160',
        ]);
        expect(provider.search('aspm-520').single.model, 'ASPM-520');
        final nw160 = provider.machineById('PACK__AS-NW160')!;
        expect(
          provider.imageOf(nw160),
          'assets/images/catalog_packing_tea_nw160.png',
        );
        final aspm = provider.machineById('PACK__ASPM-320')!;
        expect(
          provider.imageOf(aspm),
          'assets/images/catalog_packing_aspm_vertical.png',
        );
      },
    );
  });

  group('PackingSpecSheet', () {
    test('ô giá trị trên thẻ gọn, text chia sẻ đủ thông số', () async {
      final provider = _provider();
      await provider.load();
      final machine = provider.machineById('PACK__ASPM-B100')!;
      final sheet = PackingSpecSheet(
        machine: machine,
        series: provider.seriesOf(machine.seriesCode),
      );
      expect(sheet.title, 'MÁY ĐÓNG GÓI ASPM-B100');
      expect(sheet.chips.map((c) => c.$1), ['5 - 50 kg', '2 - 4 bao/phút']);
      expect(sheet.installRows.map((r) => r.label), contains('Khí nén'));
      final text = sheet.shareText(contactName: 'An', contactPhone: '0901');
      expect(text, contains('• Tốc độ đóng gói: 2 - 4 bao/phút'));
      expect(
        text,
        contains('• Độ chính xác: 5 - 20 kg: ≤ ±0.1 - 0.2%; ≥ 20 kg'),
      );
    });

    test('PDF catalog máy đóng gói dựng được với font tiếng Việt', () async {
      final provider = _provider();
      await provider.load();
      final machine = provider.machineById('PACK__AS-C12')!;
      final sheet = PackingSpecSheet(
        machine: machine,
        series: provider.seriesOf(machine.seriesCode),
        imagePath: provider.imageOf(machine),
      );
      final bytes = await GrindingSpecSheetPdfService.buildCatalogPdf(
        headerTitle: 'CATALOG MÁY ĐÓNG GÓI',
        footerLabel: 'DTCGroup · Catalog máy đóng gói',
        title: sheet.title,
        subtitle: sheet.series?.nameVi,
        imagePath: sheet.imagePath,
        imageCaption: null,
        groups: [
          ('THÔNG SỐ KỸ THUẬT', sheet.technicalRows),
          ('LẮP ĐẶT', sheet.installRows),
        ],
        applicationText: sheet.series!.applicationVi,
        contactName: 'An',
        contactPhone: '0901',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  testWidgets('Trang chính -> dòng máy -> trang thông số đổi model', (
    tester,
  ) async {
    await _pumpPacking(tester);
    expect(find.text('Máy đóng gói'), findsOneWidget);
    expect(find.text('7 dòng · 20 model'), findsOneWidget);

    final teaCard = find.byKey(const Key('packing_series_card_TEA_BAG'));
    await tester.scrollUntilVisible(teaCard, 200);
    await tester.ensureVisible(teaCard);
    await tester.pumpAndSettle();
    await tester.tap(teaCard);
    await tester.pumpAndSettle();
    expect(find.text('MÁY ĐÓNG GÓI TRÀ TÚI LỌC'), findsOneWidget);

    final tile = find.byKey(const Key('packing_machine_tile_PACK__AS-C12'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('3 model'), findsOneWidget);
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('MÁY ĐÓNG GÓI AS-C12'), findsOneWidget);
    expect(find.text('Tốc độ (túi/phút)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('packing_detail_model_AS-NW160')));
    await tester.pumpAndSettle();
    expect(find.text('MÁY ĐÓNG GÓI AS-NW160'), findsOneWidget);
    expect(find.text('Hàn 3 biên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('So sánh đặt sẵn 2 model hiện bảng theo khoá thông số', (
    tester,
  ) async {
    await _pumpPacking(tester);
    final context = tester.element(find.byType(PackingMachineHomeScreen));
    GoRouter.of(
      context,
    ).push('/packing_machine/compare', extra: ['PACK__ASPM-A', 'PACK__ASPM-C']);
    await tester.pumpAndSettle();
    expect(find.text('Khối lượng rót'), findsOneWidget);
    expect(find.text('10 - 500 g'), findsOneWidget);
    expect(find.text('10 - 5000 g'), findsOneWidget);
    expect(find.text('Dung tích phễu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('PackingMachineSelectionService', () {
    late PackingMachineProvider provider;
    setUp(() async {
      provider = _provider();
      await provider.load();
    });

    List<PackingMachineMatch> evaluate(PackingSelectionCriteria c) =>
        PackingMachineSelectionService.evaluate(
          criteria: c,
          machines: provider.machines,
          seriesByCode: {for (final s in provider.series) s.seriesCode: s},
        );

    List<String> strong(List<PackingMachineMatch> results) => [
      for (final r in results)
        if (r.label == GrindingMatchLabel.strong) r.machine.model,
    ];

    test('bột 1 kg, 30 túi/phút, đóng túi', () {
      final results = evaluate(
        const PackingSelectionCriteria(
          form: PackingMaterialForm.powder,
          packWeightG: 1000,
          speedPerMin: 30,
          packaging: PackingPackaging.bag,
        ),
      );
      expect(results, hasLength(20), reason: 'không loại model nào');
      expect(strong(results), [
        'ASPM-520',
        'ASPM-620',
        'ASPM-720',
        'ASPM-820',
        'ASPM-B',
        'ASPM-C',
      ]);
      // Cân trục vít 50L: bao bì tùy máy đi kèm -> "có thể phù hợp".
      final screw = results.firstWhere((r) => r.machine.model == '50L');
      expect(screw.label, GrindingMatchLabel.possible);
      // ASPM-320 chỉ tới 200 g -> không đạt khối lượng.
      final small = results.firstWhere((r) => r.machine.model == 'ASPM-320');
      expect(small.label, GrindingMatchLabel.closest);
      expect(
        small.criteria
            .firstWhere((c) => c.label == 'Khối lượng mỗi gói')
            .status,
        GrindingCriterionStatus.notMatch,
      );
    });

    test('trà túi lọc 3 g, tự động hoàn toàn', () {
      final results = evaluate(
        const PackingSelectionCriteria(
          form: PackingMaterialForm.tea,
          packWeightG: 3,
          automation: PackingAutomation.auto,
        ),
      );
      expect(strong(results), ['AS-C12', 'AS-NW160']);
      // AS-20D: catalog không ghi mức tự động -> chưa có dữ liệu, không loại.
      expect(
        results.firstWhere((r) => r.machine.model == 'AS-20D').label,
        GrindingMatchLabel.possible,
      );
    });

    test('bao lớn 25 kg bán tự động', () {
      final results = evaluate(
        const PackingSelectionCriteria(
          packWeightG: 25000,
          packaging: PackingPackaging.bigbag,
          automation: PackingAutomation.semi,
        ),
      );
      expect(strong(results), ['ASPM-B100']);
      expect(results[1].machine.model, 'ASPM-A100');
      expect(results[1].label, GrindingMatchLabel.possible);
    });

    test('máy chỉ ghi mức tối đa (≤ 200 g) chỉ so với mức tối đa', () {
      final results = evaluate(const PackingSelectionCriteria(packWeightG: 5));
      final aspm320 = results.firstWhere((r) => r.machine.model == 'ASPM-320');
      expect(aspm320.label, GrindingMatchLabel.strong);
      expect(aspm320.criteria.single.actualDisplay, '≤ 200 g');
      final big = results.firstWhere((r) => r.machine.model == 'ASPM-A100');
      expect(big.criteria.single.status, GrindingCriterionStatus.notMatch);
      expect(big.criteria.single.actualDisplay, '5 - 50 kg');
    });

    test('công suất điện tối đa và tiêu chí rỗng', () {
      final results = evaluate(const PackingSelectionCriteria(maxPowerKw: 1.5));
      expect(strong(results), [
        '2 phễu',
        '4 phễu',
        'AS-20D',
        'ASPM-A',
        'ASPM-B',
        'ASPM-F',
      ]);
      expect(const PackingSelectionCriteria().isEmpty, isTrue);
    });
  });

  testWidgets('Chọn máy: nhập yêu cầu -> đề xuất -> so sánh 2 model', (
    tester,
  ) async {
    await _pumpPacking(tester);
    final context = tester.element(find.byType(PackingMachineHomeScreen));
    GoRouter.of(context).push('/packing_machine/selector');
    await tester.pumpAndSettle();
    expect(find.byType(PackingMachineSelectorScreen), findsOneWidget);
    final list = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(finder, 250, scrollable: list);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('packing_selector_form_tea')));
    await tester.enterText(
      find.byKey(const Key('packing_selector_weight_field')),
      '3',
    );
    final submit = find.byKey(const Key('packing_selector_submit_button'));
    await reveal(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Máy được đề xuất (3)'), findsOneWidget);
    for (final id in ['PACK__AS-20D', 'PACK__AS-C12']) {
      final star = find.byKey(Key('packing_selector_shortlist_$id'));
      await reveal(star);
      await tester.tap(star);
      await tester.pumpAndSettle();
    }
    final compare = find.byKey(
      const Key('packing_selector_compare_shortlist_button'),
    );
    await reveal(compare);
    await tester.tap(compare);
    await tester.pumpAndSettle();
    expect(find.byType(PackingMachineCompareScreen), findsOneWidget);
    expect(find.text('Khối lượng mỗi túi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu trung gian hiện số dòng/model của cả 2 nhóm', (
    tester,
  ) async {
    sqfliteFfiInit();
    final database = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(database.close);
    await GrindingMachineDatabase.instance.createSchemaForTesting(database);
    final grinding = GrindingMachineProvider(
      repository: GrindingMachineRepository(
        database: GrindingMachineDatabase.forTesting(database),
      ),
    );
    addTearDown(grinding.dispose);
    final packing = _provider();
    addTearDown(packing.dispose);
    final router = GoRouter(
      initialLocation: '/grinding_menu',
      routes: [
        GoRoute(
          path: '/grinding_menu',
          builder: (_, _) => const GrindingMenuScreen(),
        ),
        GoRoute(
          path: '/packing_machine',
          builder: (_, _) => const PackingMachineHomeScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: grinding),
            ChangeNotifierProvider.value(value: packing),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      while (grinding.isLoading || !packing.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(find.text('Máy nghiền & đóng gói'), findsOneWidget);
    expect(find.text('12 dòng · 57 model'), findsOneWidget);
    expect(find.text('7 dòng · 20 model'), findsOneWidget);

    await tester.tap(find.byKey(const Key('grinding_menu_packing_btn')));
    await tester.pumpAndSettle();
    expect(find.byType(PackingMachineHomeScreen), findsOneWidget);
  });
}
