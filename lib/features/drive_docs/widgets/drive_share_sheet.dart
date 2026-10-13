import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';

/// Nút chia sẻ một file trong thư viện tài liệu (danh sách và màn hình xem).
class DriveShareButton extends StatelessWidget {
  const DriveShareButton({super.key, this.item, this.pdfName, this.color})
    : assert(item != null || pdfName != null);

  final DriveItem? item;

  /// PDF mở theo tên file (tài liệu cố định): tìm trên Drive khi bấm.
  final String? pdfName;
  final Color? color;

  Future<void> _onPressed(BuildContext context) async {
    var target = item;
    if (target == null) {
      try {
        target = await DriveDocsService.instance.findPdfByName(pdfName!);
      } on Object catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              error is DriveDocsException
                  ? error.message
                  : 'Không tìm thấy tài liệu để chia sẻ.',
            ),
          ),
        );
        return;
      }
    }
    if (!context.mounted) return;
    await showDriveShareSheet(context, target);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share_rounded),
      color: color,
      tooltip: 'Chia sẻ',
      onPressed: () => _onPressed(context),
    );
  }
}

/// Chọn gửi nguyên file hay đường link Google Drive, rồi mở bảng chia sẻ của
/// máy (Zalo, Messenger, Email...). [context] là của nút bấm, dùng làm điểm
/// neo bảng chia sẻ trên iPad.
Future<void> showDriveShareSheet(BuildContext context, DriveItem item) {
  final origin = _originOf(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(sheetContext).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            key: const Key('drive_share_file'),
            leading: const Icon(Icons.attach_file_rounded),
            title: const Text('Gửi file'),
            subtitle: Text(_fileOptionHint(item)),
            enabled: item.canShareAsFile,
            onTap: () {
              Navigator.of(sheetContext).pop();
              _shareFile(context, item, origin);
            },
          ),
          ListTile(
            key: const Key('drive_share_link'),
            leading: const Icon(Icons.link_rounded),
            title: const Text('Gửi đường link Google Drive'),
            subtitle: const Text(
              'Gửi ngay, người nhận bấm link để xem hoặc tải về',
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();
              // Gọi chia sẻ ngay trong lần bấm: trình duyệt chặn bảng chia sẻ
              // nếu mở sau một lần chờ.
              _shareLink(context, item, origin);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

String _fileOptionHint(DriveItem item) {
  if (item.isGoogleNative) {
    return 'File Google Docs/Sheets chỉ gửi được đường link';
  }
  if (!item.canShareAsFile) {
    return 'File lớn hơn ${DriveItem.maxShareFileBytes ~/ (1024 * 1024)} MB, '
        'hãy gửi đường link';
  }
  final size = item.size;
  final sizeText = size == null ? '' : ' (${_formatSize(size)})';
  return 'Gửi nguyên file$sizeText qua Zalo, Messenger, Email...';
}

String _formatSize(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).ceil()} KB';

Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return null;
}

Future<void> _shareLink(
  BuildContext context,
  DriveItem item,
  Rect? origin,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final link = item.driveViewUri.toString();
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: '${item.name}\n$link',
        subject: item.name,
        sharePositionOrigin: origin,
      ),
    );
  } on Object catch (error) {
    debugPrint('DriveDocs: không mở được bảng chia sẻ link: $error');
    await Clipboard.setData(ClipboardData(text: link));
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Không mở được bảng chia sẻ. Đã sao chép đường link.'),
      ),
    );
  }
}

Future<void> _shareFile(
  BuildContext context,
  DriveItem item,
  Rect? origin,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  var cancelled = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text('Đang tải "${item.name}"...')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            cancelled = true;
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Hủy'),
        ),
      ],
    ),
  );

  final Uint8List bytes;
  try {
    // PDF/ảnh lưu bộ đệm để lần sau xem offline; video thì không.
    bytes = await DriveDocsService.instance.loadFile(
      item,
      cache: item.isPdf || item.isImage,
    );
  } on Object catch (error) {
    if (cancelled) return;
    navigator.pop();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          error is DriveDocsException
              ? error.message
              : 'Không tải được file để chia sẻ. Vui lòng thử lại.',
        ),
      ),
    );
    return;
  }
  if (cancelled) return;
  navigator.pop();

  if (!kIsWeb) {
    await _openFileShareSheet(bytes, item, origin, messenger);
    return;
  }
  // Web: trình duyệt (nhất là Safari trên iPhone) chỉ mở bảng chia sẻ ngay
  // sau một lần bấm, nên cần người dùng bấm "Chia sẻ" sau khi tải xong.
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Đã tải xong'),
      content: Text('Bấm "Chia sẻ" để gửi "${item.name}".'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _openFileShareSheet(bytes, item, origin, messenger);
          },
          icon: const Icon(Icons.share_rounded),
          label: const Text('Chia sẻ'),
        ),
      ],
    ),
  );
}

Future<void> _openFileShareSheet(
  Uint8List bytes,
  DriveItem item,
  Rect? origin,
  ScaffoldMessengerState? messenger,
) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: item.mimeType, name: item.name),
        ],
        fileNameOverrides: [item.name],
        sharePositionOrigin: origin,
      ),
    );
  } on Object catch (error) {
    debugPrint('DriveDocs: không chia sẻ được file ${item.name}: $error');
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Thiết bị không gửi được file này. Hãy thử "Gửi đường link".',
        ),
      ),
    );
  }
}
