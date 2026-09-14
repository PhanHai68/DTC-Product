/// Script để đọc file Excel (Cân đóng gói) và tạo SQLite database.
/// Chạy bằng: dart run bin/generate_packing_db.dart
///
/// Lưu ý: File Excel này dùng t="str" (formula-calculated inline strings),
/// không dùng sharedStrings. Và XML dùng namespace prefix "x:".
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

void main() async {
  print('=== DTC Packing Database Generator ===\n');

  // Đường dẫn file Excel
  final excelPath = p.join(
    Directory.current.path,
    'docs',
    '3 Cân đóng gói',
    'DTC_Database_Can_Dong_Goi_Chuan_Hoa_HinhAnh (1).xlsx',
  );

  if (!File(excelPath).existsSync()) {
    print('❌ Không tìm thấy file Excel: $excelPath');
    exit(1);
  }

  // Thư mục tạm để giải nén
  final tempDir = Directory(p.join(Directory.current.path, '.temp_excel_db'));
  if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  tempDir.createSync();

  print('📂 Giải nén file Excel...');

  // Giải nén Excel (Excel = ZIP)
  final bytes = File(excelPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    final filename = p.join(tempDir.path, file.name);
    if (file.isFile) {
      final outFile = File(filename);
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
    } else {
      Directory(filename).createSync(recursive: true);
    }
  }
  print('  Giải nén thành công');

  // Đọc workbook.xml để lấy mapping sheet name → file ID
  final workbookFile = File(p.join(tempDir.path, 'xl', 'workbook.xml'));
  final workbookRelsFile = File(
    p.join(tempDir.path, 'xl', '_rels', 'workbook.xml.rels'),
  );

  final sheetFileMap = _parseWorkbookRels(
    workbookFile.readAsStringSync(),
    workbookRelsFile.readAsStringSync(),
  );
  print('  Sheets: ${sheetFileMap.keys.toList()}');

  // Tìm sheet "Models"
  final modelsFileName = sheetFileMap['Models'];
  if (modelsFileName == null) {
    print('❌ Không tìm thấy sheet "Models" trong workbook');
    print('  Sheets có: ${sheetFileMap.keys.toList()}');
    exit(1);
  }

  final modelsSheetPath = p.join(
    tempDir.path,
    'xl',
    'worksheets',
    modelsFileName,
  );
  print('  Sheet Models: $modelsSheetPath');

  // Parse shared strings (nếu có)
  final sharedStrings = <String>[];
  final ssFile = File(p.join(tempDir.path, 'xl', 'sharedStrings.xml'));
  if (ssFile.existsSync()) {
    final ssContent = ssFile.readAsStringSync();
    // Check nếu file không empty
    if (ssContent.contains('<si>') || ssContent.contains('<x:si>')) {
      sharedStrings.addAll(_parseSharedStrings(ssContent));
    }
  }
  print('  Shared strings: ${sharedStrings.length}');

  // Parse dữ liệu Models sheet
  final sheetContent = File(modelsSheetPath).readAsStringSync();
  final machines = _parseModelsSheet(sheetContent, sharedStrings);
  print('\n✅ Đọc được ${machines.length} models\n');

  _copyVietnameseCatalogs();

  // Tạo SQLite DB
  sqfliteFfiInit();
  final dbFactory = databaseFactoryFfi;

  final dbPath = p.join(
    Directory.current.path,
    'assets',
    'database',
    'packing.db',
  );
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();

  print('💾 Tạo database: $dbPath');
  final db = await dbFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute(_createTableSQL);
      },
    ),
  );

  // Insert data
  final batch = db.batch();
  for (final machine in machines) {
    batch.insert('packing_machines', machine);
  }
  await batch.commit(noResult: true);

  print('✅ Đã insert ${machines.length} records vào database\n');

  // Verify
  final rows = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM packing_machines',
  );
  print('🔍 Verify: ${rows.first['cnt']} records trong DB');

  // Sample check
  print('\nSample records:');
  final sample = await db.rawQuery(
    'SELECT model, product_group, weight_min_kg, weight_max_kg, '
    'capacity_min, capacity_max, capacity_unit FROM packing_machines LIMIT 5',
  );
  for (final row in sample) {
    print(
      '  ${row['model']} | ${row['product_group']} | '
      '${row['weight_min_kg']}-${row['weight_max_kg']} kg | '
      '${row['capacity_min']}-${row['capacity_max']} ${row['capacity_unit']}',
    );
  }

  await db.close();

  // Dọn thư mục tạm
  tempDir.deleteSync(recursive: true);

  print('\n🎉 HOÀN THÀNH! Database tại: $dbPath');
}

