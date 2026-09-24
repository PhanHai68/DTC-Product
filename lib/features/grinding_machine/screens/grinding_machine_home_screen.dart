import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../providers/grinding_machine_provider.dart';

/// Màn hình chính module "Máy nghiền" — liệt kê các dòng máy (Series), có
/// thanh tìm kiếm nhanh đẩy sang [GrindingMachineSearchScreen].
class GrindingMachineHomeScreen extends StatefulWidget {
  const GrindingMachineHomeScreen({super.key});

  @override
  State<GrindingMachineHomeScreen> createState() =>
      _GrindingMachineHomeScreenState();
}

class _GrindingMachineHomeScreenState
    extends State<GrindingMachineHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<GrindingMachineProvider>().loadHome(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Máy nghiền'),
        actions: [
          IconButton(
            key: const Key('grinding_machine_update_button'),
            tooltip: 'Cập nhật database',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => context.push('/grinding_machine/database_update'),
          ),
          IconButton(
            key: const Key('grinding_machine_list_button'),
            tooltip: 'Danh sách máy nghiền',
            icon: const Icon(Icons.view_list_rounded),
            onPressed: () => context.push('/grinding_machine/list'),
          ),
          IconButton(
            key: const Key('grinding_machine_filter_button'),
            tooltip: 'Bộ lọc',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/grinding_machine/filter'),
          ),
          IconButton(
            key: const Key('grinding_machine_compare_button'),
            tooltip: 'So sánh model',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push('/grinding_machine/compare'),
          ),
          IconButton(
            key: const Key('grinding_machine_backup_button'),
            tooltip: 'Backup & Restore',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => context.push('/grinding_machine/backup'),
          ),
        ],
      ),
      body: Consumer<GrindingMachineProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.series.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.series.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SearchBar(
                onTap: () => context.push('/grinding_machine/search'),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                // Trỏ sang Machine Selector (Phase 6, minh bạch MATCH/
                // NOT_MATCH/UNKNOWN theo từng tiêu chí) — route Phase 4 cũ
                // vẫn còn (/grinding_machine/selection) để tránh regression,
                // chỉ không còn nút riêng trên Home để tránh 2 chức năng
                // chọn máy gần giống nhau.
                key: const Key('grinding_machine_selection_button'),
                onPressed: () => context.push('/grinding_machine/selector'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Chọn máy phù hợp'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('grinding_machine_projects_button'),
                      onPressed: () => context.push('/grinding_machine/projects'),
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('Saved Projects'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('grinding_machine_dashboard_button'),
                      onPressed: () => context.push('/grinding_machine/dashboard'),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('Dashboard'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: palette.cyan,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Dòng máy',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '${provider.series.length} dòng · ${provider.machines.length} model',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final series in provider.series)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SeriesCard(
                    seriesCode: series.seriesCode,
                    displayCode: series.displayCode,
                    nameVi: series.nameVi,
                    nameEn: series.nameEn,
                    machineCount: provider.machineCountOf(series.seriesCode),
                    onTap: () => context.push(
                      '/grinding_machine/series',
                      extra: series.seriesCode,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.border),
      ),
      child: InkWell(
        key: const Key('grinding_machine_search_bar'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: palette.cyan),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tìm theo model, dòng máy, nguyên liệu...',
                  style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({
    required this.seriesCode,
    required this.displayCode,
    required this.nameVi,
    required this.nameEn,
    required this.machineCount,
    required this.onTap,
  });

  final String seriesCode;
  final String displayCode;
  final String nameVi;
  final String nameEn;
  final int machineCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('grinding_series_card_$seriesCode'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.cyan.withValues(alpha: 0.14),
                      palette.cyan.withValues(alpha: 0.22),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  displayCode,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: palette.navy,
                    fontSize: displayCode.length > 4 ? 11 : 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nameVi,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nameEn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$machineCount model',
                      style: TextStyle(
                        color: palette.cyan,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.cyan),
            ],
          ),
        ),
      ),
    );
  }
}
