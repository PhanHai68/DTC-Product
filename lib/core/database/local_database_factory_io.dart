import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Factory dùng cho mọi cơ sở dữ liệu cục bộ của app (FFI trên Windows/Linux,
/// plugin trên Android/iOS/macOS).
DatabaseFactory localDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    return databaseFactoryFfi;
  }
  return databaseFactorySqflitePlugin;
}

Future<Database> openLocalDatabase({
  required String fileName,
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) async {
  final factory = localDatabaseFactory();
  final databasePath = p.join(await factory.getDatabasesPath(), fileName);
  return factory.openDatabase(
    databasePath,
    options: OpenDatabaseOptions(
      version: version,
      onCreate: onCreate,
      onUpgrade: onUpgrade,
    ),
  );
}