// ─── SQL Schema ───────────────────────────────────────────────────────────────

const String _createTableSQL = '''
  CREATE TABLE packing_machines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    stt INTEGER,
    product_group TEXT,
    machine_line TEXT,
    model TEXT UNIQUE NOT NULL,
    automation_level TEXT,
    automation_original TEXT,
    bag_material TEXT,
    bag_edges TEXT,
    bag_shape TEXT,
    materials TEXT,
    heads_stations TEXT,
    weight_min_kg REAL,
    weight_max_kg REAL,
    weight_unit TEXT,
    capacity_min REAL,
    capacity_max REAL,
    capacity_unit TEXT,
    power_system TEXT,
    voltage_v REAL,
    frequency_hz REAL,
    power_kw REAL,
    air_pressure_min_mpa REAL,
    air_pressure_max_mpa REAL,
    air_consumption_m3h REAL,
    length_mm REAL,
    width_mm REAL,
    height_mm REAL,
    notes TEXT,
    source_catalog TEXT,
    image_file TEXT,
    image_main_path TEXT,
    image_2_path TEXT,
    image_bag_path TEXT,
    diagram_image_path TEXT,
    catalog_asset_path TEXT,
    catalog_page INTEGER
  )
''';

// ─── Workbook/Rels Parser ─────────────────────────────────────────────────────

/// Đọc workbook.xml + workbook.xml.rels để map sheet name → file name (vd: sheet2.xml)
Map<String, String> _parseWorkbookRels(String workbookXml, String relsXml) {
  // Parse workbook để lấy name → rId
  final workbookDoc = XmlDocument.parse(workbookXml);
  final nameToRid = <String, String>{};
  for (final el in workbookDoc.descendants.whereType<XmlElement>()) {
    if (el.localName == 'sheet') {
      final name = el.getAttribute('name') ?? '';
      // Tìm r:id attribute (có namespace)
      String rId = '';
      for (final attr in el.attributes) {
        if (attr.localName == 'id') {
          rId = attr.value;
          break;
        }
      }
      if (name.isNotEmpty && rId.isNotEmpty) {
        nameToRid[name] = rId;
      }
    }
  }

  // Parse rels để lấy rId → target (file name)
  final relsDoc = XmlDocument.parse(relsXml);
  final ridToTarget = <String, String>{};
  for (final el in relsDoc.descendants.whereType<XmlElement>()) {
    if (el.localName == 'Relationship') {
      final id = el.getAttribute('Id') ?? '';
      final target = el.getAttribute('Target') ?? '';
      if (id.isNotEmpty && target.isNotEmpty) {
        // target là "worksheets/sheet2.xml", lấy phần sau "/"
        final fileName = target.split('/').last;
        ridToTarget[id] = fileName;
      }
    }
  }

  // Kết hợp: name → file
  final result = <String, String>{};
  for (final entry in nameToRid.entries) {
    final target = ridToTarget[entry.value];
    if (target != null) {
      result[entry.key] = target;
    }
  }
  return result;
}

// ─── Shared Strings Parser ────────────────────────────────────────────────────

List<String> _parseSharedStrings(String xml) {
  final doc = XmlDocument.parse(xml);
  final strings = <String>[];
  for (final el in doc.descendants.whereType<XmlElement>()) {
    if (el.localName == 'si') {
      // Ghép tất cả text trong <t> elements
      final tElements = el.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 't')
          .toList();
      final text = tElements.map((t) => t.innerText).join('');
      strings.add(text);
    }
  }
  return strings;
}

// ─── Models Sheet Parser ──────────────────────────────────────────────────────

