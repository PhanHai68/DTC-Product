import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color, Offset;

import 'air_diagram.dart';

/// Xuất [AirDiagram] thành SVG (đường nét, chữ phóng to không vỡ). Ảnh thiết
/// bị nhúng thẳng vào file từ [images] (byte PNG theo asset).
String airDiagramSvg(
  AirDiagram diagram, {
  Map<String, Uint8List> images = const {},
}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'xmlns:xlink="http://www.w3.org/1999/xlink" width="${_n(diagram.width)}" '
      'height="${_n(diagram.height)}" viewBox="0 0 ${_n(diagram.width)} '
      '${_n(diagram.height)}" font-family="Roboto, Arial, sans-serif">',
    )
    ..writeln('<rect width="100%" height="100%" fill="#ffffff"/>');
  for (final shape in diagram.shapes) {
    switch (shape) {
      case DRect():
        final r = shape.rect;
        b.writeln(
          '<rect x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
          'height="${_n(r.height)}" rx="${_n(shape.radius)}" '
          '${_paint(shape.fill, shape.stroke, shape.strokeWidth, shape.dashed)}/>',
        );
      case DCircle():
        b.writeln(
          '<circle cx="${_n(shape.center.dx)}" cy="${_n(shape.center.dy)}" '
          'r="${_n(shape.radius)}" '
          '${_paint(shape.fill, shape.stroke, shape.strokeWidth, false)}/>',
        );
      case DPath():
        final tag = shape.closed ? 'polygon' : 'polyline';
        b.writeln(
          '<$tag points="${shape.points.map(_point).join(' ')}" '
          'stroke-linejoin="round" '
          '${_paint(shape.fill, shape.stroke, shape.strokeWidth, shape.dashed)}/>',
        );
      case DImage():
        final r = shape.rect;
        final bytes = images[shape.asset];
        if (bytes == null) continue;
        final href = 'data:image/png;base64,${base64Encode(bytes)}';
        b.writeln(
          '<image x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
          'height="${_n(r.height)}" preserveAspectRatio="none" '
          'href="$href" xlink:href="$href"/>',
        );
      case DText():
        final anchor = switch (shape.anchor) {
          DAnchor.start => 'start',
          DAnchor.middle => 'middle',
          DAnchor.end => 'end',
        };
        b.writeln(
          '<text x="${_n(shape.baseline.dx)}" y="${_n(shape.baseline.dy)}" '
          'font-size="${_n(shape.size)}" fill="${_hex(shape.color)}" '
          'text-anchor="$anchor"'
          '${shape.bold ? ' font-weight="bold"' : ''}>${_escape(shape.text)}</text>',
        );
    }
  }
  b.writeln('</svg>');
  return b.toString();
}

String _paint(Color? fill, Color? stroke, double width, bool dashed) => [
  'fill="${fill == null ? 'none' : _hex(fill)}"',
  if (stroke != null) ...[
    'stroke="${_hex(stroke)}"',
    'stroke-width="${_n(width)}"',
    if (dashed) 'stroke-dasharray="7 5"',
  ],
].join(' ');

String _point(Offset o) => '${_n(o.dx)},${_n(o.dy)}';

String _n(double v) {
  final s = v.toStringAsFixed(2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

String _hex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}';
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
