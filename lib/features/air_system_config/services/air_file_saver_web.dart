import 'dart:js_interop';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

import 'air_config_export_service.dart';

/// Web: tải file về máy.
Future<void> deliverAirExport(AirExportFile file, {Rect? origin}) async {
  final blob = web.Blob(
    <JSUint8Array>[file.bytes.toJS].toJS,
    web.BlobPropertyBag(type: file.mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = file.name
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
