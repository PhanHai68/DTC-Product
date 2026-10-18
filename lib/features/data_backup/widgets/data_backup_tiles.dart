import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_error_log.dart';
import '../../auth/services/auth_service.dart';
import '../data_backup_service.dart';
import '../models/backup_manifest.dart';

final _timeFormat = DateFormat('HH:mm dd/MM/yyyy');

String formatBackupSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// Hai mục "Sao lưu dữ liệu" và "Khôi phục từ file sao lưu" trong Cài đặt.
class DataBackupTiles extends StatefulWidget {
  const DataBackupTiles({super.key});

  @override
  State<DataBackupTiles> createState() => _DataBackupTilesState();
}

class _DataBackupTilesState extends State<DataBackupTiles> {
  DateTime? _lastBackup;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _lastBackup = DataBackupService.lastBackupAt(prefs));
    }
  }

  /// Chạy [task] kèm hộp "Đang ...". Lỗi thì báo cho người dùng và trả null.
  Future<T?> _withProgress<T>(String message, Future<T> Function() task) async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    String? failure;
    try {
      return await task();
    } on BackupException catch (error) {
      failure = error.message;
    } catch (error, stack) {
      AppErrorLog.instance.record(error, stack, source: 'backup');
      failure =
          'Đã xảy ra lỗi ngoài dự kiến. Chi tiết được ghi trong Cài đặt → '
          'Nhật ký lỗi.\n\n$error';
    } finally {
      navigator.pop();
      if (mounted) setState(() => _busy = false);
    }
    await _showMessage('Không thực hiện được', failure);
    return null;
  }

  Future<void> _showMessage(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _backup() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final info = await _withProgress(
      'Đang tạo file sao lưu...',
      DataBackupService.createBackup,
    );
    if (info == null || !mounted) return;

    final ShareResult share;
    try {
      share = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(info.path, mimeType: 'application/zip')],
          fileNameOverrides: [info.fileName],
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      await _showMessage(
        'Không mở được bảng chia sẻ',
        'File sao lưu đã tạo nhưng không chia sẻ được: $error',
      );
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (share.status == ShareResultStatus.dismissed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa lưu file sao lưu. Bấm lại khi bạn sẵn sàng.'),
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await DataBackupService.markBackedUp(prefs);
    await _loadLastBackup();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          'Đã tạo file sao lưu (${formatBackupSize(info.sizeBytes)}). Hãy lưu '
          'vào Google Drive cá nhân, không gửi vào nhóm chung.',
        ),
      ),
    );
  }

  Future<void> _restore() async {
    final XFile? file;
    try {
      file = await openFile();
    } catch (error) {
      await _showMessage('Không chọn được file', '$error');
      return;
    }
    if (file == null || !mounted) return;
    final path = file.path;

    final manifest = await _withProgress(
      'Đang đọc file sao lưu...',
      () => DataBackupService.readBackup(path),
    );
    if (manifest == null || !mounted) return;
    if (await _confirmRestore(manifest) != true || !mounted) return;

    final restored = await _withProgress(
      'Đang khôi phục dữ liệu... Không tắt app.',
      () => DataBackupService.restore(path),
    );
    if (restored == null || !mounted) return;
    await _showRestartDialog();
  }

  Future<bool?> _confirmRestore(BackupManifest manifest) {
    final currentEmail = AuthService.instance.email;
    final otherAccount =
        manifest.accountEmail != null &&
        currentEmail != null &&
        manifest.accountEmail!.toLowerCase() != currentEmail.toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục dữ liệu?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File sao lưu lúc ${_timeFormat.format(manifest.createdAt)}',
              ),
              const SizedBox(height: 4),
              Text(
                'Gồm ${manifest.fileCount} ảnh/tệp, khoảng '
                '${formatBackupSize(manifest.totalBytes)}'
                '${manifest.appVersion.isEmpty ? '' : ' — app phiên bản ${manifest.appVersion}'}',
              ),
              if (manifest.accountEmail != null) ...[
                const SizedBox(height: 4),
                Text('Tài khoản: ${manifest.accountEmail}'),
              ],
              if (otherAccount) ...[
                const SizedBox(height: 8),
                Text(
                  'File này được tạo bởi tài khoản khác với tài khoản đang '
                  'đăng nhập.',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Toàn bộ dữ liệu hiện có trên máy này (ghi chú, dự án, ngân '
                'hàng lỗi, báo cáo, ảnh...) sẽ bị thay bằng dữ liệu trong file. '
                'Không hoàn tác được.',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRestartDialog() async {
    final canClose = defaultTargetPlatform == TargetPlatform.android;
    // Ngay sau khi khôi phục, dữ liệu đang hiển thị là dữ liệu cũ: chỉ cho
    // đóng app để lần mở sau đọc dữ liệu mới.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Khôi phục xong'),
          content: Text(
            canClose
                ? 'Bấm "Đóng app" rồi mở lại DTC Product để xem dữ liệu đã khôi '
                      'phục. Các nhắc hẹn sẽ được đặt lại khi mở app.'
                : 'Hãy tắt hẳn DTC Product rồi mở lại để xem dữ liệu đã khôi '
                      'phục. Các nhắc hẹn sẽ được đặt lại khi mở app.',
          ),
          actions: [
            if (canClose)
              FilledButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Đóng app'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!DataBackupService.isSupported) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: false,
        leading: Icon(Icons.backup_outlined),
        title: Text('Sao lưu & khôi phục dữ liệu'),
        subtitle: Text(
          'Chỉ có trên app Android. Bản web lưu dữ liệu trong trình duyệt này.',
        ),
      );
    }
    final last = _lastBackup;
    return Column(
      children: [
        ListTile(
          key: const Key('settings_backup'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.backup_outlined),
          title: const Text('Sao lưu dữ liệu'),
          subtitle: Text(
            last == null
                ? 'Chưa sao lưu lần nào. Tạo 1 file chứa toàn bộ dữ liệu để '
                      'cất lên Google Drive'
                : 'Lần cuối: ${_timeFormat.format(last)}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _backup,
        ),
        const Divider(height: 1),
        ListTile(
          key: const Key('settings_restore'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.settings_backup_restore_rounded),
          title: const Text('Khôi phục từ file sao lưu'),
          subtitle: const Text('Dùng khi đổi điện thoại hoặc cài lại app'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _busy ? null : _restore,
        ),
      ],
    );
  }
}
