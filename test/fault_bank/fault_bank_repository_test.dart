import 'dart:io';

import 'package:dtc_product/features/fault_bank/data/fault_bank_database.dart';
import 'package:dtc_product/features/fault_bank/models/engineer_profile.dart';
import 'package:dtc_product/features/fault_bank/models/fault_machine_model.dart';
import 'package:dtc_product/features/fault_bank/models/fault_record.dart';
import 'package:dtc_product/features/fault_bank/repositories/fault_bank_repository.dart';
import 'package:dtc_product/features/fault_bank/utils/fault_ids.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _author = EngineerProfile(
  engineerName: 'Nguyễn Văn A',
  engineerCode: 'KS012',
);

class _Clock {
  DateTime now = DateTime.utc(2026, 1, 1, 8);
  DateTime call() => now;
  void advance() => now = now.add(const Duration(minutes: 5));
}

Future<(FaultBankRepository, Database, _Clock, FaultBankDatabase)> _open({
  bool forceLike = false,
}) async {
  sqfliteFfiInit();
  final db = await databaseFactoryFfiNoIsolate.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(singleInstance: false),
  );
  final database = FaultBankDatabase.forTesting(db);
  await database.createSchemaForTesting(db, forceLikeSearch: forceLike);
  final clock = _Clock();
  return (
    FaultBankRepository(database: database, clock: clock.call),
    db,
    clock,
    database,
  );
}

FaultRecordDraft _draft(
  String machineId, {
  String symptom = 'Động cơ quá nhiệt, máy dừng sau 10 phút',
  String cause = 'Quạt làm mát bị kẹt bụi',
  List<String> steps = const ['Ngắt điện', 'Vệ sinh quạt', 'Chạy thử'],
  String? errorCode,
  String? faultGroup,
}) => FaultRecordDraft(
  machineModelId: machineId,
  symptom: symptom,
  cause: cause,
  errorCode: errorCode,
  faultGroup: faultGroup,
  steps: [
    for (var i = 0; i < steps.length; i++)
      SolutionStep(id: FaultIds.newChildId(), order: i + 1, content: steps[i]),
  ],
);

