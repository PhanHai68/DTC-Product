import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../equipment_catalog_config.dart';
import '../providers/equipment_catalog_provider.dart';

/// Trang chính 1 catalog thiết bị — cùng bố cục trang chính máy nghiền: thanh
/// tìm kiếm, nút chọn máy, nút so sánh và danh sách dòng máy.
class EquipmentHomeScreen extends StatefulWidget {
  const EquipmentHomeScreen({super.key, required this.config});

  final EquipmentCatalogConfig config;

  @override
  State<EquipmentHomeScreen> createState() => _EquipmentHomeScreenState();
}

class _EquipmentHomeScreenState extends State<EquipmentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<EquipmentCatalogProvider>().load(widget.config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final palette = DtcPalette.of(context);
    final provider = context.watch<EquipmentCatalogProvider>();
    final catalog = provider.catalog(config);
    final error = provider.error(config);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: Text(config.title),
        actions: [
          IconButton(
            key: Key('${config.id}_machine_compare_button'),
            tooltip: 'So sánh model',
            icon: const Icon(Icons.compare_arrows_rounded),
            onPressed: () => context.push('${config.routeBase}/compare'),
          ),
        ],
      ),
      body: catalog == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        error,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.muted),
                      ),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _SearchBar(
                  key: Key('${config.id}_machine_search_bar'),
                  onTap: () => context.push('${config.routeBase}/search'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: Key('${config.id}_machine_selector_button'),
                  onPressed: () => context.push('${config.routeBase}/selector'),
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
                        '${catalog.series.length} dòng · '
                        '${catalog.machines.length} model',
                        key: Key('${config.id}_machine_counts'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: palette.muted, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final (i, series) in catalog.series.indexed) ...[
                  if (series.groupVi.isNotEmpty &&
                      (i == 0 ||
                          catalog.series[i - 1].groupVi != series.groupVi))
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 8),
                      child: Text(
                        series.groupVi.toUpperCase(),
                        key: Key('${config.id}_group_${series.groupVi}'),
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EquipmentSeriesCard(
                      key: Key('${config.id}_series_card_${series.seriesCode}'),
                      displayCode: series.displayCode,
                      nameVi: series.nameVi,
                      subtitle: series.nameEn,
                      machineCount: catalog.machineCountOf(series.seriesCode),
                      onTap: () => context.push(
                        Uri(
                          path: '${config.routeBase}/series',
                          queryParameters: {'code': series.seriesCode},
                        ).toString(),
                        extra: series.seriesCode,
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({super.key, required this.onTap});

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
class EquipmentSeriesCard extends StatelessWidget {
  const EquipmentSeriesCard({
    super.key,
    required this.displayCode,
    required this.nameVi,
    required this.subtitle,
    required this.machineCount,
    required this.onTap,
  });

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
