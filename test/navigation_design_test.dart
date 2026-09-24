import 'package:dtc_product/models/daily_goal.dart';
import 'package:dtc_product/providers/daily_goals_provider.dart';
import 'package:dtc_product/providers/settings_provider.dart';
import 'package:dtc_product/repositories/daily_goal_repository.dart';
import 'package:dtc_product/screens/color_sorter_menu_screen.dart';
import 'package:dtc_product/screens/extensions_screen.dart';
import 'package:dtc_product/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository giả rỗng — các test ở đây không quan tâm dữ liệu Mục tiêu hôm
/// nay, chỉ cần DailyGoalsProvider tồn tại để HomeScreen không lỗi thiếu
/// provider.
class _EmptyDailyGoalRepository extends DailyGoalRepository {
  @override
  Future<List<DailyGoal>> getGoalsForDate(DateTime date) async => const [];
}

Future<void> _pumpAtSize(
  WidgetTester tester, {
  required Size size,
  required Widget home,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(prefs),
        ),
        ChangeNotifierProvider<DailyGoalsProvider>(
          create: (_) =>
              DailyGoalsProvider(repository: _EmptyDailyGoalRepository()),
        ),
      ],
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home Screen hiển thị hài hòa trên điện thoại', (tester) async {
    await _pumpAtSize(
      tester,
      size: const Size(390, 844),
      home: const HomeScreen(),
    );

    expect(find.byKey(const Key('home_brand_wordmark')), findsOneWidget);
    expect(find.text('Giải pháp công nghệ - Danh mục sản phẩm'), findsNothing);
    expect(find.text('Máy tách màu'), findsOneWidget);
    expect(find.text('Máy nén khí'), findsOneWidget);
    expect(find.text('Cân đóng gói'), findsOneWidget);
    expect(find.text('Máy nghiền'), findsOneWidget);
    expect(find.text('Công cụ & Tiện ích'), findsOneWidget);
    expect(find.text('DTCGroup'), findsOneWidget);
    expect(find.text('Tra cứu model hoặc chức năng'), findsOneWidget);
    expect(find.text('Tra cứu nhanh'), findsNothing);
    expect(find.text('Tính toán kỹ thuật'), findsNothing);
    expect(find.text('Tài liệu vận hành'), findsNothing);
    expect(
      find.byKey(const ValueKey('home_solution_/color_sorter_categories')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home_solution_/acomp_menu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home_solution_/packing_menu')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home_solution_/grinding_machine')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home_solution_/extensions')),
      findsOneWidget,
    );
    final compressorCard = tester.getRect(
      find.byKey(const ValueKey('home_solution_/acomp_menu')),
    );
    final grindingMachineCard = tester.getRect(
      find.byKey(const ValueKey('home_solution_/grinding_machine')),
    );
    final extensionsCard = tester.getRect(
      find.byKey(const ValueKey('home_solution_/extensions')),
    );
    // Lưới 2 cột trên điện thoại: 5 mục -> "Máy nén khí" + "Máy nghiền" (mục
    // thứ 3-4) cùng hàng, "Công cụ & Tiện ích" (mục thứ 5, lẻ) xuống hàng
    // riêng bên dưới.
    expect(compressorCard.top, grindingMachineCard.top);
    expect(compressorCard.size, grindingMachineCard.size);
    expect(compressorCard.left, lessThan(grindingMachineCard.left));
    expect(grindingMachineCard.right, lessThanOrEqualTo(372));
    expect(extensionsCard.top, greaterThan(compressorCard.top));
    expect(
      tester.getCenter(find.byKey(const Key('home_brand_wordmark'))).dx,
      closeTo(195, 1),
    );
    expect(tester.getBottomRight(find.text('DTCGroup')).dy, greaterThan(820));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home Screen hiển thị lưới tối giản trên desktop', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      size: const Size(1440, 1000),
      home: const HomeScreen(),
    );

    final first = tester.getRect(
      find.byKey(const ValueKey('home_solution_/color_sorter_categories')),
    );
    final second = tester.getRect(
      find.byKey(const ValueKey('home_solution_/packing_menu')),
    );
    final third = tester.getRect(
      find.byKey(const ValueKey('home_solution_/acomp_menu')),
    );
    expect(first.top, second.top);
    expect(second.top, third.top);
    expect(first.left, lessThan(second.left));
    expect(second.left, lessThan(third.left));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Công cụ & Tiện ích hiển thị chức năng lập form lưu mẫu', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      size: const Size(390, 844),
      home: const ExtensionsScreen(),
    );

    expect(find.text('Công cụ & Tiện ích'), findsOneWidget);
    expect(find.text('Lập Form Lưu Mẫu'), findsOneWidget);
    expect(find.byKey(const Key('extension_sample_record')), findsOneWidget);
    expect(find.text('Project Timeline'), findsOneWidget);
    expect(find.byKey(const Key('extension_project_tracking')), findsOneWidget);
    expect(find.text('Phân tích hoàn vốn'), findsNothing);
    expect(find.text('Thiết bị phụ trợ máy tách màu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('menu trung gian hiển thị lưới chức năng trên điện thoại', (
    tester,
  ) async {
    await _pumpAtSize(
      tester,
      size: const Size(390, 844),
      home: const ColorSorterMenuScreen(),
    );

    expect(find.text('Trung tâm chức năng'), findsOneWidget);
    expect(find.text('6 mục'), findsOneWidget);
    expect(find.text('Phân loại nông sản thông minh'), findsNothing);
    expect(
      find.text('Chọn nội dung bạn cần tra cứu hoặc tính toán'),
      findsNothing,
    );
    expect(
      find.text('Tra cứu cấu hình và thông số các dòng máy tách màu.'),
      findsNothing,
    );
    expect(find.text('Mở chức năng'), findsNothing);
    expect(find.byIcon(Icons.data_object_rounded), findsNothing);
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
    expect(find.byKey(const Key('color_sorter_specs_btn')), findsOneWidget);
    expect(find.byKey(const Key('color_sorter_manual_btn')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('color_sorter_manual_btn'))).bottom,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);
  });
}
