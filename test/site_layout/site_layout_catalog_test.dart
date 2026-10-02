import 'package:flutter_test/flutter_test.dart';
import 'package:dtc_product/features/site_layout/repositories/machine_layout_catalog_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalog hợp nhất đọc nguồn hiện có và giữ tên máy nghiền tiếng Việt',
    (tester) async {
      final machines = await tester.runAsync(
        () => MachineLayoutCatalogRepository().getAll(),
      );
      expect(machines, isNotNull);
      expect(machines!.any((item) => item.sourceType == 'grinding'), isTrue);
      expect(machines.any((item) => item.sourceType == 'packing'), isTrue);
      expect(machines.any((item) => item.sourceType == 'compressor'), isTrue);
      expect(machines.any((item) => item.sourceType == 'color_sorter'), isTrue);
      expect(
        machines.any(
          (item) =>
              item.sourceType == 'grinding' &&
              item.displayName.contains('Máy nghiền siêu mịn'),
        ),
        isTrue,
      );
      final suspicious = machines.firstWhere((item) => item.model == 'S+80D');
      expect(suspicious.canPlace, isFalse);
    },
  );
}
