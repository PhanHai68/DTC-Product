import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/providers/compare_provider.dart';
import 'package:dtc_product/providers/packing_provider.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';
import 'package:dtc_product/screens/packing/compare_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePackingMachineRepository extends PackingMachineRepository {
  _FakePackingMachineRepository(this.machines);

  final List<PackingMachine> machines;

  @override
  Future<List<PackingMachine>> getAllMachines() async => machines;

  @override
  Future<List<String>> getDistinctProductGroups() async => machines
      .map((machine) => machine.productGroup)
      .whereType<String>()
      .toSet()
      .toList();

  @override
  Future<PackingMachine?> getMachineByModel(String model) async {
    for (final machine in machines) {
      if (machine.model == model) return machine;
    }
    return null;
  }
}

void main() {
  const machines = [
    PackingMachine(
      id: 1,
      stt: 1,
      model: 'DTC-PACK-100',
      productGroup: 'Túi PE',
      machineLine: 'Máy đóng gói tự động',
      bagMaterial: 'PE',
      bagEdges: '2 cạnh',
      weightMinKg: 1,
      weightMaxKg: 10,
      capacityMin: 500,
      capacityMax: 600,
      capacityUnit: 'túi/giờ',
    ),
    PackingMachine(
      id: 2,
      stt: 2,
      model: 'DTC-PACK-200',
      productGroup: 'Túi PE',
      machineLine: 'Máy đóng gói tự động',
      bagMaterial: 'PE',
      bagEdges: '6 cạnh',
      weightMinKg: 5,
      weightMaxKg: 25,
      capacityMin: 400,
      capacityMax: 500,
      capacityUnit: 'túi/giờ',
    ),
    PackingMachine(
      id: 3,
      stt: 3,
      model: 'DTC-PACK-300',
      productGroup: 'Bao PP',
      machineLine: 'Máy cân định lượng',
      bagMaterial: 'PP',
      weightMinKg: 10,
      weightMaxKg: 50,
      capacityMin: 300,
      capacityMax: 400,
      capacityUnit: 'bao/giờ',
    ),
    PackingMachine(
      id: 4,
      stt: 4,
      model: 'DTC-PACK-400',
      productGroup: 'Bao PP',
      machineLine: 'Máy cân định lượng',
      bagMaterial: 'PP',
      weightMinKg: 20,
      weightMaxKg: 80,
      capacityMin: 200,
      capacityMax: 300,
      capacityUnit: 'bao/giờ',
    ),
  ];

  testWidgets('chọn, xác nhận và chỉnh lại 2-3 model trên màn hình desktop', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakePackingMachineRepository(machines);
    final packingProvider = PackingProvider(repository: repository);
    final compareProvider = CompareProvider(repository: repository);
    addTearDown(packingProvider.dispose);
    addTearDown(compareProvider.dispose);
    await packingProvider.loadAll();
    expect(packingProvider.errorMessage, isNull);
    expect(packingProvider.machines, hasLength(machines.length));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PackingProvider>.value(value: packingProvider),
          ChangeNotifierProvider<CompareProvider>.value(value: compareProvider),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const CompareScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    for (final machine in machines) {
      expect(find.text(machine.model), findsOneWidget);
      expect(
        find.byKey(ValueKey('choose_model_${machine.model}')),
        findsOneWidget,
      );
    }

    final confirmFinder = find.byKey(const Key('confirm_compare_button'));
    expect(confirmFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);
    expect(find.text('BẢNG SO SÁNH'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('choose_model_DTC-PACK-100')));
    await tester.pump();

    expect(compareProvider.count, 1);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('select_DTC-PACK-200')));
    await tester.pump();

    expect(compareProvider.count, 2);
    expect(tester.widget<FilledButton>(confirmFinder).onPressed, isNotNull);
    expect(find.text('BẢNG SO SÁNH'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    expect(find.text('BẢNG SO SÁNH'), findsOneWidget);
    expect(find.text('Chọn lại'), findsOneWidget);
    expect(compareProvider.count, 2);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('edit_compare_selection_button')));
    await tester.pumpAndSettle();

    expect(find.text('BẢNG SO SÁNH'), findsNothing);
    expect(compareProvider.count, 2);
    expect(compareProvider.isSelected('DTC-PACK-100'), isTrue);
    expect(compareProvider.isSelected('DTC-PACK-200'), isTrue);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('select_DTC-PACK-300')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select_DTC-PACK-400')));
    await tester.pumpAndSettle();

    expect(compareProvider.count, CompareProvider.maxModels);
    expect(compareProvider.isSelected('DTC-PACK-300'), isTrue);
    expect(compareProvider.isSelected('DTC-PACK-400'), isFalse);
    expect(find.text('Đã chọn tối đa 3 model'), findsOneWidget);
    expect(find.text('Chỉ có thể chọn tối đa 3 model.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hiển thị và thao tác được nút chọn model trên điện thoại', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _FakePackingMachineRepository(machines);
    final packingProvider = PackingProvider(repository: repository);
    final compareProvider = CompareProvider(repository: repository);
    addTearDown(packingProvider.dispose);
    addTearDown(compareProvider.dispose);
    await packingProvider.loadAll();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PackingProvider>.value(value: packingProvider),
          ChangeNotifierProvider<CompareProvider>.value(value: compareProvider),
        ],
        child: MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const CompareScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chooseButton = find.byKey(
      const ValueKey('choose_model_DTC-PACK-100'),
    );
    expect(chooseButton, findsOneWidget);
    expect(find.text('Chọn model'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(chooseButton);
    await tester.pump();

    expect(compareProvider.isSelected('DTC-PACK-100'), isTrue);
    expect(find.text('Bỏ chọn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
