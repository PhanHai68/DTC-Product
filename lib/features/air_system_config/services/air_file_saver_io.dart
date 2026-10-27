import 'dart:ui' show Rect;

import 'package:share_plus/share_plus.dart';

import 'air_config_export_service.dart';

/// Điện thoại/máy tính: mở bảng chia sẻ để lưu hoặc gửi file.
Future<void> deliverAirExport(AirExportFile file, {Rect? origin}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(file.bytes, mimeType: file.mimeType, name: file.name),
      ],
      fileNameOverrides: [file.name],
      subject: file.name,
      sharePositionOrigin: origin,
    ),
  );
}
