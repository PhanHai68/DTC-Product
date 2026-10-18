import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/local_database_factory_io.dart';
import '../models/backup_manifest.dart';
import 'data_backup_engine.dart';

const bool platformBackupSupported = true;

Future<DataBackupEngine> _engine({
  Future<void> Function()? closeDatabases,
}) async {
  final factory = localDatabaseFactory();
  return DataBackupEngine(
    locations: BackupLocations(
      documents: await getApplicationDocumentsDirectory(),
      databases: Directory(await factory.getDatabasesPath()),
      work: Directory(
        p.join((await getTemporaryDirectory()).path, 'data_backup'),
      ),
    ),
    prefs: await SharedPreferences.getInstance(),
    databaseFactory: factory,
    closeDatabases: closeDatabases ?? () async {},
  );
}

Future<BackupFileInfo> platformCreateBackup({
  required Future<void> Function() closeDatabases,
  required String appVersion,
  required int appBuild,
  String? accountEmail,
}) async => (await _engine(closeDatabases: closeDatabases)).createBackup(
  appVersion: appVersion,
  appBuild: appBuild,
  platform: Platform.operatingSystem,
  accountEmail: accountEmail,
);

Future<BackupManifest> platformReadManifest(String path) async =>
    (await _engine()).readManifest(path);

Future<BackupManifest> platformRestore(
  String path, {
  required Future<void> Function() closeDatabases,
  required int currentBuild,
}) async =>
    (await _engine(closeDatabases: closeDatabases))
        .restore(path, currentBuild: currentBuild);

Future<bool> platformHasUserData() async => (await _engine()).hasUserData();
