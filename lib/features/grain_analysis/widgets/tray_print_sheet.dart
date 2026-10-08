import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../engine/tray_layout.dart';
import '../services/tray_pdf_service.dart';

/// Chọn khổ + màu nền rồi sinh file PDF tấm nền khay chuẩn để in.
Future<void> showTrayPrintSheet(BuildContext context, TrayLayout initial) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TrayPrintSheet(initial: initial),
    );

class _TrayPrintSheet extends StatefulWidget {
  const _TrayPrintSheet({required this.initial});

  final TrayLayout initial;

  @override
  State<_TrayPrintSheet> createState() => _TrayPrintSheetState();
}

class _TrayPrintSheetState extends State<_TrayPrintSheet> {
  // Khay thật (không mốc) không có file in: mở với khổ A4.
  late TrayLayout _layout = widget.initial.hasMarkers
      ? widget.initial
      : TrayLayout.a4;
  TrayBackground _background = TrayBackground.navy;
  bool _busy = false;

  Future<void> _share(Rect? origin) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await TrayPdfService.build(
        _layout,
        background: _background,
      );
      final name = TrayPdfService.fileName(_layout, _background);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: name),
          ],
          fileNameOverrides: [name],
          title: 'Tấm nền khay chuẩn ${_layout.name}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không tạo được file PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'In tấm nền khay chuẩn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Tấm nền có 4 mốc đen ở góc để app nắn ảnh và đo kích thước hạt '
              'theo mm, cùng một ô trắng chuẩn để cân bằng màu.',
              style: TextStyle(color: palette.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Text(
              'Khổ giấy',
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'a4',
                  label: Text('A4 — mẫu 20 g hạt nhỏ'),
                ),
                ButtonSegment(value: 'a3', label: Text('A3 — hạt lớn')),
              ],
              selected: {_layout.id},
              onSelectionChanged: (s) =>
                  setState(() => _layout = TrayLayout.byId(s.first)),
            ),
            const SizedBox(height: 14),
            Text(
              'Màu nền',
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
            ),
            RadioGroup<TrayBackground>(
              groupValue: _background,
              onChanged: (v) => setState(() => _background = v!),
              child: Column(
                children: [
                  for (final b in TrayBackground.values)
                    RadioListTile<TrayBackground>(
                      value: b,
                      contentPadding: EdgeInsets.zero,
                      title: Text(b.label),
                      subtitle: Text(b.hint),
                      secondary: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Color.fromARGB(255, b.r, b.g, b.b),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: palette.border),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.cyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Khi in: chọn tỉ lệ 100% (Actual size), KHÔNG chọn "Vừa trang" '
                '(Fit to page). In xong, đo thước 80 mm ở mép dưới để kiểm tra. '
                'Giấy nên ép plastic mờ hoặc đặt dưới khay trong, tránh bóng loáng.',
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (buttonContext) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('grain_tray_pdf_share'),
                  onPressed: _busy
                      ? null
                      : () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          _share(
                            box == null
                                ? null
                                : box.localToGlobal(Offset.zero) & box.size,
                          );
                        },
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Tạo PDF & chia sẻ để in'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
