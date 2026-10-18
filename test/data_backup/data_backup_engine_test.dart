import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:dtc_product/features/data_backup/data_backup_service.dart';
import 'package:dtc_product/features/data_backup/models/backup_manifest.dart';
import 'package:dtc_product/features/data_backup/services/data_backup_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Một "điện thoại" giả lập: thư mục Documents, thư mục cơ sở dữ liệu và
/// thư mục tạm riêng.
class _Device {
  _Device(Directory root)
    : locations = BackupLocations(
        documents: Directory(p.join(root.path, 'documents')),
        databases: Directory(p.join(root.path, 'databases')),
        work: Directory(p.join(root.path, 'work')),
      );

  final BackupLocations locations;

  String get photosDir =>
      p.join(locations.documents.path, 'DTCProduct', 'FaultBank', 'photos');

  String dbPath(String name) => p.join(locations.databases.path, name);

  Future<DataBackupEngine> engine({int build = 30}) async {
    await locations.documents.create(recursive: true);
    await locations.databases.create(recursive: true);
    return DataBackupEngine(
      locations: locations,
      prefs: await SharedPreferences.getInstance(),
      databaseFactory: databaseFactoryFfiNoIsolate,
      closeDatabases: () async {},
      now: () => DateTime(2026, 11, 12, 9, 30),
    );
  }

  /// Tạo user_data.db với 1 ghi chú có đường dẫn ảnh, và file ảnh đó.
  Future<void> seedNote(String title) async {
    await Directory(photosDir).create(recursive: true);
    final photo = p.join(photosDir, 'a.jpg');
    await File(photo).writeAsBytes([1, 2, 3, 4]);
    await locations.databases.create(recursive: true);
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      dbPath('user_data.db'),
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS notes(id INTEGER PRIMARY KEY, title TEXT, '
      'photos TEXT, pinned INTEGER)',
    );
    await db.insert('notes', {
      'title': title,
      'photos': jsonEncode([photo]),
      'pinned': 1,
    });
    await db.close();
  }

  Future<List<Map<String, Object?>>> notes() async {
    final db = await databaseFactoryFfiNoIsolate.openDatabase(
      dbPath('user_data.db'),
    );
    try {
      return await db.query('notes');
    } finally {
      await db.close();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory temp;
  late _Device phoneA;
  late _Device phoneB;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('dtc_backup_test');
    phoneA = _Device(Directory(p.join(temp.path, 'a')));
    phoneB = _Device(Directory(p.join(temp.path, 'b')));
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<BackupFileInfo> backupFromPhoneA() async {
    SharedPreferences.setMockInitialValues({
      'settings_theme_mode': 'dark',
      'home_display_name': 'Kỹ sư Minh',
      'home_daily_goals_reminder_hour': 7,
      'settings_text_scale': 1.15,
      'global_search_recent_locations': ['/color_sorter'],
      'auth_email': 'minh@dtc.vn',
      'auth_refresh_token': 'rt-A',
      'drive_docs_folder_x': '[]',
      'app_error_log': '[]',
    });
    await phoneA.seedNote('Bảo trì SC16');
    final engine = await phoneA.engine();
    return engine.createBackup(
      appVersion: '1.0.23',
      appBuild: 24,
      platform: 'android',
      accountEmail: 'minh@dtc.vn',
    );
  }

  test('sao lưu rồi khôi phục sang máy mới giữ đủ dữ liệu', () async {
    final backup = await backupFromPhoneA();
    expect(backup.manifest.databaseCount, 1);
    expect(backup.manifest.fileCount, 1);
    expect(backup.fileName, 'DTCProduct-SaoLuu-2026-11-12-0930.zip');

    // Máy B: đã đăng nhập, có sẵn 1 ghi chú khác sẽ bị thay.
    SharedPreferences.setMockInitialValues({
      'auth_email': 'minh@dtc.vn',
      'auth_last_verified_ms': 1,
      'settings_theme_mode': 'light',
    });
    await phoneB.seedNote('Ghi chú trên máy mới');
    final engine = await phoneB.engine();
    final manifest = await engine.restore(backup.path, currentBuild: 24);
    expect(manifest.accountEmail, 'minh@dtc.vn');

    final notes = await phoneB.notes();
    expect(notes, hasLength(1));
    expect(notes.single['title'], 'Bảo trì SC16');
    // Đường dẫn ảnh đã đổi sang thư mục của máy B và file ảnh có thật.
    final photo =
        (jsonDecode(notes.single['photos']! as String) as List).single
            as String;
    expect(photo, p.join(phoneB.photosDir, 'a.jpg'));
    expect(await File(photo).readAsBytes(), [1, 2, 3, 4]);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_theme_mode'), 'dark');
    expect(prefs.getString('home_display_name'), 'Kỹ sư Minh');
    expect(prefs.getInt('home_daily_goals_reminder_hour'), 7);
    expect(prefs.getDouble('settings_text_scale'), 1.15);
    expect(prefs.getStringList('global_search_recent_locations'), [
      '/color_sorter',
    ]);
    // Phiên đăng nhập của máy B giữ nguyên, không lấy token của máy A.
    expect(prefs.getString('auth_refresh_token'), isNull);
    expect(prefs.getInt('auth_last_verified_ms'), 1);
    expect(prefs.getString('drive_docs_folder_x'), isNull);
  });

  test('không khôi phục file từ app mới hơn', () async {
    final backup = await backupFromPhoneA();
    SharedPreferences.setMockInitialValues({});
    final engine = await phoneB.engine();
    await expectLater(
      engine.restore(backup.path, currentBuild: 23),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('cập nhật app'),
        ),
      ),
    );
  });

