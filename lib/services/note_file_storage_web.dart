import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

String _downloadBlob(List<int> bytes, String fileName, String mimeType) {
  final data = Uint8List.fromList(bytes);
  final blob = web.Blob(
    <JSUint8Array>[data.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}

Future<String> saveNoteFile({
  required List<int> bytes,
  required String fileName,
}) async {
  final mimeType = fileName.endsWith('.pdf') ? 'application/pdf' : 'image/png';
  return _downloadBlob(bytes, fileName, mimeType);
}

Future<String> cacheNoteFileForOpen({
  required List<int> bytes,
  required String fileName,
}) async {
  // Trên web, "Mở file" và "Lưu file" là cùng một hành động tải xuống.
  return saveNoteFile(bytes: bytes, fileName: fileName);
}
