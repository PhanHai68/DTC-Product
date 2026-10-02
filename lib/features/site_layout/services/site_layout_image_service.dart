import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/site_layout_models.dart';
import 'layout_geometry_service.dart';
import '../widgets/layout_canvas.dart';

enum SiteLayoutRenderProfile { screen, pdf }

abstract final class SiteLayoutImageService {
  static Future<Uint8List> buildPng(
    SiteLayoutBundle bundle, {
    bool showGrid = true,
    bool showClearance = true,
    bool showMeasurements = true,
    bool showNotes = true,
    SiteLayoutRenderProfile renderProfile = SiteLayoutRenderProfile.screen,
  }) async {
    final isPdf = renderProfile == SiteLayoutRenderProfile.pdf;
    final renderScale = isPdf ? 4.0 : 2.0;
    final padding = isPdf ? 80.0 : 48.0;
    final maxDimension = math.max(
      bundle.project.siteWidthMm,
      bundle.project.siteLengthMm,
    );
    final maxPixels = isPdf ? 3200.0 : 2600.0;
    final pixelsPerMm = (maxPixels / math.max(1, maxDimension)).clamp(
      0.03,
      isPdf ? 1.2 : 0.6,
    );
    final contentSize = Size(
      bundle.project.siteWidthMm * pixelsPerMm,
      bundle.project.siteLengthMm * pixelsPerMm,
    );
    final outputSize = Size(
      contentSize.width + padding * 2,
      contentSize.height + padding * 2,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & outputSize, Paint()..color = Colors.white);
    canvas.save();
    canvas.translate(padding, padding);
    final exportBundle = bundle.copyWith(
      measurements: showMeasurements ? bundle.measurements : const [],
      annotations: showNotes ? bundle.annotations : const [],
      photoMarkers: showNotes ? bundle.photoMarkers : const [],
    );
    SiteLayoutPainter(
      bundle: exportBundle,
      pixelsPerMm: pixelsPerMm,
      gridMm: showGrid ? 500 : maxDimension * 2,
      selectedId: null,
      showClearance: showClearance,
      warningIds: LayoutGeometryService.validate(bundle)
          .map((warning) => warning.subjectId)
          .whereType<String>()
          .toSet(),
      forExport: true,
      renderScale: renderScale,
    ).paint(canvas, contentSize);
    canvas.restore();
    final title = TextPainter(
      text: TextSpan(
        text: '${bundle.project.name} · ${bundle.layout.name}',
        style: TextStyle(
          color: const Color(0xFF0A2740),
          fontSize: isPdf ? 12 * renderScale : 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: outputSize.width - 32);
    title.paint(
      canvas,
      Offset(isPdf ? 16 * renderScale : 16, isPdf ? 4 * renderScale : 12),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      outputSize.width.ceil(),
      outputSize.height.ceil(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Không thể dựng ảnh mặt bằng.');
    return data.buffer.asUint8List();
  }
}