void main() {
  for (final forceLike in [false, true]) {
    final modeName = forceLike ? 'LIKE' : 'FTS';

    group('Tìm kiếm ($modeName)', () {
      test('chế độ tìm kiếm đúng như cấu hình', () async {
        final (_, db, _, database) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        expect(
          await database.searchMode(),
          forceLike ? FaultSearchMode.like : FaultSearchMode.fts5,
        );
      });

      test('gõ "dong co" ra bản ghi có "động cơ"', () async {
        final (repo, db, _, _) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        final model = await repo.addMachineModel(
          name: 'SC16 Pro',
          engineerCode: 'KS012',
        );
        final hit = await repo.createRecord(_draft(model.id), author: _author);
        await repo.createRecord(
          _draft(model.id, symptom: 'Camera mờ', cause: 'Kính bẩn'),
          author: _author,
        );

        for (final query in ['dong co', 'Động Cơ', 'DONG', 'đông c']) {
          final results = await repo.search(FaultSearchFilter(query: query));
          expect(results.map((r) => r.id), [hit], reason: 'query "$query"');
        }
      });

      test('tìm cả trong bước xử lý, linh kiện, tên dòng máy', () async {
        final (repo, db, _, _) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        final model = await repo.addMachineModel(
          name: 'Máy nén ACOMP',
          engineerCode: 'KS012',
        );
        final id = await repo.createRecord(
          _draft(model.id, steps: ['Thay rơ-le nhiệt']),
          author: _author,
        );
        expect(
          (await repo.search(const FaultSearchFilter(query: 'ro le nhiet')))
              .single
              .id,
          id,
        );
        expect(
          (await repo.search(const FaultSearchFilter(query: 'may nen'))).length,
          1,
        );
      });

      test('mọi từ khóa phải khớp', () async {
        final (repo, db, _, _) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        final model = await repo.addMachineModel(
          name: 'SC12',
          engineerCode: 'KS012',
        );
        await repo.createRecord(_draft(model.id), author: _author);
        expect(
          await repo.search(const FaultSearchFilter(query: 'dong co camera')),
          isEmpty,
        );
      });

      test('lọc theo dòng máy, nhóm lỗi, mã lỗi', () async {
        final (repo, db, _, _) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        final a = await repo.addMachineModel(
          name: 'SC16',
          engineerCode: 'KS012',
        );
        final b = await repo.addMachineModel(
          name: 'SF7D',
          engineerCode: 'KS012',
        );
        final r1 = await repo.createRecord(
          _draft(a.id, errorCode: 'E-102', faultGroup: 'ĐIỆN NGUỒN'),
          author: _author,
        );
        final r2 = await repo.createRecord(
          _draft(b.id, errorCode: 'E-205', faultGroup: 'CAMERA'),
          author: _author,
        );

        Future<List<String>> ids(FaultSearchFilter f) async =>
            (await repo.search(f)).map((r) => r.id).toList();

        expect(await ids(FaultSearchFilter(machineModelId: b.id)), [r2]);
        expect(await ids(const FaultSearchFilter(faultGroup: 'ĐIỆN NGUỒN')), [
          r1,
        ]);
        expect(await ids(const FaultSearchFilter(errorCode: 'e-10')), [r1]);
        expect(
          await ids(FaultSearchFilter(query: 'dong co', machineModelId: a.id)),
          [r1],
        );
      });

      test('gợi ý bản ghi có triệu chứng tương tự', () async {
        final (repo, db, _, _) = await _open(forceLike: forceLike);
        addTearDown(db.close);
        final model = await repo.addMachineModel(
          name: 'SC16',
          engineerCode: 'KS012',
        );
        final existing = await repo.createRecord(
          _draft(model.id),
          author: _author,
        );
        await repo.createRecord(
          _draft(model.id, symptom: 'Camera mờ, ảnh nhiễu'),
          author: _author,
        );

        final similar = await repo.findSimilar('dong co qua nhiet');
        expect(similar.map((r) => r.id), [existing]);
        // Đang sửa chính bản ghi đó thì không gợi ý lại.
        expect(
          await repo.findSimilar('dong co qua nhiet', excludeId: existing),
          isEmpty,
        );
        // Quá ít từ khóa thì không gợi ý.
        expect(await repo.findSimilar('dong'), isEmpty);
      });
    });
  }

  test('đóng database rồi mở lại: dữ liệu còn, tìm kiếm vẫn chạy', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('fault_bank_reopen');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/fault_bank.db';
    Future<Database> open() => databaseFactoryFfiNoIsolate.openDatabase(path);

    final db1 = await open();
    final database1 = FaultBankDatabase.forTesting(db1);
    await database1.createSchemaForTesting(db1);
    final repo1 = FaultBankRepository(database: database1);
    await repo1.saveProfile(engineerName: 'An', engineerCode: 'KS012');
    final model = await repo1.addMachineModel(
      name: 'SC16',
      engineerCode: 'KS012',
    );
    final id = await repo1.createRecord(_draft(model.id), author: _author);
    await db1.close();

    // "Mở lại app": instance mới, chế độ tìm kiếm đọc lại từ bảng meta.
    final db2 = await open();
    addTearDown(db2.close);
    final repo2 = FaultBankRepository(
      database: FaultBankDatabase.forTesting(db2),
    );
    expect((await repo2.getProfile())?.engineerCode, 'KS012');
    expect((await repo2.getRecord(id))?.steps, hasLength(3));
    expect(
      (await repo2.search(const FaultSearchFilter(query: 'dong co'))).single.id,
      id,
    );
  });

  group('Xóa bằng cờ', () {
    test('giữ dòng trong bảng, ẩn khỏi tra cứu và chi tiết', () async {
      final (repo, db, clock, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      final id = await repo.createRecord(_draft(model.id), author: _author);
      clock.advance();

      await repo.softDeleteRecord(id);

      final rows = await db.query(
        'fault_records',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows, hasLength(1), reason: 'dòng vẫn còn trong bảng');
      expect(rows.single['is_deleted'], 1);
      expect(rows.single['updated_at'], clock.now.toIso8601String());
      expect(await repo.getRecord(id), isNull);
      expect(await repo.search(const FaultSearchFilter()), isEmpty);
      expect(
        await repo.search(const FaultSearchFilter(query: 'dong co')),
        isEmpty,
      );
      expect(await repo.findSimilar('dong co qua nhiet'), isEmpty);
      // Bước xử lý và ảnh cũng giữ nguyên để gộp file về sau.
      expect(
        await db.query(
          'solution_steps',
          where: 'record_id = ?',
          whereArgs: [id],
        ),
        hasLength(3),
      );
    });

    test('bản ghi nhập vào không xóa / sửa được', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      final id = await repo.createRecord(_draft(model.id), author: _author);
      await db.update(
        'fault_records',
        {'source': 'imported'},
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(() => repo.softDeleteRecord(id), throwsStateError);
      expect(() => repo.updateRecord(id, _draft(model.id)), throwsStateError);
      expect((await repo.getRecord(id))!.isEditable, isFalse);
    });
  });

  group('Ghi / sửa', () {
    test('tạo bản ghi: mã theo kỹ sư, đủ bước theo thứ tự', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      final id = await repo.createRecord(_draft(model.id), author: _author);

      final record = (await repo.getRecord(id))!;
      expect(record.id, startsWith('KS012-'));
      expect(record.machineModelName, 'SC16');
      expect(record.steps.map((s) => (s.order, s.content)), [
        (1, 'Ngắt điện'),
        (2, 'Vệ sinh quạt'),
        (3, 'Chạy thử'),
      ]);
      expect(record.authorCode, 'KS012');
      expect(record.source, FaultRecordSource.mine);
    });

    test(
      'sửa: giữ mã + ngày tạo, cập nhật ngày cập nhật, trả về ảnh bị gỡ',
      () async {
        final (repo, db, clock, _) = await _open();
        addTearDown(db.close);
        final model = await repo.addMachineModel(
          name: 'SC16',
          engineerCode: 'KS012',
        );
        final photo = FaultAttachment(id: 'p1', fileName: 'KS012-x_p1.jpg');
        final first = _draft(model.id);
        final id = await repo.createRecord(
          FaultRecordDraft(
            machineModelId: first.machineModelId,
            symptom: first.symptom,
            cause: first.cause,
            steps: first.steps,
            photos: [photo],
          ),
          author: _author,
        );
        final created = (await repo.getRecord(id))!;
        clock.advance();

        final removed = await repo.updateRecord(
          id,
          _draft(
            model.id,
            symptom: 'Động cơ rung mạnh',
            steps: ['Siết bulông'],
          ),
        );

        final updated = (await repo.getRecord(id))!;
        expect(updated.id, id);
        expect(updated.createdAt, created.createdAt);
        expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
        expect(updated.symptom, 'Động cơ rung mạnh');
        expect(updated.steps.single.content, 'Siết bulông');
        expect(updated.photos, isEmpty);
        expect(removed, ['KS012-x_p1.jpg']);
        // Chỉ mục tìm kiếm cũng được cập nhật.
        expect(
          (await repo.search(const FaultSearchFilter(query: 'rung manh')))
              .length,
          1,
        );
        expect(
          await repo.search(const FaultSearchFilter(query: 'qua nhiet')),
          isEmpty,
        );
      },
    );

    test('ảnh gắn vào bước được đọc lại đúng bước', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      final id = await repo.createRecord(
        FaultRecordDraft(
          machineModelId: model.id,
          symptom: 'Súng bắn yếu',
          cause: 'Van kẹt',
          steps: const [
            SolutionStep(
              id: 's1',
              order: 1,
              content: 'Tháo van',
              photo: FaultAttachment(
                id: 'a1',
                fileName: 'f1.jpg',
                stepId: 's1',
              ),
            ),
          ],
        ),
        author: _author,
      );
      final record = (await repo.getRecord(id))!;
      expect(record.steps.single.photo?.fileName, 'f1.jpg');
      expect(record.photos, isEmpty);
    });

    test('thiếu mục bắt buộc thì không lưu', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      expect(
        () => repo.createRecord(_draft(model.id, cause: '  '), author: _author),
        throwsArgumentError,
      );
      expect(
        () =>
            repo.createRecord(_draft(model.id, steps: ['  ']), author: _author),
        throwsArgumentError,
      );
    });
  });

  group('Dòng máy, nhóm lỗi, hồ sơ', () {
    test('phát hiện dòng máy tên gần giống', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16 Pro',
        engineerCode: 'KS012',
      );
      expect(model.id, startsWith('KS012-'));
      expect((await repo.findSimilarMachineModel('sc16pro'))?.id, model.id);
      expect(await repo.findSimilarMachineModel('SC12'), isNull);
    });

    test('đổi tên dòng máy thì tìm được theo tên mới', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      await repo.createRecord(_draft(model.id), author: _author);
      await repo.updateMachineModel(
        FaultMachineModel(id: model.id, name: 'Máy tách màu Gạo'),
      );
      expect(
        (await repo.search(const FaultSearchFilter(query: 'tach mau gao')))
            .length,
        1,
      );
      // Còn bản ghi thì không xóa được dòng máy.
      expect(() => repo.deleteMachineModel(model.id), throwsStateError);
    });

    test('nhóm lỗi tự thêm được viết hoa và liệt kê lại', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final model = await repo.addMachineModel(
        name: 'SC16',
        engineerCode: 'KS012',
      );
      await repo.createRecord(
        _draft(model.id, faultGroup: 'băng  tải'),
        author: _author,
      );
      await repo.createRecord(
        _draft(model.id, faultGroup: 'CAMERA'),
        author: _author,
      );
      expect(await repo.customFaultGroups(), ['BĂNG TẢI']);
    });

    test('không nhập mã kỹ sư: tự sinh mã, đổi tên vẫn giữ mã', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      final first = await repo.saveProfile(engineerName: 'An');
      expect(FaultIds.isValidEngineerCode(first.engineerCode), isTrue);
      expect(first.engineerCode, startsWith('KS'));
      final renamed = await repo.saveProfile(engineerName: 'Nguyễn An');
      expect(renamed.engineerName, 'Nguyễn An');
      expect(renamed.engineerCode, first.engineerCode);
      expect(FaultIds.newEngineerCode(), isNot(FaultIds.newEngineerCode()));
    });

    test('hồ sơ kỹ sư lưu 1 dòng, sửa được', () async {
      final (repo, db, _, _) = await _open();
      addTearDown(db.close);
      expect(await repo.getProfile(), isNull);
      await repo.saveProfile(engineerName: 'An', engineerCode: 'ks012');
      final saved = await repo.saveProfile(
        engineerName: 'Nguyễn An',
        engineerCode: 'KS013',
      );
      expect(saved.engineerCode, 'KS013');
      expect(await db.query('profile'), hasLength(1));
      expect(
        () => repo.saveProfile(engineerName: 'An', engineerCode: 'x'),
        throwsArgumentError,
      );
    });

    test('tạo sẵn bảng export_logs, import_logs', () async {
      final (_, db, _, _) = await _open();
      addTearDown(db.close);
      final tables = (await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table'",
      )).map((r) => r['name']).toSet();
      expect(
        tables,
        containsAll([
          'profile',
          'machine_models',
          'fault_records',
          'solution_steps',
          'attachments',
          'export_logs',
          'import_logs',
        ]),
      );
    });
  });
}
