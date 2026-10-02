import 'package:sqflite/sqflite.dart';

import '../data/factory_location_database.dart';
import '../models/factory_location.dart';

class FactoryLocationRepository {
  FactoryLocationRepository({FactoryLocationDatabase? database})
    : _database = database ?? FactoryLocationDatabase.instance;

  final FactoryLocationDatabase _database;

  Future<Database> get _db => _database.database;

  Future<List<FactoryLocation>> getAll() async {
    final db = await _db;
    final rows = await db.query(
      'factory_locations',
      orderBy: 'updatedAt DESC, id DESC',
    );
    return rows.map(FactoryLocation.fromMap).toList();
  }

  Future<int> save(FactoryLocation location) async {
    final db = await _db;
    if (location.id == null) {
      return db.insert('factory_locations', location.toMap());
    }
    await db.update(
      'factory_locations',
      location.toMap(),
      where: 'id = ?',
      whereArgs: [location.id],
    );
    return location.id!;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('factory_locations', where: 'id = ?', whereArgs: [id]);
  }
}