/// Parse sheet Models, trả về list Map<String, dynamic>
List<Map<String, dynamic>> _parseModelsSheet(
  String xml,
  List<String> sharedStrings,
) {
  final doc = XmlDocument.parse(xml);
  final machines = <Map<String, dynamic>>[];

  // Lấy tất cả row elements
  final rows = doc.descendants
      .whereType<XmlElement>()
      .where((e) => e.localName == 'row')
      .toList();

  print('  Tổng số rows trong sheet: ${rows.length}');

  // Bỏ qua row 1 (header)
  for (int rowIdx = 1; rowIdx < rows.length; rowIdx++) {
    final row = rows[rowIdx];
    final cells = row.descendants
        .whereType<XmlElement>()
        .where((e) => e.localName == 'c')
        .toList();

    // Build map: column letter → value
    final cellMap = <String, String>{};
    for (final cell in cells) {
      final ref = cell.getAttribute('r') ?? '';
      final colLetter = ref.replaceAll(RegExp(r'\d'), '');
      final type = cell.getAttribute('t') ?? 'n';

      // Lấy value từ <v> element
      final vEl = cell.descendants
          .whereType<XmlElement>()
          .where((e) => e.localName == 'v')
          .firstOrNull;
      if (vEl == null) continue;

      String value;
      if (type == 's') {
        // shared string index
        final idx = int.tryParse(vEl.innerText) ?? -1;
        value = (idx >= 0 && idx < sharedStrings.length)
            ? sharedStrings[idx]
            : '';
      } else {
        // inline string (str) hoặc number (n) → lấy trực tiếp
        value = vEl.innerText.trim();
      }

      if (value.isNotEmpty) {
        cellMap[colLetter] = value;
      }
    }

    // Bỏ qua row rỗng
    final model = cellMap['D'];
    if (model == null || model.isEmpty) continue;

    // Map columns → database fields
    final machine = <String, dynamic>{
      'stt': _parseInt(cellMap['A']),
      'product_group': cellMap['B'],
      'machine_line': cellMap['C'],
      'model': model,
      'automation_level': cellMap['E'],
      'automation_original': cellMap['F'],
      'bag_material': cellMap['G'],
      'bag_edges': cellMap['H'],
      'bag_shape': cellMap['I'],
      'materials': cellMap['J'],
      'heads_stations': cellMap['K'],
      'weight_min_kg': _parseDouble(cellMap['L']),
      'weight_max_kg': _parseDouble(cellMap['M']),
      'weight_unit': cellMap['N'],
      'capacity_min': _parseDouble(cellMap['O']),
      'capacity_max': _parseDouble(cellMap['P']),
      'capacity_unit': cellMap['Q'],
      'power_system': cellMap['R'],
      'voltage_v': _parseDouble(cellMap['S']),
      'frequency_hz': _parseDouble(cellMap['T']),
      'power_kw': _parseDouble(cellMap['U']),
      'air_pressure_min_mpa': _parseDouble(cellMap['V']),
      'air_pressure_max_mpa': _parseDouble(cellMap['W']),
      'air_consumption_m3h': _parseDouble(cellMap['X']),
      'length_mm': _parseDouble(cellMap['Y']),
      'width_mm': _parseDouble(cellMap['Z']),
      'height_mm': _parseDouble(cellMap['AA']),
      'notes': cellMap['AB'],
      'source_catalog': cellMap['AC'],
      'image_file': cellMap['AD'],
      'image_main_path': cellMap['AE'],
      'image_2_path': cellMap['AF'],
      'image_bag_path': cellMap['AG'],
      'diagram_image_path': cellMap['AH'],
      'catalog_asset_path': cellMap['AI'],
      'catalog_page': _parseInt(cellMap['AJ']),
    };

    _applyCatalogVisuals(machine);

    // Remove null entries
    machine.removeWhere((k, v) => v == null);
    machines.add(machine);

    print(
      '  [${rowIdx.toString().padLeft(2)}] ${machine['model']} '
      '| ${machine['product_group']} '
      '| ${machine['weight_min_kg'] ?? '?'}-${machine['weight_max_kg'] ?? '?'} kg '
      '| Cap: ${machine['capacity_min'] ?? '?'}-${machine['capacity_max'] ?? '?'} ${machine['capacity_unit'] ?? ''}',
    );
  }

  return machines;
}

