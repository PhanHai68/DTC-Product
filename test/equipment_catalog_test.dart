import 'dart:io';

import 'package:dtc_product/features/equipment_catalog/equipment_catalog_config.dart';
import 'package:dtc_product/features/equipment_catalog/equipment_routes.dart';
import 'package:dtc_product/features/equipment_catalog/models/equipment_catalog.dart';
import 'package:dtc_product/features/equipment_catalog/providers/equipment_catalog_provider.dart';
import 'package:dtc_product/features/equipment_catalog/screens/equipment_compare_screen.dart';
import 'package:dtc_product/features/equipment_catalog/screens/equipment_home_screen.dart';
import 'package:dtc_product/features/equipment_catalog/screens/equipment_selector_screen.dart';
import 'package:dtc_product/features/equipment_catalog/services/equipment_selection_service.dart';
import 'package:dtc_product/features/equipment_catalog/utils/equipment_spec_sheet.dart';
import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/models/grinding_machine_match.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:dtc_product/features/grinding_machine/screens/grinding_menu_screen.dart';
import 'package:dtc_product/features/grinding_machine/services/grinding_spec_sheet_pdf_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _packing = EquipmentCatalogs.packing;
const _mixer = EquipmentCatalogs.mixer;
const _sifter = EquipmentCatalogs.sifter;
const _rice = EquipmentCatalogs.riceMilling;

EquipmentCatalogProvider _provider() => EquipmentCatalogProvider(
  loadSource: (path) async => File(path).readAsStringSync(),
);

Future<LoadedEquipmentCatalog> _load(EquipmentCatalogConfig config) async {
  final provider = _provider();
  await provider.load(config);
  return provider.catalog(config)!;
}

EquipmentCatalog _parse(EquipmentCatalogConfig config) =>
    EquipmentCatalog.parse(File(config.assetPath).readAsStringSync());

