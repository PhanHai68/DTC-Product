import 'package:sqflite/sqflite.dart';

Future<Database> openLocalDatabase({
  required String fileName,
  required int version,
  required OnDatabaseCreateFn onCreate,
  required OnDatabaseVersionChangeFn onUpgrade,
}) {
  throw UnsupportedError(
    'Nền tảng này chưa hỗ trợ cơ sở dữ liệu bảo trì cục bộ.',
  );
}
