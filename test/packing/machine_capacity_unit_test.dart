import 'dart:async';

import 'package:dtc_product/models/machine_match_result.dart';
import 'package:dtc_product/models/machine_selector_request.dart';
import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/providers/machine_selector_provider.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';
import 'package:dtc_product/screens/packing/machine_selector_screen.dart';
import 'package:dtc_product/services/machine_selector_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Repository implements PackingMachineRepository {
  final List<PackingMachine> machines;
  Completer<List<PackingMachine>>? pending;
  _Repository(this.machines);

  @override
  Future<List<PackingMachine>> getMachinesForSelector({
    String? bagMaterial,
    double? weightKg,
  }) async => pending == null ? machines : pending!.future;

  @override
  Future<List<String>> getDistinctBagMaterials() async => ['PE'];
  @override
  Future<List<String>> getDistinctBagEdges() async => ['6 cạnh'];
  @override
  Future<List<String>> getDistinctAutomationLevels() async => ['Tự động'];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

PackingMachine _machine(String? unit, {double? max = 600, double? min}) =>
    PackingMachine(
      id: 1,
      model: 'TEST',
      capacityUnit: unit,
      capacityMax: max,
      capacityMin: min,
    );

Future<MachineMatchResult> _match(
  PackingMachine machine,
  MachineSelectorRequest request,
) async =>
    (await MachineSelectorService(repository: _Repository([machine]))
            .findSuitableMachines(request))
        .single;

