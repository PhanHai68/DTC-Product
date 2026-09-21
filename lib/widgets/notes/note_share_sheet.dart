import 'package:flutter/material.dart';

import '../../models/note.dart';
import '../../services/note_export_service.dart';
import '../../services/note_pdf_service.dart';
import 'note_export_card.dart';

/// Mở bottom sheet "Chia sẻ / Xuất" cho 1 ghi chú với 3 lựa chọn theo yêu
/// cầu: Chia sẻ dạng Text, Xuất thành hình ảnh, Xuất thành PDF.
Future<void> showNoteShareSheet(BuildContext context, Note note) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.text_snippet_outlined),
            title: const Text('Chia sẻ dạng Text'),
            subtitle: const Text('Gửi qua Zalo, Messenger, Email, SMS...'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await NoteExportService.shareText(note);
              } catch (_) {
                if (context.mounted) {
                  _showError(context, 'Không thể chia sẻ ghi chú.');
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('Xuất thành hình ảnh'),
            subtitle: const Text('Tạo ảnh đẹp để chia sẻ nhanh'),
            onTap: () {
              Navigator.pop(sheetContext);
              showNoteImageExportDialog(context, note);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Xuất thành PDF'),
            subtitle: const Text('Mở, lưu hoặc chia sẻ file PDF'),
            onTap: () {
              Navigator.pop(sheetContext);
              exportNotePdf(context, note);
            },
          ),
        ],
      ),
    ),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

void showNoteImageExportDialog(BuildContext context, Note note) {
  final boundaryKey = GlobalKey();
  var isSharing = false;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: NoteExportCard(note: note),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Đóng'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isSharing
                            ? null
                            : () async {
                                setState(() => isSharing = true);
                                try {
                                  final bytes = await captureWidgetAsPng(
                                    boundaryKey,
                                  );
                                  if (bytes == null) {
                                    throw StateError('Không thể tạo ảnh.');
                                  }
                                  await NoteExportService.shareBytes(
                                    bytes: bytes,
                                    fileName: NoteExportService.imageFileName(
                                      note,
                                    ),
                                    mimeType: 'image/png',
                                  );
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                } catch (_) {
                                  if (dialogContext.mounted) {
                                    _showError(
                                      dialogContext,
                                      'Không thể xuất hình ảnh. Vui lòng thử lại.',
                                    );
                                  }
                                } finally {
                                  setState(() => isSharing = false);
                                }
                              },
                        icon: isSharing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.share_rounded),
                        label: const Text('Chia sẻ'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

Future<void> exportNotePdf(BuildContext context, Note note) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final bytes = await NotePdfService.build(note);
    if (!context.mounted) return;
    Navigator.pop(context); // đóng loading
    _showPdfActionsSheet(context, note, bytes);
  } catch (_) {
    if (context.mounted) {
      Navigator.pop(context);
      _showError(context, 'Không thể tạo file PDF. Vui lòng thử lại.');
    }
  }
}

void _showPdfActionsSheet(BuildContext context, Note note, List<int> bytes) {
  final fileName = NoteExportService.pdfFileName(note);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: const Text('Mở file'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await NoteExportService.openFile(
                  bytes: bytes,
                  fileName: fileName,
                );
              } catch (_) {
                if (context.mounted) {
                  _showError(context, 'Không thể mở file PDF.');
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Lưu file'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await NoteExportService.saveFile(
                  bytes: bytes,
                  fileName: fileName,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã lưu file: $fileName')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  _showError(context, 'Không thể lưu file PDF.');
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Chia sẻ file'),
            onTap: () async {
              Navigator.pop(sheetContext);
              try {
                await NoteExportService.shareBytes(
                  bytes: bytes,
                  fileName: fileName,
                  mimeType: 'application/pdf',
                );
              } catch (_) {
                if (context.mounted) {
                  _showError(context, 'Không thể chia sẻ file PDF.');
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}
