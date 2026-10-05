import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../providers/packing_machine_provider.dart';

/// Trang chính "Máy đóng gói" — cùng bố cục trang chính máy nghiền: thanh tìm
/// kiếm, nút so sánh và danh sách dòng máy.
class PackingMachineHomeScreen extends StatefulWidget {
  const PackingMachineHomeScreen({super.key});

  @override
  State<PackingMachineHomeScreen> createState() =>
      _PackingMachineHomeScreenState();
}

class _PackingMachineHomeScreenState extends State<PackingMachineHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<PackingMachineProvider>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: const Text('Máy đóng gói'),
        actions: [
          IconButton(
            key: const Key('packing_machine_compare_button'),
            tooltip: 'So sánh model',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push('/packing_machine/compare'),
          ),
        ],
      ),
      body: Consumer<PackingMachineProvider>(
        builder: (context, provider, _) {
          if (!provider.isLoaded && provider.error == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
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
              _SearchBar(onTap: () => context.push('/packing_machine/search')),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('packing_machine_selector_button'),
                onPressed: () => context.push('/packing_machine/selector'),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Chọn máy phù hợp'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
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
                      key: const Key('packing_machine_counts'),
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
                  child: PackingSeriesCard(
                    seriesCode: series.seriesCode,
                    displayCode: series.displayCode,
                    nameVi: series.nameVi,
                    subtitle: series.nameEn,
                    machineCount: provider.machineCountOf(series.seriesCode),
                    onTap: () => context.push(
                      '/packing_machine/series',
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
        key: const Key('packing_machine_search_bar'),
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
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ 1 dòng máy — cùng kiểu thẻ dòng máy nghiền.
class PackingSeriesCard extends StatelessWidget {
  const PackingSeriesCard({
    super.key,
    required this.seriesCode,
    required this.displayCode,
    required this.nameVi,
    required this.subtitle,
    required this.machineCount,
    required this.onTap,
  });

  final String seriesCode;
  final String displayCode;
  final String nameVi;
  final String subtitle;
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
        key: Key('packing_series_card_$seriesCode'),
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
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  displayCode,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: palette.navy,
                    fontSize: displayCode.length > 4 ? 10.5 : 13,
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
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.muted, fontSize: 12.5),
                      ),
                    ],
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
