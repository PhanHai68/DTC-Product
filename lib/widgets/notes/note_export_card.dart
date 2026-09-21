import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';

/// Card hiển thị nội dung ghi chú theo phong cách chuyên nghiệp, dùng để
/// chụp lại thành ảnh PNG khi người dùng chọn "Xuất thành hình ảnh".
/// Giao diện cố định (không đổi theo theme sáng/tối) vì đây là nội dung sẽ
/// được chia sẻ ra ngoài app, cần hiển thị nhất quán trên mọi thiết bị.
class NoteExportCard extends StatelessWidget {
  const NoteExportCard({super.key, required this.note});

  final Note note;

  static const _navy = Color(0xFF0A2740);
  static const _green = Color(0xFF148147);
  static const _muted = Color(0xFF607786);
  static const _border = Color(0xFFDCE7EB);
  static const _canvas = Color(0xFFF3F7F9);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      width: 720,
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 34,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'DTC',
                      style: TextStyle(color: Color(0xFF138347)),
                    ),
                    TextSpan(
                      text: 'Product',
                      style: TextStyle(color: Color(0xFF72AD30)),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const Text(
                'GHI CHÚ',
                style: TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            note.title.trim().isEmpty ? '(Không có tiêu đề)' : note.title,
            style: const TextStyle(
              color: _navy,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _MetaRow(
                icon: Icons.calendar_today_rounded,
                text: 'Ngày tạo: ${dateFormat.format(note.createdAt)}',
              ),
              if (note.reminderEnabled && note.reminderDateTime != null)
                _MetaRow(
                  icon: Icons.notifications_active_rounded,
                  text:
                      'Nhắc hẹn: ${dateFormat.format(note.reminderDateTime!)}',
                  color: _green,
                ),
            ],
          ),
          if (note.content.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: _border),
            const SizedBox(height: 16),
            Text(
              note.content.trim(),
              style: const TextStyle(
                color: _navy,
                fontSize: 15.5,
                height: 1.55,
              ),
            ),
          ],
          if (note.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(height: 1, color: _border),
            const SizedBox(height: 16),
            const Text(
              'CHECKLIST',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ...note.checklistItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      item.isCompleted
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: item.isCompleted ? _green : _muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          color: item.isCompleted ? _muted : _navy,
                          fontSize: 14.5,
                          decoration: item.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              color: _canvas,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Text(
              'Created by DTC Product',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? NoteExportCard._muted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: resolvedColor),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: resolvedColor,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Chụp lại 1 widget đã gắn [RepaintBoundary] với [key] thành ảnh PNG.
Future<Uint8List?> captureWidgetAsPng(
  GlobalKey key, {
  double pixelRatio = 2.5,
}) async {
  final boundary =
      key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
