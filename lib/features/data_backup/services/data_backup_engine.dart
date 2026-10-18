import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../models/backup_manifest.dart';

/// Các thư mục mà bộ sao lưu đọc/ghi.
class BackupLocations {
  const BackupLocations({
    required this.documents,
    required this.databases,
    required this.work,
  });

  /// Thư mục Documents của app — dữ liệu người dùng nằm trong
  /// [DataBackupEngine.userFolder] bên trong.
  final Directory documents;

  /// Thư mục chứa các file SQLite.
  final Directory databases;

  /// Thư mục tạm của bộ sao lưu (file sao lưu tạo ra, giải nén, bản dự phòng
  /// khi khôi phục). Phải cùng ổ với [documents]/[databases] để đổi chỗ nhanh.
  final Directory work;
}

/// Đóng gói toàn bộ dữ liệu người dùng thành 1 file zip và khôi phục lại.
///
/// File zip gồm:
/// - `manifest.json`: [BackupManifest]
/// - `preferences.json`: cài đặt cá nhân (không có phiên đăng nhập, bộ nhớ đệm)
/// - `databases/<tên>.db`: các cơ sở dữ liệu trong [databaseFiles]
/// - `files/DTCProduct/...`: ảnh, tệp đính kèm, PDF đã lưu
///
/// Khôi phục thay TOÀN BỘ dữ liệu hiện có. Dữ liệu cũ được chuyển sang bản dự
/// phòng trước, có lỗi giữa chừng thì trả lại như cũ.
class DataBackupEngine {
  DataBackupEngine({
    required this.locations,
    required this.prefs,
    required this.databaseFactory,
    required this.closeDatabases,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// Mọi cơ sở dữ liệu của app (xem các class `*Database` và `LocalDatabase`).
  /// Thêm cơ sở dữ liệu mới thì phải thêm vào đây và vào
  /// `DataBackupService.closeAllDatabases`.
  static const databaseFiles = [
    'user_data.db',
    'factory_location.db',
    'fault_bank.db',
    'grinding_machines.db',
    'maintenance_reports.db',
    'project_tracking.db',
    'site_layout.db',
  ];

  /// Bảng chứa dữ liệu người dùng tự tạo (không tính catalog nạp sẵn) — dùng
  /// để quyết định có nhắc sao lưu hay không.
  static const userContentTables = {
    'user_data.db': ['notes', 'daily_goals', 'maintenance_records'],
    'factory_location.db': ['factory_locations'],
    'fault_bank.db': ['fault_records'],
    'maintenance_reports.db': ['maintenance_reports'],
    'project_tracking.db': ['projects'],
    'site_layout.db': ['site_layout_projects'],
    'grinding_machines.db': [
      'grinding_selection_projects',
      'grinding_proposals',
    ],
  };

  static const userFolder = 'DTCProduct';
  static const preferencesEntry = 'preferences.json';
  static const _dbEntryPrefix = 'databases/';
  static const _filesEntryPrefix = 'files/';
  static const _dbSidecars = ['-wal', '-shm', '-journal'];
  static const _storedExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.pdf', '.zip', '.glb', //
    '.mp4', '.mov', '.xlsx', '.docx',
  };

  /// Cài đặt không đưa vào bản sao lưu: phiên đăng nhập, bộ nhớ đệm thư viện
  /// tài liệu, nhật ký lỗi và trạng thái của chính bộ sao lưu.
  static bool isBackedUpPreference(String key) =>
      !key.startsWith('auth_') &&
      !key.startsWith('drive_docs_folder_') &&
      !key.startsWith('data_backup_') &&
      key != 'app_error_log';

  final BackupLocations locations;
  final SharedPreferences prefs;
  final DatabaseFactory databaseFactory;
  final Future<void> Function() closeDatabases;
  final DateTime Function() _now;

  // ---------------------------------------------------------------- Sao lưu

  Future<BackupFileInfo> createBackup({
    required String appVersion,
    required int appBuild,
    required String platform,
    String? accountEmail,
  }) async {
    final outDir = await _freshDir('backups');
    final createdAt = _now();
    final fileName = 'DTCProduct-SaoLuu-${_stamp(createdAt)}.zip';
    final outPath = p.join(outDir.path, fileName);

    // Đóng để mọi thay đổi đã ghi hẳn vào file .db trước khi chép.
    await closeDatabases();
    final encoder = ZipFileEncoder()..create(outPath);
    var databaseCount = 0;
    var fileCount = 0;
    var totalBytes = 0;
    try {
      for (final name in databaseFiles) {
        final file = File(p.join(locations.databases.path, name));
        if (!await file.exists()) continue;
        await encoder.addFile(file, '$_dbEntryPrefix$name');
        databaseCount++;
        totalBytes += await file.length();
        final wal = File('${file.path}-wal');
        if (await wal.exists() && await wal.length() > 0) {
          await encoder.addFile(wal, '$_dbEntryPrefix$name-wal');
          totalBytes += await wal.length();
        }
      }

      final folder = Directory(p.join(locations.documents.path, userFolder));
      if (await folder.exists()) {
        await for (final entity in folder.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          final relative = p.relative(
            entity.path,
            from: locations.documents.path,
          );
          final stored = _storedExtensions.contains(
            p.extension(entity.path).toLowerCase(),
          );
          await encoder.addFile(
            entity,
            '$_filesEntryPrefix${p.posix.joinAll(p.split(relative))}',
            stored ? ZipFileEncoder.STORE : ZipFileEncoder.GZIP,
          );
          fileCount++;
          totalBytes += await entity.length();
        }
      }

      _addJson(encoder, preferencesEntry, _exportPreferences());
      final manifest = BackupManifest(
        createdAt: createdAt,
        appVersion: appVersion,
        appBuild: appBuild,
        platform: platform,
        documentsPath: locations.documents.path,
        accountEmail: accountEmail,
        databaseCount: databaseCount,
        fileCount: fileCount,
        totalBytes: totalBytes,
      );
      _addJson(encoder, BackupManifest.fileName, manifest.toJson());
      await encoder.close();
      return BackupFileInfo(
        path: outPath,
        fileName: fileName,
        sizeBytes: await File(outPath).length(),
        manifest: manifest,
      );
    } catch (_) {
      try {
        await encoder.close();
      } catch (_) {}
      await _deleteQuietly(File(outPath));
      rethrow;
    }
  }

  // ----------------------------------------------------------- Đọc tờ khai

  Future<BackupManifest> readManifest(String path) async {
    final input = _openInput(path);
    try {
      final entry = _decode(input).findFile(BackupManifest.fileName);
      if (entry == null) {
        throw const BackupException(
          'File này không phải file sao lưu của DTC Product.',
        );
      }
      return BackupManifest.fromJson(_decodeJson(entry));
    } on FormatException catch (error) {
      throw BackupException(error.message);
    } finally {
      await input.close();
    }
  }

  // -------------------------------------------------------------- Khôi phục

  /// Thay toàn bộ dữ liệu trên máy bằng dữ liệu trong file [path]. Lỗi giữa
  /// chừng thì trả lại dữ liệu cũ rồi ném lỗi.
  Future<BackupManifest> restore(
    String path, {
    required int currentBuild,
  }) async {
    final manifest = await readManifest(path);
    if (manifest.appBuild > currentBuild) {
      throw BackupException(
        'File sao lưu được tạo từ app phiên bản ${manifest.appVersion}, mới '
        'hơn app đang dùng. Hãy cập nhật app rồi khôi phục lại.',
      );
    }

    final staging = await _freshDir('restore_staging');
    final previous = await _freshDir('restore_previous');
    try {
      final restoredPrefs = await _extract(path, staging);

      await closeDatabases();
      final currentPrefs = _exportPreferences();
      var movedCurrent = false;
      try {
        await _moveCurrentDataTo(previous);
        movedCurrent = true;
        await _installFrom(staging);
        await _rewritePaths(manifest.documentsPath, locations.documents.path);
        await _applyPreferences(
          restoredPrefs,
          oldRoot: manifest.documentsPath,
          newRoot: locations.documents.path,
        );
      } catch (_) {
        if (movedCurrent) await _rollback(previous, currentPrefs);
        rethrow;
      }
    } finally {
      await _deleteQuietly(staging);
    }
    await _deleteQuietly(previous);
    return manifest;
  }

  Future<Map<String, Object?>> _extract(String path, Directory staging) async {
    final input = _openInput(path);
    Map<String, Object?> preferences = const {};
    try {
      for (final entry in _decode(input).files) {
        if (!entry.isFile) continue;
        if (entry.name == preferencesEntry) {
          final json = _decodeJson(entry);
          if (json is Map<String, Object?>) preferences = json;
          continue;
        }
        final target = _stagingTarget(staging, entry.name);
        if (target == null) continue;
        await target.parent.create(recursive: true);
        final output = OutputFileStream(target.path);
        try {
          entry.writeContent(output);
        } finally {
          await output.close();
        }
      }
    } on FormatException {
      throw const BackupException('File sao lưu bị hỏng, không đọc được.');
    } finally {
      await input.close();
    }
    return preferences;
  }

  /// Chỉ nhận đúng các mục do [createBackup] tạo ra; bỏ qua mục lạ và mọi
  /// đường dẫn thoát ra ngoài thư mục giải nén.
  File? _stagingTarget(Directory staging, String name) {
    if (name.startsWith(_dbEntryPrefix)) {
      final dbName = name.substring(_dbEntryPrefix.length);
      final base = dbName.endsWith('-wal')
          ? dbName.substring(0, dbName.length - 4)
          : dbName;
      if (!databaseFiles.contains(base)) return null;
      return File(p.join(staging.path, 'databases', dbName));
    }
    if (!name.startsWith('$_filesEntryPrefix$userFolder/') ||
        name.contains('\\')) {
      return null;
    }
    final parts = p.posix.split(name.substring(_filesEntryPrefix.length));
    if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      return null;
    }
    final root = p.join(staging.path, 'files');
    final target = p.normalize(p.joinAll([root, ...parts]));
    return p.isWithin(root, target) ? File(target) : null;
  }