Future<void> _pump(WidgetTester tester, EquipmentCatalogConfig config) async {
  final provider = _provider();
  addTearDown(provider.dispose);
  await provider.load(config);
  final router = GoRouter(
    initialLocation: config.routeBase,
    routes: equipmentRoutes(config),
  );
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<EquipmentCatalogProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

List<EquipmentMatch> _evaluate(
  LoadedEquipmentCatalog catalog,
  Map<String, Object> requirements,
) => EquipmentSelectionService.evaluate(
  criteria: catalog.criteria,
  requirements: requirements,
  machines: catalog.machines,
  seriesByCode: catalog.seriesByCode,
);

List<String> _strong(List<EquipmentMatch> results) => [
  for (final r in results)
    if (r.label == GrindingMatchLabel.strong) r.machine.model,
];

EquipmentMatch _match(List<EquipmentMatch> results, String model) =>
    results.firstWhere((r) => r.machine.model == model);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dữ liệu catalog', () {
    test('số dòng / model mỗi catalog, machineId không trùng', () {
      final expected = {
        _packing: {
          'ASPM_VERTICAL': 6,
          'SCREW_SCALE': 3,
          'HOPPER_SCALE': 2,
          'ASPM_F': 1,
          'ASPM_ABC': 3,
          'TEA_BAG': 3,
          'BIG_BAG': 2,
        },
        _mixer: {
          'ASR_RIBBON': 14,
          'ASL_PADDLE': 10,
          'AST_TROUGH': 5,
          'ASV_V': 10,
          'ASW_W': 9,
          'ASTD_3D': 10,
          'ASD_DOUBLE_CONE': 8,
          'ASS_SQUARE_CONE': 6,
        },
        _sifter: {'ASST_VIBRO': 7, 'ASRS_ROTARY': 2},
        _rice: {
          'DRYER_5H': 7,
          'CLEANER_TQLG': 3,
          'CLEANER_TQLM': 3,
          'DESTONER_TQSX': 3,
          'DESTONER_TQSZ': 4,
          'HUSKER_MLGQ': 6,
          'HUSKER_SMART': 4,
          'HUSKER_ASPIRATOR': 1,
          'SEPARATOR_DOUBLE': 4,
          'SEPARATOR_SINGLE': 3,
          'WHITENER_MNSL': 3,
          'WHITENER_MNTL': 4,
          'WHITENER_MNSW': 3,
          'WHITENER_MNSW2': 3,
          'POLISHER_MPGW': 4,
          'POLISHER_MPGW2': 4,
          'POLISHER_MPGL': 1,
          'GRADER_MMJX': 3,
          'GRADER_MMJX200_7': 1,
          'GRADER_MMJX100': 1,
          'LENGTH_GRADER_MJXT': 7,
          'FILTER_TBHM': 4,
          'FILTER_TBHM_WD': 2,
          'ELEVATOR_SEC': 5,
          'ELEVATOR_MS': 4,
          'ELEVATOR_TDTG': 8,
          'BELT_TDSG': 4,
          'CHAIN_TGSH': 3,
          'CHAIN_TGSS': 4,
        },
      };
      for (final MapEntry(key: config, value: counts) in expected.entries) {
        final catalog = _parse(config);
        expect(catalog.series, hasLength(counts.length), reason: config.id);
        final actual = <String, int>{};
        for (final m in catalog.machines) {
          actual[m.seriesCode] = (actual[m.seriesCode] ?? 0) + 1;
        }
        expect(actual, counts, reason: config.id);
        expect(
          catalog.machines.map((m) => m.machineId).toSet(),
          hasLength(catalog.machines.length),
          reason: config.id,
        );
      }
    });

    test('tên model đổi B -> A, không còn tên nhà cung cấp', () {
      for (final config in EquipmentCatalogs.all) {
        final catalog = _parse(config);
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
        for (final m in catalog.machines) {
          expect(m.model, isNot(startsWith('B')), reason: m.model);
        }
        for (final banned in ['brightsail', 'bspm', 'bsr-', 'bsst', 'sbd-']) {
          expect(shown, isNot(contains(banned)), reason: config.id);
        }
      }
    });

    test('mỗi model có 2-3 chỉ số nổi bật, thông số kỹ thuật và ô giá trị', () {
      for (final config in EquipmentCatalogs.all) {
        for (final m in _parse(config).machines) {
          // Gàu tải tốc độ chậm: catalog chỉ có năng suất và công suất.
          expect(m.highlights.length, inInclusiveRange(2, 3), reason: m.model);
          if (config != _rice) {
            expect(m.highlights, hasLength(3), reason: m.model);
          }
          expect(
            m.specsOf(EquipmentSpecGroup.technical),
            isNotEmpty,
            reason: m.model,
          );
          final chips = EquipmentSpecSheet(
            config: config,
            machine: m,
            series: null,
          ).chips;
          expect(chips, hasLength(2), reason: m.model);
        }
      }
    });

    test('tiêu chí chọn máy khớp khoá dữ liệu của model', () {
      for (final config in EquipmentCatalogs.all) {
        final catalog = _parse(config);
        final keys = catalog.criteria.map((c) => c.key).toSet();
        expect(keys, isNotEmpty, reason: config.id);
        for (final m in catalog.machines) {
          expect(keys, containsAll(m.selection.keys), reason: m.model);
          expect(keys, containsAll(m.selectionNotes.keys), reason: m.model);
        }
      }
    });

    test('ảnh dòng máy / model đều có trong assets', () async {
      for (final config in EquipmentCatalogs.all) {
        final catalog = _parse(config);
        final paths = {
          config.menuImage,
          for (final s in catalog.series)
            if (s.image case final p?) p,
          for (final m in catalog.machines)
            if (m.image case final p?) p,
        };
        for (final path in paths) {
          final bytes = await rootBundle.load(path);
          expect(bytes.lengthInBytes, greaterThan(1000), reason: path);
        }
      }
    });
  });

  group('Tra cứu catalog', () {
    test('sắp model theo số, tìm không dấu, ảnh model ưu tiên', () async {
      final catalog = await _load(_packing);
      expect(catalog.machinesOf('ASPM_VERTICAL').map((m) => m.model).toList(), [
        'ASPM-320',
        'ASPM-420',
        'ASPM-520',
        'ASPM-620',
        'ASPM-720',
        'ASPM-820',
      ]);
      expect(catalog.search('tra tui loc').map((m) => m.model), [
        'AS-20D',
        'AS-C12',
        'AS-NW160',
      ]);
      expect(catalog.search('aspm-520').single.model, 'ASPM-520');
      expect(
        catalog.imageOf(catalog.machineById('PACK__AS-NW160')!),
        'assets/images/catalog_packing_tea_nw160.png',
      );
      expect(
        catalog.imageOf(catalog.machineById('PACK__ASPM-320')!),
        'assets/images/catalog_packing_aspm_vertical.png',
      );

      final mixer = await _load(_mixer);
      expect(
        mixer.machinesOf('ASR_RIBBON').map((m) => m.model).take(4).toList(),
        ['ASR-100', 'ASR-300', 'ASR-500', 'ASR-1000'],
      );
      expect(mixer.search('chu v').map((m) => m.seriesCode).toSet(), {'ASV_V'});
    });
  });

  group('Thông số / chia sẻ', () {
    test('ô giá trị trên thẻ gọn, text chia sẻ đủ thông số', () async {
      final catalog = await _load(_packing);
      final machine = catalog.machineById('PACK__ASPM-B100')!;
      final sheet = EquipmentSpecSheet(
        config: _packing,
        machine: machine,
        series: catalog.seriesOf(machine.seriesCode),
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

      final mixer = await _load(_mixer);
      final asv = mixer.machineById('MIX__ASV-1000')!;
      final mixerSheet = EquipmentSpecSheet(
        config: _mixer,
        machine: asv,
        series: mixer.seriesOf(asv.seriesCode),
      );
      expect(mixerSheet.title, 'MÁY TRỘN ASV-1000');
      expect(mixerSheet.chips.map((c) => c.$1), ['1 m³', '4 kW']);
      expect(mixerSheet.extraRows.single.label, 'Động cơ thanh tăng cường');
    });

    test('PDF catalog dựng được với font tiếng Việt', () async {
      final catalog = await _load(_sifter);
      final machine = catalog.machineById('SIFT__ASRS-300')!;
      final sheet = EquipmentSpecSheet(
        config: _sifter,
        machine: machine,
        series: catalog.seriesOf(machine.seriesCode),
        imagePath: catalog.imageOf(machine),
      );
      final bytes = await GrindingSpecSheetPdfService.buildCatalogPdf(
        headerTitle: 'CATALOG ${_sifter.upperLabel}',
        footerLabel: 'DTCGroup · Catalog ${_sifter.productLabel}',
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

  group('Chọn máy đóng gói', () {
    late LoadedEquipmentCatalog catalog;
    setUp(() async => catalog = await _load(_packing));

    test('bột 1 kg, 30 túi/phút, đóng túi', () {
      final results = _evaluate(catalog, {
        'form': 'powder',
        'weight': 1000.0,
        'speed': 30.0,
        'packaging': 'bag',
      });
      expect(results, hasLength(20), reason: 'không loại model nào');
      expect(_strong(results), [
        'ASPM-520',
        'ASPM-620',
        'ASPM-720',
        'ASPM-820',
        'ASPM-B',
        'ASPM-C',
      ]);
      // Cân trục vít 50L: bao bì tùy máy đi kèm -> "có thể phù hợp".
      final screw = _match(results, '50L');
      expect(screw.label, GrindingMatchLabel.possible);
      expect(
        screw.criteria.firstWhere((c) => c.label == 'Bao bì').reason,
        contains('thiết bị định lượng'),
      );
      // ASPM-320 chỉ tới 200 g -> không đạt khối lượng.
      final small = _match(results, 'ASPM-320');
      expect(small.label, GrindingMatchLabel.closest);
      expect(
        small.criteria
            .firstWhere((c) => c.label == 'Khối lượng mỗi gói')
            .status,
        GrindingCriterionStatus.notMatch,
      );
    });

    test('trà túi lọc 3 g, tự động hoàn toàn', () {
      final results = _evaluate(catalog, {
        'form': 'tea',
        'weight': 3.0,
        'automation': 'auto',
      });
      expect(_strong(results), ['AS-C12', 'AS-NW160']);
      // AS-20D: catalog không ghi mức tự động -> chưa có dữ liệu, không loại.
      expect(_match(results, 'AS-20D').label, GrindingMatchLabel.possible);
    });

    test('bao lớn 25 kg bán tự động', () {
      final results = _evaluate(catalog, {
        'weight': 25000.0,
        'packaging': 'bigbag',
        'automation': 'semi',
      });
      expect(_strong(results), ['ASPM-B100']);
      expect(results[1].machine.model, 'ASPM-A100');
      expect(results[1].label, GrindingMatchLabel.possible);
    });

    test('máy chỉ ghi mức tối đa (≤ 200 g) chỉ so với mức tối đa', () {
      final results = _evaluate(catalog, {'weight': 5.0});
      final aspm320 = _match(results, 'ASPM-320');
      expect(aspm320.label, GrindingMatchLabel.strong);
      expect(aspm320.criteria.single.actualDisplay, '≤ 200 g');
      final big = _match(results, 'ASPM-A100');
      expect(big.criteria.single.status, GrindingCriterionStatus.notMatch);
      expect(big.criteria.single.actualDisplay, '5 - 50 kg');
      // Đơn vị riêng của model được giữ khi hiển thị tốc độ.
      final speed = _evaluate(catalog, {'speed': 3.0});
      expect(
        _match(speed, 'ASPM-B100').criteria.single.actualDisplay,
        '2 - 4 bao/phút',
      );
    });

    test('công suất điện tối đa', () {
      final results = _evaluate(catalog, {'power': 1.5});
      expect(_strong(results), [
        '2 phễu',
        '4 phễu',
        'AS-20D',
        'ASPM-A',
        'ASPM-B',
        'ASPM-F',
      ]);
    });
  });

  group('Chọn máy trộn', () {
    late LoadedEquipmentCatalog catalog;
    setUp(() async => catalog = await _load(_mixer));

    test('mẻ 500 L bột khô', () {
      final results = _evaluate(catalog, {
        'volume': 500.0,
        'material': 'powder',
      });
      expect(results, hasLength(72));
      expect(_strong(results).toSet(), {
        for (final v in [1000, 2000, 3000, 4000, 10000, 15000]) 'ASD-$v',
        for (final v in [
          1000,
          2000,
          3000,
          4000,
          5000,
          6000,
          8000,
          10000,
          12000,
          15000,
          20000,
        ])
          'ASR-$v',
        'ASTD-800',
        'ASTD-1000',
      });
      // ASR-500 làm việc tối đa 300 L -> không đạt.
      expect(_match(results, 'ASR-500').label, GrindingMatchLabel.closest);
      // AST-300 chỉ có dung tích thùng 300 L: vượt giới hạn -> không đạt.
      final ast = _match(results, 'AST-300').criteria.first;
      expect(ast.status, GrindingCriterionStatus.notMatch);
      expect(ast.actualDisplay, '≤ 300 L');
      // ASV-500 tổng 500 L, chưa biết dung tích nạp -> chưa đủ dữ liệu.
      final asv = _match(results, 'ASV-500').criteria.first;
      expect(asv.status, GrindingCriterionStatus.unknown);
      expect(asv.reason, contains('chưa ghi dung tích nạp tối đa'));
      // ASL: catalog không ghi dạng nguyên liệu -> có thể phù hợp.
      expect(_match(results, 'ASL-1000').label, GrindingMatchLabel.possible);
    });

    test('mẻ 800 kg, nguyên liệu chênh lệch tỉ trọng lớn', () {
      final results = _evaluate(catalog, {
        'batch_weight': 800.0,
        'material': 'density',
      });
      expect(_strong(results), [
        'ASD-3000',
        'ASD-4000',
        'ASD-10000',
        'ASD-15000',
      ]);
      // ASTD hợp dạng nguyên liệu nhưng chưa có khối lượng nạp tối đa.
      expect(_match(results, 'ASTD-1000').label, GrindingMatchLabel.possible);
    });

    test('nhập theo m³ được quy đổi sang L', () {
      final results = _evaluate(catalog, {'volume': 1200.0});
      final asr = _match(results, 'ASR-2000').criteria.single;
      expect(asr.requiredDisplay, '≥ 1.2 m³');
      expect(asr.status, GrindingCriterionStatus.match);
    });
  });

  group('Chọn máy sàng', () {
    late LoadedEquipmentCatalog catalog;
    setUp(() async => catalog = await _load(_sifter));

    test('bột khô 3000 kg/h, lưới 100 mesh', () {
      final results = _evaluate(catalog, {
        'capacity': 3000.0,
        'mesh': 100.0,
        'material': 'powder',
      });
      expect(_strong(results), [
        'ASST-1000',
        'ASST-1200',
        'ASST-1500',
        'ASST-1800',
        'ASST-2000',
      ]);
      expect(_match(results, 'ASRS-300').label, GrindingMatchLabel.closest);
    });

    test('lưới 15 mesh nhỏ hơn mức tối thiểu của sàng quay', () {
      final results = _evaluate(catalog, {'mesh': 15.0});
      final asrs = _match(results, 'ASRS-190').criteria.single;
      expect(asrs.status, GrindingCriterionStatus.notMatch);
      expect(asrs.actualDisplay, '20 - 200 mesh');
      expect(_match(results, 'ASST-600').label, GrindingMatchLabel.strong);
    });

    test('nguyên liệu dính / nhiều xơ 1800 kg/h', () {
      final results = _evaluate(catalog, {
        'capacity': 1800.0,
        'material': 'sticky',
      });
      expect(_strong(results), ['ASRS-300']);
      expect(_match(results, 'ASRS-190').label, GrindingMatchLabel.closest);
    });
  });

  group('Xay xát lúa - gạo', () {
    late LoadedEquipmentCatalog catalog;
    setUp(() async => catalog = await _load(_rice));

    test('xát trắng 8 tấn/giờ, tổng công suất ≤ 60 kW', () {
      final results = _evaluate(catalog, {
        'stage': 'whitening',
        'capacity': 8.0,
        'power': 60.0,
      });
      expect(
        _strong(results),
        unorderedEquals(['MNSL6500A', 'MNTL26B', 'MNSW30D']),
      );
      // MNSL10000 đủ năng suất nhưng tổng 75 - 90 + 3 + 2.2 kW vượt giới hạn.
      final mnsl = _match(results, 'MNSL10000');
      expect(mnsl.label, GrindingMatchLabel.closest);
      expect(mnsl.criteria.last.actualDisplay, '95.2 kW');
      // Thiết bị công đoạn khác không được đề xuất.
      expect(_match(results, 'MPGW158').label, GrindingMatchLabel.closest);
    });

    test('máy bóc vỏ so năng suất theo gạo hạt dài', () {
      final results = _evaluate(catalog, {'stage': 'husking', 'capacity': 8.0});
      // MLGQ51B: gạo dài 6 - 9, gạo tròn 8 - 11.
      expect(_match(results, 'MLGQ51B').label, GrindingMatchLabel.strong);
      // MLGQ36B: gạo dài 5 - 7 → chưa đạt dù gạo tròn tới 9.
      expect(_match(results, 'MLGQ36B').label, GrindingMatchLabel.closest);
      expect(
        _match(results, 'MLGQ36B').criteria.last.actualDisplay,
        '5 - 7 tấn/giờ',
      );
    });

    test('máy sấy / phin lọc không đoán năng suất', () {
      final dryers = _evaluate(catalog, {'stage': 'drying', 'capacity': 10.0});
      for (final m in catalog.machinesOf('DRYER_5H')) {
        final match = _match(dryers, m.model);
        expect(match.label, GrindingMatchLabel.possible, reason: m.model);
        expect(
          match.criteria.last.status,
          GrindingCriterionStatus.unknown,
          reason: m.model,
        );
        expect(m.needsVerification, isTrue, reason: m.model);
      }
      final filters = _evaluate(catalog, {
        'stage': 'dust_filter',
        'capacity': 10.0,
        'power': 5.0,
      });
      final wd = _match(filters, 'TBHM-WD322 × 2000');
      expect(wd.label, GrindingMatchLabel.possible);
      expect(wd.criteria[1].reason, contains('lưu lượng gió'));
      expect(wd.criteria[2].reason, contains('chưa ghi công suất'));
    });

    test('tìm theo công đoạn không dấu và theo model', () {
      expect(catalog.search('may lau bong').map((m) => m.seriesCode).toSet(), {
        'POLISHER_MPGW',
        'POLISHER_MPGW2',
        'POLISHER_MPGL',
      });
      expect(catalog.search('mlgq36b').map((m) => m.model), [
        'MLGQ36B',
        'MLGQ36B × 2',
      ]);
      expect(
        catalog.imageOf(catalog.machineById('RICE__MLGQ25CX2')!),
        'assets/images/rice_husker_mlgq_double.jpg',
      );
    });

    test('thông số giữ đúng số liệu catalog', () {
      final mntl = catalog.machineById('RICE__MNTL28A')!;
      expect(mntl.valueOf('capacity'), '9 - 12 tấn/giờ');
      expect(mntl.valueOf('power_main'), '55 - 75 kW');
      expect(mntl.valueOf('power_kw'), '58.7 - 78.7 kW');
      expect(mntl.valueOf('dimensions'), '1560 x 1470 x 2250 mm');
      expect(mntl.valueOf('weight'), '1850 kg');
      final sheet = EquipmentSpecSheet(
        config: _rice,
        machine: catalog.machineById('RICE__TDSG65')!,
        series: catalog.seriesOf('BELT_TDSG'),
      );
      expect(sheet.chips.map((c) => c.$1), ['48 - 54 tấn/giờ', '2.2 - 7.5 kW']);
      // Catalog bỏ trống khối lượng MPGW190 × 2 → không có dòng khối lượng.
      expect(catalog.machineById('RICE__MPGW190X2')!.valueOf('weight'), isNull);
    });
  });

  testWidgets('Xay xát: trang chính chia nhóm công đoạn -> dòng máy', (
    tester,
  ) async {
    await _pump(tester, _rice);
    expect(find.text('Xay xát Lúa - Gạo'), findsOneWidget);
    expect(find.text('29 dòng · 106 model'), findsOneWidget);
    expect(find.text('SẤY LÚA'), findsOneWidget);

    final group = find.text('XÁT TRẮNG & LAU BÓNG');
    await tester.scrollUntilVisible(group, 300);
    final card = find.byKey(
      const Key('rice_milling_series_card_WHITENER_MNTL'),
    );
    await tester.scrollUntilVisible(card, 200);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('MÁY XÁT TRẮNG TRỤC ĐỨNG MNTL'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('MNTL28A'), 300);
    expect(find.text('MNTL28A'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Máy đóng gói: trang chính -> dòng máy -> thông số đổi model', (
    tester,
  ) async {
    await _pump(tester, _packing);
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
    await _pump(tester, _packing);
    final context = tester.element(find.byType(EquipmentHomeScreen));
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

  testWidgets('Chọn máy đóng gói: yêu cầu -> đề xuất -> so sánh 2 model', (
    tester,
  ) async {
    await _pump(tester, _packing);
    final context = tester.element(find.byType(EquipmentHomeScreen));
    GoRouter.of(context).push('/packing_machine/selector');
    await tester.pumpAndSettle();
    expect(find.byType(EquipmentSelectorScreen), findsOneWidget);
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
    expect(find.byType(EquipmentCompareScreen), findsOneWidget);
    expect(find.text('Khối lượng mỗi túi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Máy trộn: dòng máy -> thông số, chọn máy theo m³', (
    tester,
  ) async {
    await _pump(tester, _mixer);
    expect(find.text('8 dòng · 72 model'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mixer_series_card_ASR_RIBBON')));
    await tester.pumpAndSettle();
    expect(find.text('MÁY TRỘN RIBBON (BĂNG XOẮN)'), findsOneWidget);
    final tile = find.byKey(const Key('mixer_machine_tile_MIX__ASR-1000'));
    await tester.scrollUntilVisible(
      tile,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('MÁY TRỘN ASR-1000'), findsOneWidget);
    expect(find.text('Dung tích (L)'), findsOneWidget);

    final context = tester.element(find.byType(Scaffold).last);
    GoRouter.of(context).push('/mixer_machine/selector');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('mixer_selector_volume_field')),
      '10',
    );
    await tester.tap(find.byKey(const Key('mixer_selector_volume_unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('m³').last);
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('mixer_selector_submit_button'));
    await tester.scrollUntilVisible(
      submit,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(submit);
    await tester.pumpAndSettle();
    // 10 m³ = 10.000 L: chỉ ASR-20000 (12.000 L) đạt.
    expect(find.text('Máy được đề xuất (1)'), findsOneWidget);
    expect(
      find.byKey(const Key('mixer_selector_match_MIX__ASR-20000')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Menu trung gian hiện máy nghiền + 3 catalog thiết bị', (
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
    final catalogs = _provider();
    addTearDown(catalogs.dispose);
    final router = GoRouter(
      initialLocation: '/grinding_menu',
      routes: [
        GoRoute(
          path: '/grinding_menu',
          builder: (_, _) => const GrindingMenuScreen(),
        ),
        for (final config in EquipmentCatalogs.powderLine)
          ...equipmentRoutes(config),
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
            ChangeNotifierProvider.value(value: catalogs),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      while (grinding.isLoading ||
          !EquipmentCatalogs.powderLine.every(catalogs.isLoaded)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pump();

    expect(find.text('Máy nghiền & dây chuyền bột'), findsOneWidget);
    expect(find.text('12 dòng · 57 model'), findsOneWidget);
    expect(find.text('7 dòng · 20 model'), findsOneWidget);
    expect(find.text('8 dòng · 72 model'), findsOneWidget);
    expect(find.text('2 dòng · 9 model'), findsOneWidget);
    expect(find.text('Máy trộn (Mixer)'), findsOneWidget);
    expect(find.text('Máy sàng (Sifter)'), findsOneWidget);

    final sifter = find.byKey(const Key('grinding_menu_sifter_btn'));
    await tester.ensureVisible(sifter);
    await tester.pumpAndSettle();
    await tester.tap(sifter);
    await tester.pumpAndSettle();
    expect(find.text('Máy sàng'), findsOneWidget);
    expect(find.text('2 dòng · 9 model'), findsOneWidget);
  });
}
