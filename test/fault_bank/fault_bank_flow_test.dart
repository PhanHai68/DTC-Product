import 'dart:io';

import 'package:dtc_product/features/fault_bank/data/fault_bank_database.dart';
import 'package:dtc_product/features/fault_bank/fault_bank_routes.dart';
import 'package:dtc_product/features/fault_bank/providers/fault_bank_provider.dart';
import 'package:dtc_product/features/fault_bank/repositories/fault_bank_repository.dart';
import 'package:dtc_product/features/fault_bank/services/fault_file_storage.dart';
import 'package:dtc_product/features/fault_bank/services/fault_photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Chờ I/O thật (SQLite) rồi dựng lại khung hình.
Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  testWidgets('Hồ sơ -> ghi nhận sự cố -> chi tiết -> tìm "dong co" -> xóa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    late Database db;
    late Directory photos;
    await tester.runAsync(() async {
      sqfliteFfiInit();
      db = await databaseFactoryFfiNoIsolate.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await FaultBankDatabase.instance.createSchemaForTesting(db);
      photos = await Directory.systemTemp.createTemp('fault_bank_test');
    });
    addTearDown(() async {
      await db.close();
      await photos.delete(recursive: true);
    });

    final router = GoRouter(
      initialLocation: '/fault-bank',
      routes: [
        buildFaultBankRoutes(
          createProvider: () => FaultBankProvider(
            repository: FaultBankRepository(
              database: FaultBankDatabase.forTesting(db),
            ),
            photoService: FaultPhotoService(
              storage: FaultFileStorage(rootOverride: photos),
            ),
            searchDebounce: Duration.zero,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await _settle(tester);

    // 1. Lần đầu: nhập hồ sơ kỹ sư.
    expect(find.text('Hồ sơ kỹ sư'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('fault_profile_name')), 'An');
    expect(find.byKey(const Key('fault_profile_code')), findsNothing);
    await _tap(tester, find.byKey(const Key('fault_profile_save')));
    expect(find.text('Chưa có lỗi nào được ghi lại.'), findsOneWidget);

    // 2. Ghi nhận sự cố, thêm model máy ngay tại form.
    await _tap(tester, find.byKey(const Key('fault_bank_add')));
    expect(find.text('Ghi nhận sự cố'), findsWidgets);
    await _tap(tester, find.byKey(const Key('fault_form_machine')));
    await _tap(tester, find.byKey(const Key('fault_model_add_button')));
    expect(find.text('Hãng'), findsNothing);
    expect(find.text('Nhóm thiết bị'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('fault_model_name_field')),
      'SC16 Pro',
    );
    await _tap(tester, find.byKey(const Key('fault_model_save')));
    expect(find.text('SC16 Pro'), findsOneWidget);
    expect(find.text('Chèn hình ảnh mô tả'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fault_form_symptom')),
      'Động cơ quá nhiệt, máy dừng',
    );
    await tester.enterText(
      find.byKey(const Key('fault_form_cause')),
      'Quạt làm mát kẹt bụi',
    );
    await tester.enterText(
      find.byKey(const Key('fault_form_step_0')),
      'Vệ sinh quạt',
    );
    await tester.enterText(
      find.byKey(const Key('fault_form_tagname')),
      'CS-01',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('fault_form_duration')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('fault_form_duration')), '1,5');
    await _settle(tester);
    await _tap(tester, find.byKey(const Key('fault_form_save')));

    // 3. Chuyển sang Chi tiết.
    expect(find.text('Chi tiết lỗi'), findsOneWidget);
    expect(find.text('Động cơ quá nhiệt, máy dừng'), findsOneWidget);
    expect(find.text('Tagname CS-01'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('1,5 giờ'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1,5 giờ'), findsOneWidget);
    expect(find.textContaining('Người ghi: An'), findsOneWidget);
    expect(find.byKey(const Key('fault_detail_share_pdf')), findsOneWidget);

    // 4. Về Tra cứu, gõ không dấu.
    await tester.pageBack();
    await _settle(tester);
    await tester.enterText(
      find.byKey(const Key('fault_bank_search')),
      'dong co',
    );
    await _settle(tester);
    expect(find.text('1 bản ghi'), findsOneWidget);
    expect(find.text('SC16 Pro'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('fault_bank_search')),
      'camera',
    );
    await _settle(tester);
    expect(find.text('0 bản ghi'), findsOneWidget);

    // 5. Xóa từ màn chi tiết -> không còn trong tra cứu.
    await tester.enterText(find.byKey(const Key('fault_bank_search')), '');
    await _settle(tester);
    await _tap(tester, find.textContaining('Động cơ quá nhiệt'));
    await _tap(tester, find.byKey(const Key('fault_detail_delete')));
    await _tap(tester, find.byKey(const Key('fault_detail_confirm_delete')));
    expect(find.text('Chưa có lỗi nào được ghi lại.'), findsOneWidget);

    final rows = await tester.runAsync(() => db.query('fault_records'));
    expect(rows, hasLength(1));
    expect(rows!.single['is_deleted'], 1);
  });
}
