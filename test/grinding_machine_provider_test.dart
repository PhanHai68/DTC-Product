import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dtc_product/features/grinding_machine/data/grinding_machine_database.dart';
import 'package:dtc_product/features/grinding_machine/providers/grinding_machine_provider.dart';
import 'package:dtc_product/features/grinding_machine/repositories/grinding_machine_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late GrindingMachineRepository repository;
  late GrindingMachineProvider provider;
  Map<String, dynamic> updated() {
    final root = jsonDecode(
      File('assets/database/grinding_machine_seed.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    root['databaseVersion'] = '2.3';
    root['models'][0]['capacityMaxKgH'] = 350;
    return root;
  }

  Uint8List bytes(Map<String, dynamic> root) =>
      Uint8List.fromList(utf8.encode(jsonEncode(root)));

  setUp(() async {
    sqfliteFfiInit();
    db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await GrindingMachineDatabase.instance.createSchemaForTesting(db);
    repository = GrindingMachineRepository(
      database: GrindingMachineDatabase.forTesting(db),
    );
    provider = GrindingMachineProvider(repository: repository);
    await provider.loadHome();
  });
  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  test('Preview không ghi DB; apply làm mới cache và không bị seed ghi đè sau mở lại', () async {
    final preview = await provider.previewImport('new.json', bytes(updated()));
    expect(preview.report.canImport, isTrue);
    expect(preview.updated, contains('ASC_COARSE__ASC-200'));
    expect(
      (await repository.getMachineByModel('ASC-200'))!.capacityMaxKgH,
      300,
    );
    await Future.wait([provider.applyImport(preview), provider.loadHome()]);
    expect(
      provider.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH,
      350,
    );
    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();
    expect(
      reopened.machines.firstWhere((m) => m.model == 'ASC-200').capacityMaxKgH,
      350,
    );
    expect(await repository.getImportedDatabaseVersion(), '2.3');
  });

  test(
    'Preview thống kê thêm/xóa/inactive và cập nhật đủ dữ liệu con',
    () async {
      final root = updated();
      final removed =
          (root['models'] as List).removeAt(0) as Map<String, dynamic>;
      (root['models'] as List).add({
        ...removed,
        'machineId': 'ASC_COARSE__ASC-NEW',
        'model': 'ASC-NEW',
      });
      root['models'][0]['active'] = false;
      root['selectionTags'][0]['tag'] = 'updated_tag';
      root['extraSpecs'][0]['specValueNumber'] = 222;
      root['series'][0]['nameVi'] = 'Tên cập nhật';
      root['materials'][0]['nameVi'] = 'Vừng cập nhật';
      root['materialSeriesMap'][0]['scoreAdjustment'] = 10;
      root['aiConfig'][0]['value'] = 35;
      final preview = await provider.previewImport('catalog.json', bytes(root));
      expect(preview.added, ['ASC_COARSE__ASC-NEW']);
      expect(preview.removed, ['ASC_COARSE__ASC-200']);
      await provider.applyImport(preview);
      expect(await repository.getMachineById('ASC_COARSE__ASC-200'), isNull);
      expect(await repository.getMachineById('ASC_COARSE__ASC-NEW'), isNotNull);
      expect(provider.machines.any((m) => m.model == 'ASC-300'), isFalse);
      expect(
        provider.series.firstWhere((s) => s.seriesCode == 'ASC_COARSE').nameVi,
        'Tên cập nhật',
      );
      expect(
        (await repository.getSelectionTags('ASC_COARSE'))
            .any((t) => t.tag == 'updated_tag'),
        isTrue,
      );
      expect(
        (await repository.getExtraSpecs(root['extraSpecs'][0]['machineId']))
            .first
            .specValueNumber,
        222,
      );
      expect(
        (await repository.getMaterialById('SESAME'))!.nameVi,
        'Vừng cập nhật',
      );
      expect(
        (await repository.getMaterialSeriesMapFor('SESAME'))
            .first
            .scoreAdjustment,
        10,
      );
      expect((await repository.getAiConfigByKey('capacity_weight'))!.asNum, 35);
    },
  );

  test(
    'Cùng version cần lưu ý; version thấp hơn và file lỗi không được apply',
    () async {
      final root = updated()..['databaseVersion'] = '2.2.19';
      final same = await provider.previewImport('same.json', bytes(root));
      expect(same.report.canImport, isTrue);
      expect(
        same.report.issues.any((v) => v.message.contains('cùng phiên bản')),
        isTrue,
      );
      root['databaseVersion'] = '2.0';
      final old = await provider.previewImport('old.json', bytes(root));
      expect(old.report.canImport, isFalse);
      await expectLater(provider.applyImport(old), throwsStateError);
      final bad = await provider.previewImport('empty.json', bytes({}));
      await expectLater(provider.applyImport(bad), throwsStateError);
      expect(await repository.getImportedDatabaseVersion(), '2.2.19');
      expect(provider.machines, hasLength(57));
    },
  );

  test('Thiết bị có importOrigin cũ khác "seed" (từ lần import file thủ công '
      'trước khi màn Database Update bị gỡ) vẫn phải tự nhận seed mới khi '
      'version tăng — không được kẹt vĩnh viễn ở dữ liệu cũ', () async {
    // Mô phỏng 1 thiết bị đã cài app trước đây: catalog hiện có origin
    // 'file' (từ lần dùng màn Database Update cũ) và version THẤP HƠN
    // seed đóng gói hiện tại. Ghi thẳng vào bảng meta (không qua
    // `importSnapshot`) vì đây là trạng thái đĩa CÓ SẴN từ 1 bản app cũ,
    // không phải 1 thao tác nghiệp vụ đang diễn ra — `importSnapshot` sẽ
    // (đúng) chặn hạ version nếu gọi qua nó ở đây.
    await db.update(
      'grinding_db_meta',
      {'value': '1.0'},
      where: 'key = ?',
      whereArgs: ['databaseVersion'],
    );
    await db.update(
      'grinding_db_meta',
      {'value': 'file'},
      where: 'key = ?',
      whereArgs: ['importOrigin'],
    );
    expect((await repository.getImportMetadata())['importOrigin'], 'file');
    expect(await repository.getImportedDatabaseVersion(), '1.0');

    // Mở lại Home (như user mở app sau khi cài bản mới) -> PHẢI tự nâng
    // lên seed đóng gói mới nhất, bất kể importOrigin cũ là gì.
    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();

    expect(await repository.getImportedDatabaseVersion(), isNot('1.0'));
    expect(reopened.machines, hasLength(57));
    expect(reopened.series.every((s) => !s.seriesCode.startsWith('B')), isTrue);
  });

  test(
    'Thiết bị đang ở catalog 2.2.2 tự nhận tên tiếng Việt mới từ seed mới nhất',
    () async {
      await db.update(
        'grinding_series',
        {'nameVi': 'Máy nghiền búa tốc độ cao dạng nhỏ'},
        where: 'seriesCode = ?',
        whereArgs: ['AS_SMALL_HAMMER'],
      );
      await db.update(
        'grinding_db_meta',
        {'value': '2.2.2'},
        where: 'key = ?',
        whereArgs: ['databaseVersion'],
      );

      final reopened = GrindingMachineProvider(repository: repository);
      addTearDown(reopened.dispose);
      await reopened.loadHome();

      expect(await repository.getImportedDatabaseVersion(), '2.2.19');
      final names = {
        for (final series in reopened.series) series.seriesCode: series.nameVi,
      };
      expect(names['ASZ_PIN'], 'Máy nghiền pin');
      expect(names['ASDF_MULTISTAGE'], 'Máy nghiền búa nhiều tầng');
      expect(names['AS_SMALL_HAMMER'], 'Máy nghiền búa cỡ nhỏ');
      expect(names['ASF_AS_HAMMER'], 'Máy nghiền búa');
      expect(names['ASU_UNIVERSAL'], 'Máy nghiền tua-bin tốc độ cao');
      final asu = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASU_UNIVERSAL',
      );
      expect(asu.workingPrincipleVi, startsWith('Máy ASU sử dụng đĩa tua-bin'));
      expect(asu.workingPrincipleVi, contains('\nHệ thống luồng khí'));
      expect(asu.featuresVi.split('\n'), hasLength(3));
      expect(asu.featuresVi, startsWith('1. Nhiệt độ nghiền thấp:'));
      expect(
        asu.nameEn,
        'High Speed Turbine Grinder Dried Jerusalem artichoke chips Grinding Machine',
      );
      expect(
        reopened.series
            .firstWhere((s) => s.seriesCode == 'AS_CRYOGENIC')
            .nameEn,
        'Low Temperature Spice Cryogenic Pin Mill Grinder',
      );
      final ask = reopened.series.firstWhere((s) => s.seriesCode == 'ASK_JET');
      expect(ask.nameVi, 'Máy nghiền phản lực khí siêu mịn');
      expect(ask.nameEn, 'Powder Air Jet Mill');
      expect(
        ask.applicationVi.split('\n').where((l) => l.startsWith('- ')),
        hasLength(7),
      );
      expect(
        ask.workingPrincipleVi,
        contains('\nBước 5 – Tách bột mịn và bột thô\n'),
      );
      // Ký tự "J" thừa khi sao chép đã được bỏ.
      expect(ask.workingPrincipleVi, isNot(contains('. J')));
      final asg = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASG_UNIVERSAL_SYSTEM',
      );
      expect(asg.nameVi, 'Máy nghiền búa tự hút');
      expect(asg.nameEn, 'Self-Suction Hammer Mill System');

      final asp = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASP_ULTRAFINE',
      );
      expect(asp.nameEn, 'Air Classifier Mill');
      expect(
        asp.workingPrincipleVi,
        startsWith('Nguyên liệu được cấp vào buồng nghiền bằng vít tải'),
      );
      // Lỗi gõ khi sao chép đã sửa: ". ." -> ".", bỏ "J", "sử  kết hợp".
      expect(asp.workingPrincipleVi, isNot(contains('. .')));
      expect(asp.workingPrincipleVi, isNot(contains('. J')));
      expect(asp.featuresVi.split('\n'), hasLength(9));
      expect(
        asp.featuresVi,
        contains('- Có thể sử dụng kết hợp chiller công nghiệp'),
      );
      expect(
        reopened.series
            .firstWhere((s) => s.seriesCode == 'AS_SMALL_HAMMER')
            .nameEn,
        'Hammer mill',
      );
      // Cấu tạo tách sang mục riêng (structureVi); nguyên lý bắt đầu từ
      // "Nguyên lý nghiền".
      // Không còn dòng mở đầu nhắc tên nhà sản xuất gốc.
      expect(asg.structureVi.split('\n'), hasLength(9));
      expect(asg.structureVi, startsWith('- Máy nghiền chính\n'));
      expect(asg.structureVi, isNot(contains('Brightsail')));
      expect(asg.structureVi, contains('\n- Cyclone separator\n'));
      expect(asg.workingPrincipleVi, startsWith('Nguyên lý nghiền\n'));
      expect(asg.workingPrincipleVi, isNot(contains('Cấu tạo')));
      expect(
        asg.workingPrincipleVi,
        contains('\nChức năng phân loại kích thước\n'),
      );
      expect(asg.workingPrincipleVi, isNot(contains('. J')));

      final hammer = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASF_AS_HAMMER',
      );
      expect(hammer.nameEn, 'Hammer mill');
      expect(
        hammer.structureVi,
        startsWith('Hệ thống gồm các bộ phận chính:\n'),
      );
      expect(
        hammer.workingPrincipleVi.split('\n').where((l) => l.startsWith('- ')),
        hasLength(2),
      );
      // Nội dung cũ nhắc BSF/BS (mã gốc) và kiểu dao (nay là ASF) đã bỏ.
      expect(hammer.applicationVi, isNot(contains('BSF')));
      expect(hammer.notes, isNot(contains('BSF')));

      final asc = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASC_COARSE',
      );
      expect(asc.nameEn, 'Foodstuff Industry Chili Powder Machine');
      expect(
        asc.applicationVi.split('\n').where((l) => l.startsWith('- ')),
        hasLength(9),
      );
      expect(asc.applicationVi, endsWith('độ nhớt cao.'));
      expect(asc.workingPrincipleVi, startsWith('ASC là dạng máy nghiền/cắt'));

      final asdf = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASDF_MULTISTAGE',
      );
      expect(asdf.nameEn, '3-Stage advanced hammer mill unit');
      expect(asdf.structureVi.split('\n'), hasLength(7));
      expect(
        asdf.workingPrincipleVi,
        startsWith('Điểm đặc biệt: nghiền 3 tầng trong cùng một buồng\n'),
      );
      expect(asdf.workingPrincipleVi, contains('\n3. Vùng nghiền mịn\n'));

      // ASF tách khỏi ASF/AS: mã model giữ nguyên để dự án/báo giá cũ
      // vẫn tham chiếu đúng, chỉ đổi dòng máy.
      final asf = reopened.series.firstWhere(
        (s) => s.seriesCode == 'ASF_FITZ_MILL',
      );
      expect(asf.displayCode, 'ASF');
      expect(asf.nameVi, 'Máy nghiền dược liệu');
      expect(asf.nameEn, 'Pharmaceutical Fitz Mill');
      expect(asf.featuresVi.split('\n'), hasLength(3));
      expect(reopened.machinesOf('ASF_FITZ_MILL').map((m) => m.machineId), [
        'ASF_AS_HAMMER__ASF-15',
        'ASF_AS_HAMMER__ASF-32',
      ]);
      expect(
        reopened.series
            .firstWhere((s) => s.seriesCode == 'ASF_AS_HAMMER')
            .displayCode,
        'AS',
      );
      expect(
        reopened.machinesOf('ASF_AS_HAMMER').map((m) => m.model),
        unorderedEquals([
          'AS-200',
          'AS-320',
          'AS-400',
          'AS-630',
          'AS-880',
          'AS-1000',
        ]),
      );
      expect(
        (await repository.getSelectionTags('ASF_FITZ_MILL')).map((t) => t.tag),
        containsAll(['cutting', 'pharma']),
      );
      expect(names['ASG_UNIVERSAL_SYSTEM'], 'Máy nghiền búa tự hút');
      expect(names['AS_ROLLER'], 'Máy nghiền trục lăn');
      expect(names['ASP_ULTRAFINE'], 'Máy nghiền siêu mịn');
      expect(names['AS_CRYOGENIC'], 'Máy nghiền siêu lạnh');
      final cryo = reopened.series.firstWhere(
        (s) => s.seriesCode == 'AS_CRYOGENIC',
      );
      expect(
        cryo.applicationVi.split('\n').where((l) => l.startsWith('- ')),
        hasLength(3),
      );
      expect(cryo.workingPrincipleVi, startsWith('Nguồn lạnh trao đổi nhiệt'));
      expect(names['ASC_COARSE'], 'Máy nghiền thô thực phẩm');
    },
  );

  test('Thiết bị đang ở 2.2.3 đổi "Máy nghiền gia vị / AS" thành "Máy nghiền trục lăn / Roller mill"', () async {
    await db.update(
      'grinding_series',
      {'nameVi': 'Máy nghiền gia vị', 'displayCode': 'AS'},
      where: 'seriesCode = ?',
      whereArgs: ['AS_ROLLER'],
    );
    await db.update(
      'grinding_db_meta',
      {'value': '2.2.3'},
      where: 'key = ?',
      whereArgs: ['databaseVersion'],
    );

    final reopened = GrindingMachineProvider(repository: repository);
    addTearDown(reopened.dispose);
    await reopened.loadHome();

    final roller = reopened.series.firstWhere(
      (s) => s.seriesCode == 'AS_ROLLER',
    );
    expect(roller.nameVi, 'Máy nghiền trục lăn');
    expect(roller.displayCode, 'Roller mill');
    expect(
      roller.workingPrincipleVi,
      'Nguyên liệu thô được đưa từ phễu nạp liệu vào khu vực trục nghiền và '
      'được nghiền thành dạng bột. Bằng cách điều chỉnh khoảng cách giữa hai '
      'trục nghiền, người dùng có thể thu được thành phẩm với kích thước hạt '
      'theo mong muốn.',
    );
    expect(reopened.machinesOf('AS_ROLLER'), hasLength(6));
  });

  test('Lỗi import không chặn thao tác tiếp theo trong hàng đợi', () async {
    final stale = await provider.previewImport('first.json', bytes(updated()));
    final fresh = await provider.previewImport('second.json', bytes(updated()));
    await provider.applyImport(fresh);
    await expectLater(provider.applyImport(stale), throwsStateError);
    await provider.loadHome();
    expect(provider.error, isNull);
    expect(provider.machines, hasLength(57));
  });
}
