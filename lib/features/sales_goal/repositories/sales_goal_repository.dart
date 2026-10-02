import 'package:sqflite/sqflite.dart';

import '../data/sales_goal_database.dart';
import '../models/sales_entry.dart';
import '../models/sales_focus_task.dart';
import '../models/sales_goal_summary.dart';
import '../models/sales_opportunity.dart';
import '../models/sales_target.dart';

class SalesGoalRepository {
  SalesGoalRepository({SalesGoalDatabase? database})
    : _database = database ?? SalesGoalDatabase.instance;

  final SalesGoalDatabase _database;

  Future<Database> get _db => _database.database;

  Future<SalesTarget?> getTarget(
    SalesTargetPeriod period,
    int year,
    int periodNumber,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'sales_targets',
      where: 'periodType = ? AND year = ? AND periodNumber = ?',
      whereArgs: [period.name, year, periodNumber],
      limit: 1,
    );
    return rows.isEmpty ? null : SalesTarget.fromMap(rows.first);
  }

  Future<void> saveTarget(SalesTarget target) async {
    final db = await _db;
    final existing = await getTarget(
      target.period,
      target.year,
      target.periodNumber,
    );
    final value = SalesTarget(
      id: existing?.id,
      period: target.period,
      year: target.year,
      periodNumber: target.periodNumber,
      amount: target.amount,
      createdAt: existing?.createdAt ?? target.createdAt,
      updatedAt: target.updatedAt,
    );
    await db.insert(
      'sales_targets',
      value.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTarget(
    SalesTargetPeriod period,
    int year,
    int periodNumber,
  ) async {
    final db = await _db;
    await db.delete(
      'sales_targets',
      where: 'periodType = ? AND year = ? AND periodNumber = ?',
      whereArgs: [period.name, year, periodNumber],
    );
  }

  Future<List<SalesEntry>> getEntriesBetween(
    DateTime start,
    DateTime endExclusive,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'sales_entries',
      where: 'saleDate >= ? AND saleDate < ?',
      whereArgs: [_dateOnly(start), _dateOnly(endExclusive)],
      orderBy: 'saleDate DESC, id DESC',
    );
    return rows.map(SalesEntry.fromMap).toList();
  }

  Future<int> saveEntry(SalesEntry entry) async {
    final db = await _db;
    if (entry.id == null) return db.insert('sales_entries', entry.toMap());
    await db.update(
      'sales_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    return entry.id!;
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db;
    await db.delete('sales_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SalesOpportunity>> getOpportunities() async {
    final db = await _db;
    final rows = await db.query(
      'sales_opportunities',
      orderBy: 'expectedCloseDate ASC, id DESC',
    );
    return rows.map(SalesOpportunity.fromMap).toList();
  }

  Future<int> saveOpportunity(SalesOpportunity opportunity) async {
    final db = await _db;
    if (opportunity.id == null) {
      return db.insert('sales_opportunities', opportunity.toMap());
    }
    await db.update(
      'sales_opportunities',
      opportunity.toMap(),
      where: 'id = ?',
      whereArgs: [opportunity.id],
    );
    return opportunity.id!;
  }

  Future<void> deleteOpportunity(int id) async {
    final db = await _db;
    await db.delete('sales_opportunities', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SalesFocusTask>> getFocusTasks(DateTime date) async {
    final db = await _db;
    final rows = await db.query(
      'sales_focus_tasks',
      where: 'focusDate = ?',
      whereArgs: [_dateOnly(date)],
      orderBy: 'isCompleted ASC, id DESC',
    );
    return rows.map(SalesFocusTask.fromMap).toList();
  }

  Future<int> saveFocusTask(SalesFocusTask task) async {
    final db = await _db;
    if (task.id == null) return db.insert('sales_focus_tasks', task.toMap());
    await db.update(
      'sales_focus_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    return task.id!;
  }

  Future<void> deleteFocusTask(int id) async {
    final db = await _db;
    await db.delete('sales_focus_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SalesMonthHistory>> getMonthlyHistory({
    required DateTime through,
    int monthCount = 12,
  }) async {
    final result = <SalesMonthHistory>[];
    for (var offset = monthCount - 1; offset >= 0; offset--) {
      final month = DateTime(through.year, through.month - offset);
      final target = await getTarget(
        SalesTargetPeriod.month,
        month.year,
        month.month,
      );
      final entries = await getEntriesBetween(
        month,
        DateTime(month.year, month.month + 1),
      );
      result.add(
        SalesMonthHistory(
          year: month.year,
          month: month.month,
          target: target?.amount ?? 0,
          actual: entries.fold(0, (sum, item) => sum + item.amount),
        ),
      );
    }
    return result;
  }

  Future<List<SalesQuarterHistory>> getQuarterlyHistory({
    required DateTime through,
    int quarterCount = 8,
  }) async {
    final result = <SalesQuarterHistory>[];
    final currentQuarter = ((through.month - 1) ~/ 3) + 1;
    for (var offset = quarterCount - 1; offset >= 0; offset--) {
      final absoluteQuarter = through.year * 4 + currentQuarter - 1 - offset;
      final year = absoluteQuarter ~/ 4;
      final quarter = absoluteQuarter % 4 + 1;
      final start = DateTime(year, (quarter - 1) * 3 + 1);
      final target = await getTarget(SalesTargetPeriod.quarter, year, quarter);
      final entries = await getEntriesBetween(
        start,
        DateTime(year, start.month + 3),
      );
      result.add(
        SalesQuarterHistory(
          year: year,
          quarter: quarter,
          target: target?.amount ?? 0,
          actual: entries.fold(0, (sum, item) => sum + item.amount),
        ),
      );
    }
    return result;
  }

  Future<List<int>> recordMilestones({
    required int year,
    required int month,
    required Iterable<int> milestones,
  }) async {
    final db = await _db;
    final inserted = <int>[];
    for (final milestone in milestones) {
      final id = await db.insert('sales_milestones', {
        'year': year,
        'month': month,
        'milestone': milestone,
        'achievedAt': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id > 0) inserted.add(milestone);
    }
    return inserted;
  }
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