/// Gắn icon và ảnh nền dùng chung theo họ máy.
///
/// Excel vẫn là nguồn dữ liệu kỹ thuật. Phần trực quan được chuẩn hóa ở đây
/// vì ba catalog tiếng Việt không có ảnh tách riêng cho từng model.
void _applyCatalogVisuals(Map<String, dynamic> machine) {
  final group = machine['product_group'] as String? ?? '';
  final line = machine['machine_line'] as String? ?? '';
  final model = machine['model'] as String? ?? '';
  const root = 'assets/images/packing';

  late final String iconPath;
  late final String backgroundPath;

  if (line == 'Máy trộn gạo') {
    iconPath = '$root/lcj_icon.png';
    backgroundPath = '$root/lcj_background_v2.png';
  } else if (line == 'Cân lưu lượng' && group == 'Định lượng') {
    iconPath = '$root/lcs_icon.png';
    backgroundPath = '$root/lcs_background.png';
  } else if (line == 'Túi 2 cạnh - Hoàn toàn tự động') {
    iconPath = '$root/pe_2_auto_icon.png';
    backgroundPath = '$root/pe_2_auto_background.png';
  } else if (line == 'Túi 2 cạnh - Bán tự động') {
    iconPath = '$root/pe_2_semi_icon.png';
    backgroundPath = '$root/pe_2_semi_background.png';
  } else if (line == 'Túi 6 cạnh - Hoàn toàn tự động') {
    iconPath = '$root/pe_6_auto_icon.png';
    backgroundPath = '$root/pe_6_auto_background.png';
  } else if (line == 'Túi 6 cạnh - Bán tự động') {
    iconPath = '$root/pe_6_semi_icon.png';
    backgroundPath = '$root/pe_6_semi_background.png';
  } else if (line == 'Túi 2 & 6 cạnh - Bán tự động') {
    iconPath = '$root/pe_mixed_semi_icon.png';
    backgroundPath = '$root/pe_mixed_semi_background.png';
  } else if (line == 'Hoàn toàn tự động') {
    iconPath = '$root/pp_auto_icon.png';
    backgroundPath = '$root/pp_auto_background.png';
  } else if (line.contains('Cân bao Jumbo')) {
    iconPath = '$root/pp_jumbo_icon.png';
    backgroundPath = '$root/pp_jumbo_background.png';
  } else if (line.contains('Đóng bột')) {
    iconPath = '$root/pp_powder_icon.png';
    backgroundPath = '$root/pp_powder_background.png';
  } else if (group == 'Bao dệt PP') {
    iconPath = '$root/pp_semi_icon.png';
    backgroundPath = '$root/pp_semi_background.png';
  } else {
    iconPath = 'assets/images/packing_scale_icon.jpg';
    backgroundPath = 'assets/images/packing_scale.jpg';
  }

  machine['image_main_path'] = iconPath;
  machine['image_2_path'] = backgroundPath;
  if (group.contains('PE')) {
    machine['image_bag_path'] = '$root/pe_bag.png';
  }

  if (machine['catalog_page'] == null) {
    if (model == 'DCS-50 (SK)') {
      machine['catalog_page'] = 7;
    } else if (line.contains('Cân bao Jumbo')) {
      machine['catalog_page'] = 8;
    } else if (line.contains('Đóng bột')) {
      machine['catalog_page'] = 9;
    } else if (model == 'DCS-50-CS/N10' || model == 'DCS-50-V10') {
      machine['catalog_page'] = 10;
    }
  }
}

/// Đưa đúng ba catalog tiếng Việt vào assets để nút XEM CATALOG luôn hoạt động.
void _copyVietnameseCatalogs() {
  final sourceDirectory = p.join(
    Directory.current.path,
    'docs',
    '3 Cân đóng gói',
  );
  final outputDirectory = Directory(
    p.join(Directory.current.path, 'assets', 'catalogs'),
  )..createSync(recursive: true);

  const catalogNames = [
    'DTC-Packing-DinhLuong-260109.pdf',
    'DTC-Packing-TuiPE-240513.pdf',
    'DTC-Packing-TuiPP-260109.pdf',
  ];

  for (final name in catalogNames) {
    final source = File(p.join(sourceDirectory, name));
    if (!source.existsSync()) {
      throw StateError('Không tìm thấy catalog nguồn: ${source.path}');
    }
    source.copySync(p.join(outputDirectory.path, name));
  }
  print('📚 Đã đồng bộ 3 catalog tiếng Việt vào assets/catalogs');
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

double? _parseDouble(String? s) {
  if (s == null || s.isEmpty || s == '-') return null;
  return double.tryParse(s);
}

int? _parseInt(String? s) {
  if (s == null || s.isEmpty || s == '-') return null;
  final d = double.tryParse(s);
  return d?.round();
}
