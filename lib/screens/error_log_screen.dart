import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../core/errors/app_error_log.dart';

/// Cài đặt → Nhật ký lỗi: xem, sao chép, chia sẻ lỗi đã ghi nhận trên máy để
/// gửi cho DTC (bản phát hành APK không có báo cáo crash tự động).
class ErrorLogScreen extends StatelessWidget {
  const ErrorLogScreen({super.key});

  AppErrorLog get log => AppErrorLog.instance;

  Future<String> _exportText() async {
    String? version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version} (build ${info.buildNumber})';
    } catch (_) {}
    return log.exportText(appVersion: version);
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: await _exportText()));
    messenger.showSnackBar(
      const SnackBar(content: Text('Đã sao chép nhật ký lỗi.')),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: await _exportText(),
        subject: 'Nhật ký lỗi DTC Product',
      ),
    );
  }

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa nhật ký lỗi?'),
        content: const Text('Các lỗi đã ghi nhận trên máy này sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await log.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: log,
      builder: (context, _) {
        final entries = log.entries;
        final timeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
        return Scaffold(
          appBar: AppBar(
            title: const Text('Nhật ký lỗi'),
            actions: [
              if (entries.isNotEmpty) ...[
                IconButton(
                  tooltip: 'Sao chép',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () => _copy(context),
                ),
                IconButton(
                  tooltip: 'Chia sẻ',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _share,
                ),
                IconButton(
                  tooltip: 'Xóa nhật ký',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _clear(context),
                ),
              ],
            ],
          ),
          body: entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa ghi nhận lỗi nào trên máy này.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        'Khi app gặp lỗi, hãy bấm Chia sẻ (hoặc Sao chép) và '
                        'gửi nội dung này cho DTC để được hỗ trợ.',
                        style: Theme.of(context).textTheme.bodySmall,
                      );
                    }
                    final entry = entries[index - 1];
                    return Card(
                      child: ExpansionTile(
                        leading: Icon(
                          entry.source == 'async'
                              ? Icons.sync_problem_rounded
                              : Icons.error_outline_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          entry.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(timeFormat.format(entry.time)),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            '${entry.message}\n\n${entry.stack}',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
