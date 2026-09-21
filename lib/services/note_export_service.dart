import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';

import '../models/note.dart';
import 'note_file_storage.dart'
    if (dart.library.io) 'note_file_storage_io.dart'
    if (dart.library.js_interop) 'note_file_storage_web.dart';

/// Gom các thao tác Chia sẻ / Xuất cho chức năng "Ghi chú & Nhắc hẹn":
/// chia sẻ text, và Mở/Lưu/Chia sẻ cho file PDF hoặc hình ảnh đã xuất.
abstract final class NoteExportService {
  /// Nội dung text để chia sẻ qua Zalo/Messenger/Email/SMS...
  static String buildShareText(Note note) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final buffer = StringBuffer()
      ..writeln(note.title.trim().isEmpty ? 'Ghi chú' : note.title.trim())
      ..writeln()
      ..writeln('Ngày tạo: ${dateFormat.format(note.createdAt)}');

    if (note.content.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Nội dung:')
        ..writeln(note.content.trim());
    }

    if (note.checklistItems.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Checklist:');
      for (final item in note.checklistItems) {
        buffer.writeln('${item.isCompleted ? '☑' : '☐'} ${item.text}');
      }
    }

    if (note.reminderEnabled && note.reminderDateTime != null) {
      final reminderFormat = DateFormat("dd/MM/yyyy 'lúc' HH:mm");
      buffer
        ..writeln()
        ..writeln('Nhắc hẹn: ${reminderFormat.format(note.reminderDateTime!)}');
    }

    return buffer.toString().trimRight();
  }

  static Future<void> shareText(Note note) {
    return SharePlus.instance.share(
      ShareParams(text: buildShareText(note), subject: note.title),
    );
  }

  static String _fileBaseName(Note note) {
    final safeTitle = (note.title.trim().isEmpty ? 'Ghi chú' : note.title)
        // Chỉ loại các ký tự không hợp lệ trong tên file, giữ nguyên dấu
        // tiếng Việt và khoảng trắng để tên file dễ đọc.
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    return 'DTC ${safeTitle.isEmpty ? 'Ghi chú' : safeTitle}';
  }

  static String pdfFileName(Note note) => '${_fileBaseName(note)}.pdf';
  static String imageFileName(Note note) => '${_fileBaseName(note)}.png';

  static Future<void> shareBytes({
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    String? text,
  }) async {
    final XFile file;
    if (kIsWeb) {
      file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: mimeType,
        name: fileName,
      );
    } else {
      // XFile.fromData() ghi ra file tạm với tên ngẫu nhiên trên Android nên
      // ứng dụng nhận (Zalo, Messenger...) hiển thị sai tên file khi chia
      // sẻ — ghi thẳng ra file có đúng tên mong muốn rồi mới chia sẻ.
      final path = await cacheNoteFileForOpen(
        bytes: bytes,
        fileName: fileName,
      );
      file = XFile(path, mimeType: mimeType, name: fileName);
    }
    await SharePlus.instance.share(ShareParams(files: [file], text: text));
  }

  /// Lưu file vào bộ nhớ ứng dụng, trả về đường dẫn đã lưu (rỗng trên web vì
  /// trình duyệt tự tải xuống thay vì trả về đường dẫn cục bộ).
  static Future<String> saveFile({
    required List<int> bytes,
    required String fileName,
  }) {
    return saveNoteFile(bytes: bytes, fileName: fileName);
  }

  /// Mở file bằng ứng dụng khác trên máy (PDF viewer, trình xem ảnh...).
  static Future<void> openFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final path = await cacheNoteFileForOpen(bytes: bytes, fileName: fileName);
    if (kIsWeb) {
      // Trên web, cacheNoteFileForOpen đã tự tải file xuống trình duyệt rồi.
      return;
    }
    await OpenFile.open(path);
  }
}
