/// Màn hình chi tiết máy cân đóng gói.
/// Hiển thị image gallery, tất cả thông số kỹ thuật, và nút XEM CATALOG.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../data/packing_feature_data.dart';
import '../../models/packing_machine.dart';
import '../../providers/compare_provider.dart';
import '../../repositories/packing_machine_repository.dart';
import '../../widgets/packing/spec_row.dart';
import '../../widgets/packing/machine_card.dart';
import '../../widgets/packing/packing_back_button.dart';

class MachineDetailScreen extends StatefulWidget {
  final String modelName;
  final bool showCatalog;
  final PackingMachineRepository? repository;

  const MachineDetailScreen({
    super.key,
    required this.modelName,
    this.showCatalog = true,
    this.repository,
  });

  @override
  State<MachineDetailScreen> createState() => _MachineDetailScreenState();
}

class _MachineDetailScreenState extends State<MachineDetailScreen> {
  late final PackingMachineRepository _repository;
  PackingMachine? _machine;
  bool _isLoading = true;
  String? _error;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? PackingMachineRepository();
    _loadMachine();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMachine() async {
    try {
      final machine = await _repository.getMachineByModel(widget.modelName);
      if (mounted) {
        setState(() {
          _machine = machine;
          _isLoading = false;
          if (machine == null)
            _error = 'Không tìm thấy model ${widget.modelName}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi tải dữ liệu: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _openCatalog(PackingMachine machine) {
    if (!machine.hasCatalog) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có catalog cho model này')),
      );
      return;
    }
    context.push(
      '/packing_catalog_viewer',
      extra: {
        'path': machine.catalogAssetPath!,
        'page': machine.catalogPage ?? 1,
        'model': machine.model,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null || _machine == null) {
      return Scaffold(
        appBar: AppBar(leading: const PackingBackButton()),
        body: Center(child: Text(_error ?? 'Không tìm thấy máy')),
      );
    }

    final machine = _machine!;
    final colorScheme = Theme.of(context).colorScheme;
    final images = machine.detailImagePaths;
    final features = packingFeaturesFor(machine);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar với Image ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: images.isNotEmpty ? 300 : 200,
            pinned: true,
            backgroundColor: colorScheme.surface,
            leadingWidth: 64,
            leading: PackingBackButton(
              foregroundColor: colorScheme.primary,
              backgroundColor: colorScheme.surface.withValues(alpha: 0.88),
            ),
            actions: [
              // Compare button
              Consumer<CompareProvider>(
                builder: (context, compareProvider, _) {
                  final isSelected = compareProvider.isSelected(machine.model);
                  return IconButton(
                    icon: Icon(
                      isSelected
                          ? Icons.compare_arrows
                          : Icons.compare_arrows_outlined,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    tooltip: isSelected
                        ? 'Bỏ khỏi so sánh'
                        : 'Thêm vào so sánh',
                    onPressed: () {
                      if (isSelected) {
                        compareProvider.removeMachine(machine.model);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã xóa khỏi danh sách so sánh'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else if (!compareProvider.isFull) {
                        compareProvider.addMachineObject(machine);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã thêm ${machine.model} vào so sánh',
                            ),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'Xem',
                              onPressed: () => context.push('/machine_compare'),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã chọn tối đa 3 model'),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: images.isNotEmpty
                  ? _ImageGallery(
                      images: images,
                      currentIndex: _currentImageIndex,
                      pageController: _pageController,
                      onPageChanged: (i) =>
                          setState(() => _currentImageIndex = i),
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.precision_manufacturing_outlined,
                          size: 80,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model name + group
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              machine.model,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (machine.productGroup != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  machine.productGroup!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (machine.machineLine != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                machine.machineLine!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Automation badge
                      if (machine.automationLevel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                machine.automationLevel!.contains('Hoàn toàn')
                                ? Colors.green.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  machine.automationLevel!.contains('Hoàn toàn')
                                  ? Colors.green.shade200
                                  : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            machine.automationLevel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  machine.automationLevel!.contains('Hoàn toàn')
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  if (features.isNotEmpty) ...[
                    _FeatureSection(features: features),
                    const SizedBox(height: 8),
                  ],

                  // ── Thông số đóng gói ─────────────────────────────────
                  const SpecSectionHeader(title: 'Đóng gói'),
                  if (machine.bagMaterial != null)
                    SpecRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Loại bao',
                      value: machine.bagMaterial!,
                    ),
                  if (machine.bagEdges != null)
                    SpecRow(
                      icon: Icons.layers_outlined,
                      label: 'Kiểu túi',
                      value: machine.bagEdges!,
                    ),
                  if (machine.bagShape != null)
                    SpecRow(
                      icon: Icons.crop_square_outlined,
                      label: 'Hình dạng túi',
                      value: machine.bagShape!,
                    ),
                  if (machine.materials != null)
                    SpecRow(
                      icon: Icons.grain_outlined,
                      label: 'Nguyên liệu',
                      value: machine.materials!,
                    ),

                  // ── Thông số trọng lượng & năng suất ─────────────────
                  const SpecSectionHeader(title: 'Hiệu suất'),
                  SpecRow(
                    icon: Icons.scale_outlined,
                    label: 'Trọng lượng/túi',
                    value: machine.weightRangeText,
                  ),
                  SpecRow(
                    icon: Icons.speed_outlined,
                    label: 'Năng suất',
                    value: machine.capacityRangeText,
                  ),
                  if (machine.headsStations != null &&
                      machine.headsStations != '-')
                    SpecRow(
                      icon: Icons.hub_outlined,
                      label: 'Số đầu cân / trạm',
                      value: machine.headsStations!,
                    ),

                  // ── Thông số điện ─────────────────────────────────────
                  const SpecSectionHeader(title: 'Điện - Khí'),
                  SpecRow(
                    icon: Icons.electrical_services_outlined,
                    label: 'Nguồn điện',
                    value: machine.powerText,
                  ),
                  if (machine.powerKw != null)
                    SpecRow(
                      icon: Icons.bolt_outlined,
                      label: 'Công suất',
                      value: '${machine.powerKw} kW',
                    ),
                  SpecRow(
                    icon: Icons.compress_outlined,
                    label: 'Áp suất khí nén',
                    value: machine.airPressureText,
                  ),
                  if (machine.airConsumptionM3h != null)
                    SpecRow(
                      icon: Icons.air_outlined,
                      label: 'Lưu lượng khí',
                      value: '${machine.airConsumptionM3h} m³/h',
                    ),

                  // ── Kích thước ───────────────────────────────────────
                  const SpecSectionHeader(title: 'Kích thước'),
                  SpecRow(
                    icon: Icons.straighten_outlined,
                    label: 'Kích thước máy',
                    value: machine.dimensionText,
                  ),

                  // ── Ghi chú ─────────────────────────────────────────
                  if (machine.notes != null && machine.notes!.isNotEmpty) ...[
                    const SpecSectionHeader(title: 'Ghi chú'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        machine.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Catalog Button ───────────────────────────────────
                  if (widget.showCatalog && machine.hasCatalog)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openCatalog(machine),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text(
                          'XEM CATALOG',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureSection extends StatelessWidget {
  final List<PackingFeature> features;

  const _FeatureSection({required this.features});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF16834A);

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: accent, size: 22),
              SizedBox(width: 8),
              Text(
                'Đặc điểm nổi bật',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm vào từng đặc điểm để xem nội dung chi tiết',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 720 ? 3 : 2;
              const spacing = 10.0;
              final itemWidth =
                  (constraints.maxWidth - spacing * (columnCount - 1)) /
                  columnCount;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: features
                    .map(
                      (feature) => SizedBox(
                        width: itemWidth,
                        child: _FeatureCard(feature: feature),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final PackingFeature feature;

  const _FeatureCard({required this.feature});

  void _showDetail(BuildContext context) {
    const accent = Color(0xFF16834A);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7EF),
            shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Icon(feature.icon, color: accent, size: 30),
        ),
        title: Text(
          feature.title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Text(
            feature.detail,
            textAlign: TextAlign.left,
            style: const TextStyle(fontSize: 15, height: 1.45),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF16834A);

    return Material(
      color: const Color(0xFFF7FCF9),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: accent.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4F4EA),
                  shape: BoxShape.circle,
                ),
                child: Icon(feature.icon, color: accent, size: 21),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  feature.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, color: accent, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget image gallery với PageView
class _ImageGallery extends StatelessWidget {
  final List<String> images;
  final int currentIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;

  const _ImageGallery({
    required this.images,
    required this.currentIndex,
    required this.pageController,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: pageController,
          onPageChanged: onPageChanged,
          itemCount: images.length,
          itemBuilder: (context, index) {
            return ColoredBox(
              color: Colors.white,
              child: MachineImage(
                imagePath: images[index],
                fit: BoxFit.contain,
              ),
            );
          },
        ),

        // Page indicators
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentIndex ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == currentIndex
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Màn hình xem PDF catalog (inline)
class PackingCatalogViewerScreen extends StatelessWidget {
  final String assetPath;
  final int initialPage;
  final String modelName;

  const PackingCatalogViewerScreen({
    super.key,
    required this.assetPath,
    required this.initialPage,
    required this.modelName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Catalog - $modelName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        assetPath,
        initialPageNumber: initialPage,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