void main() {
  test('mặc định túi/giờ; công suất bằng giới hạn vẫn phù hợp', () async {
    final result = await _match(
      _machine('túi/giờ'),
      const MachineSelectorRequest(requestedCapacity: 600),
    );
    expect(result.matchLevel, MatchLevel.bestMatch);
  });

  test('3 tấn/giờ với túi 5 kg được so sánh với 600 túi/giờ', () async {
    final result = await _match(
      _machine('túi/giờ'),
      const MachineSelectorRequest(
        requestedCapacity: 3,
        requestedWeightKg: 5,
        capacityUnit: 'tấn/giờ',
      ),
    );
    expect(result.matchLevel, MatchLevel.bestMatch);
    expect(result.matchReasons.join(' '), contains('3 tấn/giờ'));
    expect(result.matchReasons.join(' '), contains('600 túi/giờ'));
    expect(result.matchReasons.join(' '), contains('5 kg/túi'));
  });

  test('quy đổi ngược túi/giờ sang tấn/giờ', () async {
    final result = await _match(
      _machine('tấn/giờ', max: 3),
      const MachineSelectorRequest(
        requestedCapacity: 600,
        requestedWeightKg: 5,
      ),
    );
    expect(result.matchLevel, MatchLevel.bestMatch);
    expect(result.matchReasons.join(' '), contains('600 túi/giờ = 3 tấn/giờ'));
  });

  test('quy đổi không làm nhu cầu vượt công suất trở thành phù hợp', () async {
    final result = await _match(
      _machine('túi/giờ'),
      const MachineSelectorRequest(
        requestedCapacity: 3.01,
        requestedWeightKg: 5,
        capacityUnit: 'tấn/giờ',
      ),
    );
    expect(result.matchLevel, MatchLevel.notSuitable);
    expect(result.mismatchReasons.join(' '), contains('3.01 tấn/giờ'));
    expect(result.mismatchReasons.join(' '), contains('602 túi/giờ'));
  });

  test(
    'khác đơn vị nhưng thiếu kg/túi không được khẳng định phù hợp',
    () async {
      final result = await _match(
        _machine('tấn/giờ', max: 3),
        const MachineSelectorRequest(requestedCapacity: 1),
      );
      expect(result.matchLevel, MatchLevel.notSuitable);
      expect(result.mismatchReasons.join(' '), contains('khối lượng mỗi túi'));
    },
  );

  test(
    'bao/giờ và túi/giờ dùng cùng số lượng; khoảng trắng không gây lỗi',
    () async {
      final result = await _match(
        _machine(' Bao / Giờ '),
        const MachineSelectorRequest(requestedCapacity: 600),
      );
      expect(result.matchLevel, MatchLevel.bestMatch);
    },
  );

  for (final unit in [null, '', 'tấn', 'kg/giờ']) {
    test(
      'không suy diễn đơn vị catalog "$unit" thành năng suất theo giờ',
      () async {
        final result = await _match(
          _machine(unit),
          const MachineSelectorRequest(requestedCapacity: 1),
        );
        expect(result.matchLevel, MatchLevel.notSuitable);
        expect(result.mismatchReasons.join(' '), contains('đơn vị catalog'));
      },
    );
  }

  test('không bỏ qua đơn vị yêu cầu chưa xác định', () async {
    final result = await _match(
      _machine('túi/giờ'),
      const MachineSelectorRequest(requestedCapacity: 1, capacityUnit: null),
    );
    expect(result.matchLevel, MatchLevel.notSuitable);
  });

  for (final max in [null, 0.0, -1.0, double.nan, double.infinity]) {
    test('thiếu hoặc sai công suất tối đa $max không được đề xuất', () async {
      final result = await _match(
        _machine('túi/giờ', max: max),
        const MachineSelectorRequest(requestedCapacity: 1),
      );
      expect(result.matchLevel, MatchLevel.notSuitable);
      expect(
        result.mismatchReasons.join(' '),
        contains('dải năng suất hợp lệ'),
      );
    });
  }

  test('dải catalog có min lớn hơn max không được đề xuất', () async {
    final result = await _match(
      _machine('túi/giờ', min: 700),
      const MachineSelectorRequest(requestedCapacity: 1),
    );
    expect(result.matchLevel, MatchLevel.notSuitable);
  });

  for (final value in [0.0, -1.0, double.nan, double.infinity]) {
    test('chặn năng suất và khối lượng không hợp lệ $value', () async {
      final service = MachineSelectorService(repository: _Repository([]));
      await expectLater(
        service.findSuitableMachines(
          MachineSelectorRequest(requestedCapacity: value),
        ),
        throwsArgumentError,
      );
      await expectLater(
        service.findSuitableMachines(
          MachineSelectorRequest(requestedWeightKg: value),
        ),
        throwsArgumentError,
      );
    });
  }

  test('quy đổi tràn số không crash hoặc đề xuất nhầm', () async {
    final result = await _match(
      _machine('túi/giờ'),
      const MachineSelectorRequest(
        requestedCapacity: double.maxFinite,
        requestedWeightKg: 5,
        capacityUnit: 'tấn/giờ',
      ),
    );
    expect(result.matchLevel, MatchLevel.notSuitable);
    expect(result.mismatchReasons.join(' '), contains('Không thể quy đổi'));
  });

  test('thay đơn vị xóa kết quả cũ và reset về túi/giờ', () async {
    final provider = MachineSelectorProvider(
      repository: _Repository([_machine('túi/giờ')]),
    );
    addTearDown(provider.dispose);
    provider.setCapacity(600);
    await provider.findMachines();
    expect(provider.suitableResults, hasLength(1));
    provider.setCapacityUnit('tấn/giờ');
    expect(provider.results, isEmpty);
    expect(provider.hasSearched, isFalse);
    provider.resetForm();
    expect(provider.selectedCapacityUnit, 'túi/giờ');
    expect(provider.requestedCapacity, isNull);
  });

  test('kết quả tìm đang chạy không được gán cho đơn vị mới', () async {
    final repo = _Repository([_machine('túi/giờ')])
      ..pending = Completer<List<PackingMachine>>();
    final provider = MachineSelectorProvider(repository: repo);
    addTearDown(provider.dispose);
    provider.setCapacity(600);
    final search = provider.findMachines();
    provider.setCapacityUnit('tấn/giờ');
    repo.pending!.complete(repo.machines);
    await search;
    expect(provider.results, isEmpty);
    expect(provider.hasSearched, isFalse);
    expect(provider.isSearching, isFalse);
  });

  testWidgets('form 320px hiển thị đúng bộ lọc lưu trước và cho đổi đơn vị', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = MachineSelectorProvider(repository: _Repository([]))
      ..setBagMaterial('PE')
      ..setWeightKg(5)
      ..setCapacity(3)
      ..setCapacityUnit('tấn/giờ');
    await provider.loadOptions();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: MachineSelectorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('capacity_input'));
    await tester.ensureVisible(field);
    expect(tester.widget<TextFormField>(field).controller!.text, '3.0');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('weight_input')))
          .controller!
          .text,
      '5.0',
    );
    await tester.tap(find.byKey(const Key('capacity_unit_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('túi/giờ').last);
    await tester.pumpAndSettle();
    expect(provider.selectedCapacityUnit, 'túi/giờ');
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: field, matching: find.byType(TextField)),
          )
          .decoration!
          .suffixText,
      'túi/giờ',
    );
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).controller!.text, '');
    expect(provider.selectedCapacityUnit, 'túi/giờ');
    expect(tester.takeException(), isNull);
  });
}