  Future<void> _moveCurrentDataTo(Directory previous) async {
    for (final name in databaseFiles) {
      for (final suffix in ['', ..._dbSidecars]) {
        final file = File(p.join(locations.databases.path, '$name$suffix'));
        if (await file.exists()) {
          await _moveFile(
            file,
            p.join(previous.path, 'databases', '$name$suffix'),
          );
        }
      }
    }
    final folder = Directory(p.join(locations.documents.path, userFolder));
    if (await folder.exists()) {
      await _moveDir(folder, p.join(previous.path, 'files', userFolder));
    }
  }

  Future<void> _installFrom(Directory staging) async {
    final stagedDatabases = Directory(p.join(staging.path, 'databases'));
    if (await stagedDatabases.exists()) {
      await locations.databases.create(recursive: true);
      await for (final entity in stagedDatabases.list()) {
        if (entity is File) {
          await _moveFile(
            entity,
            p.join(locations.databases.path, p.basename(entity.path)),
          );
        }
      }
    }
    final stagedFolder = Directory(p.join(staging.path, 'files', userFolder));
    if (await stagedFolder.exists()) {
      await locations.documents.create(recursive: true);
      await _moveDir(
        stagedFolder,
        p.join(locations.documents.path, userFolder),
      );
    }
  }

