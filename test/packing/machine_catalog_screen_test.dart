import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';
import 'package:dtc_product/screens/packing/machine_catalog_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePackingMachineRepository extends PackingMachineRepository {
  static const machines = [
    PackingMachine(
      id: 1,
      model: 'DTC-PACK-100',
      productGroup: 'Túi PE hút chân không',
      machineLine: 'Máy đóng gói tự động',
    ),
  ];

  @override
  Future<List<String>> getDistinctProductGroups() async => const [
    'Túi PE hút chân không',
  ];

  @override
  Future<List<PackingMachine>> getMachinesByGroup(String productGroup) async =>
      machines
          .where((machine) => machine.productGroup == productGroup)
          .toList();
}

void main() {
  testWidgets('danh mục sản phẩm hiển thị đúng Unicode tiếng Việt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MachineCatalogScreen(repository: _FakePackingMachineRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Danh mục sản phẩm'), findsOneWidget);
    expect(
      find.text('1 model · Chọn dòng máy để xem chi tiết'),
      findsOneWidget,
    );
    expect(find.text('Túi PE hút chân không'), findsNWidgets(2));
    expect(
      find.widgetWithText(
        TextField,
        'Tìm theo model, nhóm máy, loại vật liệu...',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
