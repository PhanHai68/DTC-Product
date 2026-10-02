import 'package:flutter/foundation.dart';

import '../models/sales_entry.dart';
import '../models/sales_focus_task.dart';
import '../models/sales_goal_summary.dart';
import '../models/sales_opportunity.dart';
import '../models/sales_target.dart';
import '../repositories/sales_goal_repository.dart';
import '../services/sales_goal_calculator.dart';

class SalesGoalProvider extends ChangeNotifier {
  SalesGoalProvider({SalesGoalRepository? repository, DateTime Function()? now})
    : _repository = repository ?? SalesGoalRepository(),
      _now = now ?? DateTime.now;

  final SalesGoalRepository _repository;
  final DateTime Function() _now;

  bool _isLoading = false;
  String? _error;
  SalesGoalSummary? _summary;
  List<SalesEntry> _entries = const [];
  List<SalesOpportunity> _opportunities = const [];
  List<SalesFocusTask> _focusTasks = const [];
  List<SalesMonthHistory> _history = const [];
  List<SalesQuarterHistory> _quarterHistory = const [];
  List<int> _newMilestones = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  SalesGoalSummary? get summary => _summary;
  List<SalesEntry> get entries => List.unmodifiable(_entries);
  List<SalesOpportunity> get opportunities => List.unmodifiable(_opportunities);
  List<SalesFocusTask> get focusTasks => List.unmodifiable(_focusTasks);
  List<SalesMonthHistory> get history => List.unmodifiable(_history);
  List<SalesQuarterHistory> get quarterHistory =>
      List.unmodifiable(_quarterHistory);
  List<int> get newMilestones => List.unmodifiable(_newMilestones);

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;
    try {
      final now = _now();
      final quarter = ((now.month - 1) ~/ 3) + 1;
      final quarterStart = DateTime(now.year, (quarter - 1) * 3 + 1);
      final monthTarget = await _repository.getTarget(
        SalesTargetPeriod.month,
        now.year,
        now.month,
      );
      final quarterTarget = await _repository.getTarget(
        SalesTargetPeriod.quarter,
        now.year,
        quarter,
      );
      final entries = await _repository.getEntriesBetween(
        quarterStart,
        DateTime(now.year, quarterStart.month + 3),
      );
      final opportunities = await _repository.getOpportunities();
      final tasks = await _repository.getFocusTasks(now);
      final history = await _repository.getMonthlyHistory(through: now);
      final quarterHistory = await _repository.getQuarterlyHistory(
        through: now,
      );
      final summary = SalesGoalCalculator.calculate(
        now: now,
        monthlyTarget: monthTarget?.amount ?? 0,
        quarterlyTarget: quarterTarget?.amount ?? 0,
        entries: entries,
        opportunities: opportunities,
      );
      _entries = entries
          .where(
            (item) =>
                item.saleDate.year == now.year &&
                item.saleDate.month == now.month,
          )
          .toList();
      _opportunities = opportunities;
      _focusTasks = tasks;
      _history = history;
      _quarterHistory = quarterHistory;
      _summary = summary;
      _newMilestones = await _repository.recordMilestones(
        year: now.year,
        month: now.month,
        milestones: SalesGoalCalculator.reachedMilestones(summary),
      );
    } catch (error, stackTrace) {
      _error = 'Không thể tải dữ liệu mục tiêu doanh số.';
      debugPrint('SalesGoalProvider.load: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMilestoneNotice() {
    if (_newMilestones.isEmpty) return;
    _newMilestones = const [];
    notifyListeners();
  }

  Future<void> saveTargets({
    required int monthlyTarget,
    required int quarterlyTarget,
  }) async {
    final now = _now();
    final timestamp = DateTime.now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    await _repository.saveTarget(
      SalesTarget(
        period: SalesTargetPeriod.month,
        year: now.year,
        periodNumber: now.month,
        amount: monthlyTarget,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await _repository.saveTarget(
      SalesTarget(
        period: SalesTargetPeriod.quarter,
        year: now.year,
        periodNumber: quarter,
        amount: quarterlyTarget,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await load(showLoading: false);
  }

  Future<void> saveTarget({
    required SalesTargetPeriod period,
    required int year,
    required int periodNumber,
    required int amount,
  }) async {
    final timestamp = DateTime.now();
    await _repository.saveTarget(
      SalesTarget(
        period: period,
        year: year,
        periodNumber: periodNumber,
        amount: amount,
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    );
    await load(showLoading: false);
  }

  Future<void> deleteTarget({
    required SalesTargetPeriod period,
    required int year,
    required int periodNumber,
  }) async {
    await _repository.deleteTarget(period, year, periodNumber);
    await load(showLoading: false);
  }

  Future<void> deleteCurrentTargets() async {
    final now = _now();
    final quarter = ((now.month - 1) ~/ 3) + 1;
    await _repository.deleteTarget(
      SalesTargetPeriod.month,
      now.year,
      now.month,
    );
    await _repository.deleteTarget(
      SalesTargetPeriod.quarter,
      now.year,
      quarter,
    );
    await load(showLoading: false);
  }

  Future<void> saveEntry(SalesEntry entry) async {
    await _repository.saveEntry(entry);
    await load(showLoading: false);
  }

  Future<List<SalesEntry>> entriesForMonth(DateTime month) =>
      _repository.getEntriesBetween(
        DateTime(month.year, month.month),
        DateTime(month.year, month.month + 1),
      );

  Future<void> deleteEntry(int id) async {
    await _repository.deleteEntry(id);
    await load(showLoading: false);
  }

  Future<void> saveOpportunity(SalesOpportunity opportunity) async {
    await _repository.saveOpportunity(opportunity);
    await load(showLoading: false);
  }

  Future<void> deleteOpportunity(int id) async {
    await _repository.deleteOpportunity(id);
    await load(showLoading: false);
  }

  Future<void> convertOpportunityToEntry(SalesOpportunity opportunity) async {
    final now = DateTime.now();
    await _repository.saveEntry(
      SalesEntry(
        saleDate: now,
        amount: opportunity.estimatedValue,
        customerOrProject: opportunity.customerOrProject,
        productOrMachine: opportunity.productOrMachine,
        notes: 'Ghi nhận từ cơ hội bán hàng',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await _repository.saveOpportunity(
      opportunity.copyWith(status: SalesOpportunityStatus.won, updatedAt: now),
    );
    await load(showLoading: false);
  }

  Future<void> addFocusTask(String title) async {
    final now = _now();
    await _repository.saveFocusTask(
      SalesFocusTask(
        title: title.trim(),
        focusDate: now,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await load(showLoading: false);
  }

  Future<void> toggleFocusTask(SalesFocusTask task) async {
    final completed = !task.isCompleted;
    await _repository.saveFocusTask(
      task.copyWith(
        isCompleted: completed,
        completedAt: completed ? DateTime.now() : null,
        clearCompletedAt: !completed,
        updatedAt: DateTime.now(),
      ),
    );
    await load(showLoading: false);
  }

  Future<void> renameFocusTask(SalesFocusTask task, String title) async {
    await _repository.saveFocusTask(
      task.copyWith(title: title.trim(), updatedAt: DateTime.now()),
    );
    await load(showLoading: false);
  }

  Future<void> deleteFocusTask(int id) async {
    await _repository.deleteFocusTask(id);
    await load(showLoading: false);
  }
}
