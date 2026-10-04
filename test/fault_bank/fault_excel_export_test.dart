import 'package:dtc_product/features/fault_bank/data/fault_bank_database.dart';
import 'package:dtc_product/features/fault_bank/models/engineer_profile.dart';
import 'package:dtc_product/features/fault_bank/models/fault_record.dart';
import 'package:dtc_product/features/fault_bank/repositories/fault_bank_repository.dart';
import 'package:dtc_product/features/fault_bank/services/fault_excel_export_service.dart';
import 'package:dtc_product/features/fault_bank/utils/fault_ids.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _author = EngineerProfile(engineerName: 'An', engineerCode: 'KS012');

FaultRecordDraft _draft(
  String machineId,
  String symptom, {
  String? tagname,
  String? faultGroup,
  String? parts,
  int? duration,
}) => FaultRecordDraft(
  machineModelId: machineId,
  symptom: symptom,
  cause: 'Quạt làm mát kẹt bụi',
  serialNumber: tagname,
  faultGroup: faultGroup,
  parts: parts,
  durationMinutes: duration,
  steps: [
    SolutionStep(id: FaultIds.newChildId(), order: 1, content: 'Ngắt điện'),
    SolutionStep(id: FaultIds.newChildId(), order: 2, content: 'Vệ sinh quạt'),
  ],
);

String? _text(Data? cell) => switch (cell?.value) {
  null => null,
  TextCellValue(:final value) => value.text,
  final other => other.toString(),
};

void main() {
  test('xuất Excel đúng cột và nội dung, theo bộ lọc đang dùng', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(db.close);
    final database = FaultBankDatabase.forTesting(db);
    await database.createSchemaForTesting(db);
    final repo = FaultBankRepository(database: database);

    final sc16 = await repo.addMachineModel(
      name: 'SC16 Pro',
      engineerCode: 'KS012',
    );
    final sf7 = await repo.addMachineModel(name: 'SF7D', engineerCode: 'KS012');
    await repo.createRecord(
      _draft(
        sc16.id,
        'Động cơ quá nhiệt',
        tagname: 'CS-01',
        faultGroup: 'ĐIỆN NGUỒN',
        parts: 'Quạt 24V',
        duration: 45,
      ),
      author: _author,
    );
    await repo.createRecord(_draft(sf7.id, 'Camera mờ'), author: _author);

    // Lọc theo model thì chỉ xuất bản ghi của model đó.
    final filtered = await repo.recordsForExport(
      FaultSearchFilter(machineModelId: sc16.id),
    );
    expect(filtered, hasLength(1));
    expect(
      await repo.recordsForExport(const FaultSearchFilter()),
      hasLength(2),
    );

    final bytes = FaultExcelExportService.buildWorkbook(filtered);
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, [FaultExcelExportService.sheetName]);
    final rows = excel.tables[FaultExcelExportService.sheetName]!.rows;
    expect(rows, hasLength(2));

    final header = rows[0].map(_text).toList();
    expect(header, [
      for (final (title, _) in FaultExcelExportService.columns) title,
    ]);
    expect(header, isNot(contains('Mã lỗi')));
    expect(header, isNot(contains('Cảnh báo an toàn')));

    final row = {
      for (var c = 0; c < header.length; c++) header[c]: _text(rows[1][c]),
    };
    expect(row['STT'], '1');
    expect(row['Model máy'], 'SC16 Pro');
    expect(row['Tagname'], 'CS-01');
    expect(row['Nhóm lỗi'], 'ĐIỆN NGUỒN');
    expect(row['Mô tả lỗi'], 'Động cơ quá nhiệt');
    expect(row['Cách xử lý'], '1. Ngắt điện\n2. Vệ sinh quạt');
    expect(row['Vật tư cần thay thế'], 'Quạt 24V');
    expect(row['Thời gian xử lý (giờ)'], '0.75');
    expect(row['Người ghi'], 'An');
  });

  test('tên file theo ngày giờ', () {
    expect(
      FaultExcelExportService.fileName(DateTime(2026, 10, 3, 9, 5)),
      'NganHangLoi_20261003_0905.xlsx',
    );
  });
}
