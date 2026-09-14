import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/providers/compare_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const machines = [
    PackingMachine(id: 1, model: 'MODEL-1'),
    PackingMachine(id: 2, model: 'MODEL-2'),
    PackingMachine(id: 3, model: 'MODEL-3'),
    PackingMachine(id: 4, model: 'MODEL-4'),
  ];

  group('CompareProvider', () {
    test('không thêm trùng cùng một model', () {
      final provider = CompareProvider();

      provider.addMachineObject(machines[0]);
      provider.addMachineObject(const PackingMachine(id: 99, model: 'MODEL-1'));

      expect(provider.count, 1);
      expect(provider.selectedMachines, [machines[0]]);
      expect(provider.isSelected('MODEL-1'), isTrue);
    });

    test('chỉ cho phép chọn tối đa 3 model', () {
      final provider = CompareProvider();

      for (final machine in machines) {
        provider.addMachineObject(machine);
      }

      expect(provider.count, CompareProvider.maxModels);
      expect(provider.isFull, isTrue);
      expect(provider.isSelected('MODEL-4'), isFalse);
    });

    test('canCompare chỉ bật khi đã chọn ít nhất 2 model', () {
      final provider = CompareProvider();

      expect(provider.canCompare, isFalse);
      provider.addMachineObject(machines[0]);
      expect(provider.canCompare, isFalse);
      provider.addMachineObject(machines[1]);
      expect(provider.canCompare, isTrue);
    });

    test('xóa một model và xóa toàn bộ cập nhật đúng trạng thái', () {
      final provider = CompareProvider();
      provider
        ..addMachineObject(machines[0])
        ..addMachineObject(machines[1])
        ..addMachineObject(machines[2]);

      provider.removeMachine('MODEL-2');

      expect(provider.count, 2);
      expect(provider.isSelected('MODEL-2'), isFalse);
      expect(provider.canCompare, isTrue);
      expect(provider.isFull, isFalse);

      provider.clearAll();

      expect(provider.selectedMachines, isEmpty);
      expect(provider.count, 0);
      expect(provider.canCompare, isFalse);
      expect(provider.isFull, isFalse);
    });
  });
}
