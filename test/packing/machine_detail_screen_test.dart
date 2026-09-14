import 'package:dtc_product/models/packing_machine.dart';
import 'package:dtc_product/providers/compare_provider.dart';
import 'package:dtc_product/repositories/packing_machine_repository.dart';
import 'package:dtc_product/screens/packing/machine_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakePackingMachineRepository extends PackingMachineRepository {
  @override
  Future<PackingMachine?> getMachineByModel(String model) async =>
      const PackingMachine(
        id: 1,
        model: 'LCJ-10T-8',
        productGroup: 'Định lượng',
        machineLine: 'Máy trộn gạo',
        imageMainPath: 'assets/images/packing/lcj_icon.png',
        image2Path: 'assets/images/packing/lcj_background.png',
      );
}

void main() {
  testWidgets(
    'trang chi tiết hiển thị và mở đặc điểm nổi bật trên điện thoại',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => CompareProvider(),
          child: MaterialApp(
            theme: ThemeData(useMaterial3: true),
            home: MachineDetailScreen(
              modelName: 'LCJ-10T-8',
              showCatalog: false,
              repository: _FakePackingMachineRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LCJ-10T-8'), findsOneWidget);
      expect(find.text('Đặc điểm nổi bật'), findsOneWidget);
      expect(
        find.text('Tự điều chỉnh đúng lưu lượng trong khi vận hành.'),
        findsNothing,
      );

      final feature = find.text('Tự động phát hiện lỗi');
      await tester.scrollUntilVisible(
        feature,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(feature);
      await tester.pumpAndSettle();

      expect(feature, findsNWidgets(2));
      expect(
        find.text(
          'Chức năng tự động phát hiện sai lệch và điều chỉnh đúng lưu lượng '
          'trong lúc vận hành, giúp quá trình phối trộn duy trì ổn định.',
        ),
        findsOneWidget,
      );
      expect(find.text('Đóng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
