import '../models/backup_manifest.dart';

// Bản web: dữ liệu nằm trong trình duyệt, chưa hỗ trợ sao lưu thành file.

const bool platformBackupSupported = false;

Never _unsupported() =>
    throw const BackupException('Sao lưu dữ liệu chỉ có trên app Android.');

Future<BackupFileInfo> platformCreateBackup({
  required Future<void> Function() closeDatabases,
  required String appVersion,
  required int appBuild,
  String? accountEmail,
}) async => _unsupported();

Future<BackupManifest> platformReadManifest(String path) async =>
    _unsupported();

Future<BackupManifest> platformRestore(
  String path, {
  required Future<void> Function() closeDatabases,
  required int currentBuild,
}) async => _unsupported();

Future<bool> platformHasUserData() async => false;
