import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/analysis_session.dart';
import '../models/grain.dart';
import '../providers/grain_analysis_provider.dart';
import '../utils/grain_format.dart';
import '../widgets/tray_print_sheet.dart';

/// Màn chính Phân tích mẫu AI: bắt đầu phân tích + lịch sử phiên.
class GrainAnalysisHomeScreen extends StatelessWidget {
  const GrainAnalysisHomeScreen({super.key});

  static const title = 'Phân tích mẫu AI';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GrainAnalysisProvider>();
    final palette = DtcPalette.of(context);

    if (!provider.isSupported) {
      return const _Message(
        icon: Icons.phone_android_rounded,
        text:
            'Phân tích mẫu AI chỉ dùng trên ứng dụng Android/iOS vì cần chụp '
            'ảnh và xử lý ảnh độ phân giải cao.',
      );
    }
    if (provider.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.error != null) {
      return _Message(icon: Icons.error_outline_rounded, text: provider.error!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(title),
        actions: [
          IconButton(
            key: const Key('grain_print_tray'),
            tooltip: 'In tấm nền khay chuẩn',
            icon: const Icon(Icons.print_outlined),
            onPressed: () => showTrayPrintSheet(context, provider.tray),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _ActionCard(
              key: const Key('grain_new_count'),
              icon: Icons.grain_rounded,
              title: 'Đếm hạt',
              subtitle:
                  'Rải mẫu một lớp trên khay chuẩn, chụp một ảnh — app tự đếm '
                  'số hạt.',
              onTap: () => context.push('/grain-analysis/new?mode=count'),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              key: const Key('grain_new_quick'),
              icon: Icons.donut_large_rounded,
              title: 'Đếm nhanh nhóm hạt',
              subtitle:
                  'Chụp cả mẫu, rồi chụp riêng nhóm hạt đã tách tay — app tính '
                  '% số hạt và % diện tích của nhóm.',
              onTap: () => context.push('/grain-analysis/new?mode=quick'),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: palette.cyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: palette.navyLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chụp trên tấm nền khay chuẩn có 4 mốc đen, hoặc khay '
                      'AnySort 21×15 cm (gạo trắng dùng khay đen), để có số '
                      'đo mm và kết quả chính xác nhất.',
                      style: TextStyle(color: palette.ink, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showTrayPrintSheet(context, provider.tray),
                    child: const Text('In tấm nền'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Lịch sử phân tích (${provider.sessions.length})',
              style: TextStyle(
                color: palette.navy,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            if (provider.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Chưa có phiên phân tích nào.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              )
            else
              for (final s in provider.sessions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SessionTile(summary: s),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: palette.navy, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.summary});

  final AnalysisSessionSummary summary;

  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final s = summary;
    final String headline;
    if (s.mode == AnalysisMode.quick) {
      final group = s.resultOf(ClassResult.groupId);
      final rest = s.resultOf(ClassResult.restId);
      final whole = (group?.grainCount ?? 0) + (rest?.grainCount ?? 0);
      headline = group == null
          ? 'Đếm nhanh'
          : 'Nhóm ${GrainFormat.count(group.grainCount)}/'
                '${GrainFormat.count(whole)} hạt · '
                '${GrainFormat.percent(group.countPercent)}';
    } else {
      final all = s.resultOf(ClassResult.allId);
      headline = '${GrainFormat.count(all?.grainCount ?? 0)} hạt';
    }
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grain_session_${s.id}'),
        onTap: () => context.push('/grain-analysis/session/${s.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Icon(
                s.mode == AnalysisMode.quick
                    ? Icons.donut_large_rounded
                    : Icons.grain_rounded,
                color: palette.navyLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        color: palette.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (s.lotCode != null) 'Lô ${s.lotCode}',
                        s.sampleType.label,
                        _date.format(s.createdAt),
                      ].join(' · '),
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Tag(
                    text: s.status.label,
                    color: s.status == SessionStatus.confirmed
                        ? const Color(0xFF148147)
                        : palette.muted,
                  ),
                  if (s.poorQuality) ...[
                    const SizedBox(height: 4),
                    const _Tag(text: 'Ảnh kém', color: Color(0xFFC0392B)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(GrainAnalysisHomeScreen.title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: DtcPalette.of(context).muted),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}