  test('file không phải bản sao lưu bị từ chối', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = await phoneB.engine();
    final random = File(p.join(temp.path, 'anh.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    await expectLater(
      engine.readManifest(random.path),
      throwsA(isA<BackupException>()),
    );

    final otherZip = p.join(temp.path, 'khac.zip');
    final encoder = ZipFileEncoder()..create(otherZip);
    encoder.addArchiveFile(ArchiveFile('readme.txt', 2, [104, 105]));
    await encoder.close();
    await expectLater(
      engine.readManifest(otherZip),
      throwsA(isA<BackupException>()),
    );
  });

  Future<String> craftedBackup(Map<String, List<int>> entries) async {
    final path = p.join(temp.path, 'crafted.zip');
    final manifest = utf8.encode(
      jsonEncode(
        BackupManifest(
          createdAt: DateTime(2026, 11, 1),
          appVersion: '1.0.23',
          appBuild: 24,
          platform: 'android',
          documentsPath: '/data/user/0/old/app_flutter',
          databaseCount: 1,
          fileCount: 0,
          totalBytes: 0,
        ).toJson(),
      ),
    );
    final encoder = ZipFileEncoder()..create(path);
    encoder.addArchiveFile(
      ArchiveFile(BackupManifest.fileName, manifest.length, manifest),
    );
    for (final MapEntry(:key, :value) in entries.entries) {
      encoder.addArchiveFile(ArchiveFile(key, value.length, value));
    }
    await encoder.close();
    return path;
  }

  test('lỗi giữa chừng thì trả lại dữ liệu cũ', () async {
    SharedPreferences.setMockInitialValues({'settings_theme_mode': 'light'});
    await phoneB.seedNote('Dữ liệu đang dùng');
    final engine = await phoneB.engine();
    // Cơ sở dữ liệu hỏng: bước đổi đường dẫn sẽ lỗi.
    final path = await craftedBackup({
      'databases/user_data.db': utf8.encode('không phải sqlite'),
      'preferences.json': utf8.encode(
        jsonEncode({
          'settings_theme_mode': {'t': 's', 'v': 'dark'},
        }),
      ),
    });

    await expectLater(
      engine.restore(path, currentBuild: 24),
      throwsA(anything),
    );

    final notes = await phoneB.notes();
    expect(notes.single['title'], 'Dữ liệu đang dùng');
    expect(await File(p.join(phoneB.photosDir, 'a.jpg')).exists(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_theme_mode'), 'light');
  });

  test('bỏ qua mục lạ và đường dẫn thoát ra ngoài thư mục', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = await phoneB.engine();
    final path = await craftedBackup({
      'files/DTCProduct/../../evil.txt': [1],
      'files/khac/x.txt': [1],
      'databases/../../evil.db': [1],
      'databases/la.db': [1],
      'files/DTCProduct/GhiChu/ok.txt': [7],
    });

    await engine.restore(path, currentBuild: 24);

    expect(
      await File(
        p.join(
          phoneB.locations.documents.path,
          'DTCProduct',
          'GhiChu',
          'ok.txt',
        ),
      ).readAsBytes(),
      [7],
    );
    final all = await temp
        .list(recursive: true)
        .where((e) => e is File)
        .map((e) => p.basename(e.path))
        .toList();
    expect(all, isNot(contains('evil.txt')));
    expect(all, isNot(contains('evil.db')));
    expect(all, isNot(contains('la.db')));
  });

  test('nhận biết máy có dữ liệu người dùng tự tạo', () async {
    SharedPreferences.setMockInitialValues({});
    final engine = await phoneB.engine();
    expect(await engine.hasUserData(), isFalse);
    await phoneB.seedNote('Ghi chú đầu tiên');
    expect(await engine.hasUserData(), isTrue);
  });

  test('lịch nhắc sao lưu', () {
    final start = DateTime(2026, 11, 1, 8);
    bool due(DateTime now, {DateTime? backup, DateTime? reminded}) =>
        DataBackupService.reminderDue(
          now: now,
          firstSeen: start,
          lastBackup: backup,
          lastReminded: reminded,
        );

    // Dưới 7 ngày từ lúc cài app: chưa nhắc.
    expect(due(start.add(const Duration(days: 6))), isFalse);
    expect(due(start.add(const Duration(days: 7))), isTrue);
    // Sao lưu gần đây: chưa nhắc.
    expect(
      due(
        start.add(const Duration(days: 20)),
        backup: start.add(const Duration(days: 15)),
      ),
      isFalse,
    );
    // Đã nhắc hôm nay thì mai mới nhắc lại.
    final now = start.add(const Duration(days: 10));
    expect(due(now, reminded: now.subtract(const Duration(hours: 3))), isFalse);
    expect(due(now, reminded: now.subtract(const Duration(days: 1))), isTrue);
  });
}
