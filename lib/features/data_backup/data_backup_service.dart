import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/local_database.dart';
import '../../providers/settings_provider.dart';
import '../../services/daily_goal_notification_service.dart';
import '../../services/note_notification_service.dart';
import '../air_system_config/data/air_config_database.dart';
import '../pipe_survey/data/pipe_survey_database.dart';
import '../auth/services/auth_service.dart';
import '../factory_location/data/factory_location_database.dart';
import '../fault_bank/data/fault_bank_database.dart';
import '../grinding_machine/data/grinding_machine_database.dart';
import '../maintenance_report/data/maintenance_report_database.dart';
import '../projects/data/project_database.dart';
import '../projects/repositories/local_project_repository.dart';
import '../projects/services/project_notification_service.dart';
import '../site_layout/data/site_layout_database.dart';
import '../technical_dictionary/data/technical_dictionary_database.dart';
import 'models/backup_manifest.dart';
import 'services/data_backup_platform.dart'
    if (dart.library.io) 'services/data_backup_platform_io.dart';

/// Sao lưu toàn bộ dữ liệu người dùng thành 1 file để cất lên Google Drive,
/// và khôi phục lại khi đổi điện thoại hoặc cài lại app.
class DataBackupService {
  DataBackupService._();

  static bool get isSupported => platformBackupSupported;

  static const _lastBackupKey = 'data_backup_last_at';
  static const _firstSeenKey = 'data_backup_first_seen_at';
  static const _lastRemindedKey = 'data_backup_last_reminded_at';
  static const _postRestoreKey = 'data_backup_post_restore';

  /// Nhắc sao lưu khi đã quá chừng này ngày kể từ lần sao lưu gần nhất.
  static const reminderInterval = Duration(days: 7);

  /// Mỗi ngày nhắc tối đa 1 lần.
  static const reminderRepeat = Duration(days: 1);

  static Future<void> closeAllDatabases() async {
    await LocalDatabase.instance.close();
    await FactoryLocationDatabase.instance.close();
    await FaultBankDatabase.instance.close();
    await GrindingMachineDatabase.instance.close();
    await MaintenanceReportDatabase.instance.close();
    await ProjectDatabase.instance.close();
    await SiteLayoutDatabase.instance.close();
    await TechnicalDictionaryDatabase.instance.close();
    await AirConfigDatabase.instance.close();
    await PipeSurveyDatabase.instance.close();
  }

  static Future<(String, int)> _appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (info.version, int.tryParse(info.buildNumber) ?? 0);
  }

  static Future<BackupFileInfo> createBackup() async {
    final (version, build) = await _appVersion();
    return platformCreateBackup(
      closeDatabases: closeAllDatabases,
      appVersion: version,
      appBuild: build,
      accountEmail: AuthService.instance.email,
    );
  }

  static Future<BackupManifest> readBackup(String path) =>
      platformReadManifest(path);

  /// Thay toàn bộ dữ liệu trên máy bằng file sao lưu. Sau khi xong, app cần
  /// được mở lại để đọc dữ liệu mới (xem [runPostRestoreTasks]).
  static Future<BackupManifest> restore(String path) async {
    final (_, build) = await _appVersion();
    final manifest = await platformRestore(
      path,
      closeDatabases: closeAllDatabases,
      currentBuild: build,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_postRestoreKey, true);
    // Nhắc hẹn của dữ liệu cũ không còn đúng; lần mở app tới sẽ đặt lại.
    try {
      await NoteNotificationService.ensureInitialized();
      if (NoteNotificationService.isReady) {
        await NoteNotificationService.sharedPlugin.cancelAll();
      }
    } catch (error) {
      debugPrint('DataBackup: không huỷ được nhắc hẹn cũ: $error');
    }
    return manifest;
  }

  /// Gọi khi app khởi động. Sau một lần khôi phục: đặt lại nhắc mục tiêu
  /// hằng ngày và nhắc hạn giai đoạn dự án. Nhắc hẹn ghi chú tự được đặt lại
  /// khi `NotesProvider` nạp ghi chú.
  static Future<void> runPostRestoreTasks(
    SharedPreferences prefs,
    SettingsProvider settings,
  ) async {
    if (prefs.getBool(_postRestoreKey) != true) return;
    await prefs.remove(_postRestoreKey);
    try {
      if (settings.homeDailyGoalsEnabled &&
          settings.homeDailyGoalsReminderEnabled) {
        await DailyGoalNotificationService.scheduleDailyReminder(
          hour: settings.homeDailyGoalsReminderHour,
          minute: settings.homeDailyGoalsReminderMinute,
        );
      }
      final repository = LocalProjectRepository();
      final names = {
        for (final project in await repository.getProjects())
          project.id: project.projectName,
      };
      for (final stage in await repository.getAllStages()) {
        await ProjectNotificationService.scheduleStageReminder(
          projectId: stage.projectId,
          projectName: names[stage.projectId] ?? '',
          stage: stage,
        );
      }
    } catch (error) {
      debugPrint('DataBackup: không đặt lại được nhắc hẹn: $error');
    }
  }

  static DateTime? lastBackupAt(SharedPreferences prefs) =>
      _readTime(prefs, _lastBackupKey);

  static Future<void> markBackedUp(SharedPreferences prefs) =>
      prefs.setInt(_lastBackupKey, DateTime.now().millisecondsSinceEpoch);

  /// Trả về số ngày chưa sao lưu nếu cần nhắc ngay bây giờ (null = không
  /// nhắc). `0` nghĩa là chưa sao lưu lần nào. Đã nhắc thì ghi lại để không
  /// nhắc lại trong [reminderRepeat].
  static Future<int?> checkReminder(SharedPreferences prefs) async {
    if (!isSupported) return null;
    final now = DateTime.now();
    final firstSeen = _readTime(prefs, _firstSeenKey);
    if (firstSeen == null) {
      await prefs.setInt(_firstSeenKey, now.millisecondsSinceEpoch);
      return null;
    }
    final lastBackup = lastBackupAt(prefs);
    final due = reminderDue(
      now: now,
      firstSeen: firstSeen,
      lastBackup: lastBackup,
      lastReminded: _readTime(prefs, _lastRemindedKey),
    );
    if (!due || !await platformHasUserData()) return null;
    await prefs.setInt(_lastRemindedKey, now.millisecondsSinceEpoch);
    return lastBackup == null ? 0 : now.difference(lastBackup).inDays;
  }

  @visibleForTesting
  static bool reminderDue({
    required DateTime now,
    required DateTime firstSeen,
    DateTime? lastBackup,
    DateTime? lastReminded,
  }) {
    final since = lastBackup ?? firstSeen;
    if (now.difference(since) < reminderInterval) return false;
    return lastReminded == null ||
        now.difference(lastReminded) >= reminderRepeat ||
        now.isBefore(lastReminded);
  }

  static DateTime? _readTime(SharedPreferences prefs, String key) {
    final ms = prefs.getInt(key);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
