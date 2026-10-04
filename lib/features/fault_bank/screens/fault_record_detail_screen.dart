import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../theme/dtc_palette.dart';
import '../models/fault_record.dart';
import '../providers/fault_bank_provider.dart';
import '../services/fault_record_pdf_service.dart';
import '../utils/fault_duration.dart';
import '../widgets/fault_photo_thumb.dart';
import '../widgets/fault_record_card.dart';

/// Chi tiết 1 sự cố: mô tả lỗi, nguyên nhân, các bước xử lý, ảnh, vật tư,
/// dụng cụ, thời gian, người ghi. Sửa / xóa với bản ghi "của tôi".
class FaultRecordDetailScreen extends StatefulWidget {
  const FaultRecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  @override
  State<FaultRecordDetailScreen> createState() =>
      _FaultRecordDetailScreenState();
}

class _FaultRecordDetailScreenState extends State<FaultRecordDetailScreen> {
  FaultRecord? _record;
  bool _loading = true;
  bool _sharing = false;

  static final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await context.read<FaultBankProvider>().getRecord(
      widget.recordId,
    );
    if (!mounted) return;
    setState(() {
      _record = record;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    await context.push('/fault-bank/record/${widget.recordId}/edit');
    if (mounted) await _load();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: const Text('Bản ghi sẽ không còn hiện trong tra cứu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            key: const Key('fault_detail_confirm_delete'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<FaultBankProvider>().deleteRecord(widget.recordId);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    context.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Đã xóa bản ghi.')));
  }

  /// Tạo PDF hướng dẫn khắc phục (kèm ảnh) rồi mở bảng chia sẻ của máy.
  Future<void> _sharePdf(FaultRecord record, Rect? origin) async {
    if (_sharing) return;
    final messenger = ScaffoldMessenger.of(context);
    final storage = context.read<FaultBankProvider>().photoService.storage;
    setState(() => _sharing = true);
    try {
      final photoBytes = <String, Uint8List>{};
      final fileNames = [
        for (final step in record.steps)
          if (step.photo != null) step.photo!.fileName,
        for (final photo in record.photos) photo.fileName,
      ];
      for (final fileName in fileNames) {
        final bytes = await storage.readPhoto(fileName);
        if (bytes != null) photoBytes[fileName] = bytes;
      }
      final pdf = await FaultRecordPdfService.build(
        record,
        photoBytes: photoBytes,
      );
      final fileName = FaultRecordPdfService.fileName(record);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(pdf, mimeType: 'application/pdf', name: fileName),
          ],
          fileNameOverrides: [fileName],
          title: 'Cách khắc phục lỗi ${record.machineModelName}',
          subject: 'Cách khắc phục lỗi ${record.machineModelName}',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không tạo được file PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    return Scaffold(
      bottomNavigationBar: record == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    key: const Key('fault_detail_share_pdf'),
                    onPressed: _sharing
                        ? null
                        : () {
                            final box =
                                buttonContext.findRenderObject() as RenderBox?;
                            _sharePdf(
                              record,
                              box == null
                                  ? null
                                  : box.localToGlobal(Offset.zero) & box.size,
                            );
                          },
                    icon: _sharing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _sharing
                          ? 'Đang tạo PDF...'
                          : 'Chia sẻ cách khắc phục (PDF)',
                    ),
                  ),
                ),
              ),
            ),
      appBar: AppBar(
        title: const Text('Chi tiết lỗi'),
        actions: [
          if (record != null && record.isEditable) ...[
            IconButton(
              key: const Key('fault_detail_edit'),
              tooltip: 'Sửa',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
            IconButton(
              key: const Key('fault_detail_delete'),
              tooltip: 'Xóa',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : record == null
          ? const Center(child: Text('Bản ghi không còn tồn tại.'))
          : _buildBody(context, record),
    );
  }

  Widget _buildBody(BuildContext context, FaultRecord r) {
    final palette = DtcPalette.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Đầu trang: model máy + nhóm + tagname
        Text(
          r.machineModelName,
          style: TextStyle(
            color: palette.navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (r.faultGroup != null)
              FaultTag(text: r.faultGroup!, color: palette.navyLight),
            if (r.serialNumber != null)
              FaultTag(text: 'Tagname ${r.serialNumber}', color: palette.muted),
            if (!r.isEditable)
              FaultTag(
                text: 'Nhập vào · chỉ xem',
                color: Colors.orange.shade800,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Mô tả lỗi',
          icon: Icons.report_problem_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Body(r.symptom),
              if (r.photos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  key: const Key('fault_detail_symptom_photos'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final photo in r.photos)
                      FaultPhotoThumb(photo: photo, size: 96),
                  ],
                ),
              ],
            ],
          ),
        ),
        _Section(
          title: 'Nguyên nhân',
          icon: Icons.manage_search_rounded,
          child: _Body(r.cause),
        ),
        _Section(
          title: 'Cách xử lý',
          icon: Icons.build_outlined,
          child: Column(
            children: [for (final step in r.steps) _StepTile(step: step)],
          ),
        ),
        if (r.parts != null || r.tools != null || r.durationMinutes != null)
          _Section(
            title: 'Vật tư & thời gian',
            icon: Icons.inventory_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.parts != null) _InfoRow('Vật tư cần thay thế', r.parts!),
                if (r.tools != null) _InfoRow('Dụng cụ', r.tools!),
                if (r.durationMinutes != null)
                  _InfoRow(
                    'Thời gian xử lý',
                    FaultDuration.label(r.durationMinutes!),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Người ghi: ${r.authorName}\n'
          'Tạo ${_dateTime.format(r.createdAt)} · '
          'Cập nhật ${_dateTime.format(r.updatedAt)}',
          style: TextStyle(color: palette.muted, fontSize: 12.5, height: 1.5),
        ),
        const SizedBox(height: 4),
        SelectableText(
          'Mã bản ghi: ${r.id}',
          style: TextStyle(color: palette.muted, fontSize: 11),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: palette.cyan),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SelectableText(
    text,
    style: TextStyle(
      color: DtcPalette.of(context).ink,
      fontSize: 14.5,
      height: 1.45,
    ),
  );
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step});

  final SolutionStep step;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: palette.navy,
            child: Text(
              '${step.order}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _Body(step.content),
                ),
                if (step.photo != null) ...[
                  const SizedBox(height: 8),
                  FaultPhotoThumb(photo: step.photo!, size: 120),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: palette.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