  Future<void> _rollback(
    Directory previous,
    Map<String, Object?> previousPrefs,
  ) async {
    for (final name in databaseFiles) {
      for (final suffix in ['', ..._dbSidecars]) {
        await _deleteQuietly(
          File(p.join(locations.databases.path, '$name$suffix')),
        );
      }
    }
    await _deleteQuietly(
      Directory(p.join(locations.documents.path, userFolder)),
    );
    await _installFrom(previous);
    await _applyPreferences(previousPrefs);
  }

  /// Ảnh và tệp đính kèm được lưu bằng đường dẫn đầy đủ. Máy mới có thể có
  /// thư mục Documents khác, nên đổi phần đầu đường dẫn trong mọi cột chữ.
  Future<void> _rewritePaths(String oldRoot, String newRoot) async {
    if (p.equals(oldRoot, newRoot)) return;
    final replacements = _pathReplacements(oldRoot, newRoot);
    for (final name in databaseFiles) {
      final path = p.join(locations.databases.path, name);
      if (!await File(path).exists()) continue;
      final db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        await db.transaction((txn) async {
          final tables = await txn.rawQuery(
            "SELECT name, sql FROM sqlite_master WHERE type = 'table'",
          );
          final virtualTables = [
            for (final table in tables)
              if ('${table['sql']}'.toUpperCase().startsWith('CREATE VIRTUAL'))
                '${table['name']}',
          ];
          for (final table in tables) {
            final tableName = '${table['name']}';
            if (tableName.startsWith('sqlite_') ||
                tableName == 'android_metadata' ||
                virtualTables.any(
                  (v) => tableName == v || tableName.startsWith('${v}_'),
                )) {
              continue;
            }
            final columns = await txn.rawQuery(
              'PRAGMA table_info(${_quote(tableName)})',
            );
            for (final column in columns) {
              final type = '${column['type']}'.toUpperCase();
              if (type.isNotEmpty &&
                  !type.contains('TEXT') &&
                  !type.contains('CHAR') &&
                  !type.contains('CLOB')) {
                continue;
              }
              final col = _quote('${column['name']}');
              for (final (from, to) in replacements) {
                await txn.rawUpdate(
                  'UPDATE ${_quote(tableName)} SET $col = REPLACE($col, ?, ?) '
                  'WHERE instr($col, ?) > 0',
                  [from, to, from],
                );
              }
            }
          }
        });
      } finally {
        await db.close();
      }
    }
  }

  // --------------------------------------------------- Nhắc sao lưu

  /// Máy có dữ liệu người dùng tự tạo hay chưa (ghi chú, dự án, ảnh...).
  Future<bool> hasUserData() async {
    for (final entry in userContentTables.entries) {
      final path = p.join(locations.databases.path, entry.key);
      if (!await File(path).exists()) continue;
      Database? db;
      try {
        db = await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        for (final table in entry.value) {
          try {
            final rows = await db.rawQuery(
              'SELECT 1 FROM ${_quote(table)} LIMIT 1',
            );
            if (rows.isNotEmpty) return true;
          } on DatabaseException {
            // Bảng chưa được tạo ở phiên bản cơ sở dữ liệu này.
          }
        }
      } catch (_) {
        // Không đọc được thì coi như không có dữ liệu ở file này.
      } finally {
        await db?.close();
      }
    }
    final folder = Directory(p.join(locations.documents.path, userFolder));
    if (await folder.exists()) {
      return folder.list(recursive: true).any((entity) => entity is File);
    }
    return false;
  }

  // ------------------------------------------------------ Cài đặt cá nhân

  Map<String, Object?> _exportPreferences() {
    final result = <String, Object?>{};
    for (final key in prefs.getKeys()) {
      if (!isBackedUpPreference(key)) continue;
      final value = prefs.get(key);
      result[key] = switch (value) {
        String v => {'t': 's', 'v': v},
        bool v => {'t': 'b', 'v': v},
        int v => {'t': 'i', 'v': v},
        double v => {'t': 'd', 'v': v},
        List _ => {'t': 'l', 'v': prefs.getStringList(key)},
        _ => null,
      };
    }
    result.removeWhere((_, value) => value == null);
    return result;
  }

  Future<void> _applyPreferences(
    Map<String, Object?> values, {
    String? oldRoot,
    String? newRoot,
  }) async {
    final replacements =
        oldRoot == null || newRoot == null || p.equals(oldRoot, newRoot)
        ? const <(String, String)>[]
        : _pathReplacements(oldRoot, newRoot);
    String fix(String text) {
      for (final (from, to) in replacements) {
        text = text.replaceAll(from, to);
      }
      return text;
    }

    for (final key in prefs.getKeys().toList()) {
      if (isBackedUpPreference(key)) await prefs.remove(key);
    }
    for (final MapEntry(:key, :value) in values.entries) {
      if (!isBackedUpPreference(key) || value is! Map) continue;
      final v = value['v'];
      switch (value['t']) {
        case 's' when v is String:
          await prefs.setString(key, fix(v));
        case 'b' when v is bool:
          await prefs.setBool(key, v);
        case 'i' when v is int:
          await prefs.setInt(key, v);
        case 'd' when v is num:
          await prefs.setDouble(key, v.toDouble());
        case 'l' when v is List:
          await prefs.setStringList(key, [for (final s in v) fix('$s')]);
      }
    }
  }

  // ------------------------------------------------------------- Tiện ích

  InputFileStream _openInput(String path) {
    try {
      return InputFileStream(path);
    } catch (_) {
      throw const BackupException('Không mở được file đã chọn.');
    }
  }

  Archive _decode(InputFileStream input) {
    try {
      return ZipDecoder().decodeBuffer(input);
    } catch (_) {
      throw const BackupException(
        'Không đọc được file. File không phải file sao lưu của DTC Product '
        'hoặc đã bị hỏng.',
      );
    }
  }

  Object? _decodeJson(ArchiveFile entry) {
    try {
      return jsonDecode(utf8.decode(entry.content as List<int>));
    } on FormatException {
      throw const BackupException('File sao lưu bị hỏng, không đọc được.');
    }
  }

  void _addJson(ZipFileEncoder encoder, String name, Object? value) {
    final bytes = utf8.encode(jsonEncode(value));
    encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
  }

  Future<Directory> _freshDir(String name) async {
    final dir = Directory(p.join(locations.work.path, name));
    await _deleteQuietly(dir);
    return dir.create(recursive: true);
  }

  Future<void> _moveFile(File file, String target) async {
    await Directory(p.dirname(target)).create(recursive: true);
    try {
      await file.rename(target);
    } on FileSystemException {
      await file.copy(target);
      await file.delete();
    }
  }

  Future<void> _moveDir(Directory dir, String target) async {
    await Directory(p.dirname(target)).create(recursive: true);
    try {
      await dir.rename(target);
    } on FileSystemException {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final dest = p.join(target, p.relative(entity.path, from: dir.path));
        await Directory(p.dirname(dest)).create(recursive: true);
        await entity.copy(dest);
      }
      await dir.delete(recursive: true);
    }
  }

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete(recursive: true);
    } catch (_) {}
  }

  /// Cặp (cũ, mới) cần thay: đường dẫn thường và dạng đã mã hoá trong JSON
  /// (danh sách ảnh lưu dạng JSON; trên Windows dấu `` bị nhân đôi).
  static List<(String, String)> _pathReplacements(
    String oldRoot,
    String newRoot,
  ) {
    final from = _withSeparator(oldRoot);
    final to = _withSeparator(newRoot);
    String json(String s) {
      final encoded = jsonEncode(s);
      return encoded.substring(1, encoded.length - 1);
    }

    return [(from, to), if (json(from) != from) (json(from), json(to))];
  }

  /// Đường dẫn có thể đến từ máy khác hệ điều hành nên tự nhận dấu phân cách.
  static String _withSeparator(String path) {
    final separator = path.contains('\\') ? '\\' : '/';
    return path.endsWith(separator) ? path : '$path$separator';
  }

  static String _quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)}-${two(t.hour)}${two(t.minute)}';
  }
}
