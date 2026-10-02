import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/dtc_palette.dart';
import '../models/factory_location.dart';
import '../providers/factory_location_provider.dart';

class FactoryLocationListScreen extends StatefulWidget {
  const FactoryLocationListScreen({super.key});

  @override
  State<FactoryLocationListScreen> createState() =>
      _FactoryLocationListScreenState();
}

class _FactoryLocationListScreenState extends State<FactoryLocationListScreen> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: context.read<FactoryLocationProvider>().query,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FactoryLocationProvider>().load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FactoryLocationProvider>();
    final items = provider.filtered;
    return Scaffold(
      appBar: AppBar(title: const Text('Vị trí nhà máy')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('factory_location_add'),
        onPressed: () => context.push('/factory-locations/form'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              key: const Key('factory_location_search'),
              controller: _search,
              onChanged: provider.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên nhà máy',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: provider.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        onPressed: () {
                          _search.clear();
                          provider.setQuery('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody(provider, items)),
        ],
      ),
    );
  }

  Widget _buildBody(
    FactoryLocationProvider provider,
    List<FactoryLocation> items,
  ) {
    if (provider.isLoading && provider.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => provider.load(force: true),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (provider.items.isEmpty) {
      return const _EmptyState();
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Không tìm thấy nhà máy nào khớp với "${provider.query.trim()}".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        return _FactoryCard(
          location: item,
          onOpenMaps: () => _openMaps(item),
          onShare: (origin) => _share(item, origin),
          onEdit: () => context.push('/factory-locations/form', extra: item),
          onDelete: () => _delete(item),
        );
      },
    );
  }

  Future<void> _openMaps(FactoryLocation location) async {
    final uri = Uri.parse(location.mapsUrl);
    var opened = false;
    try {
      // URL https của Google Maps được hệ điều hành chuyển sang app Google
      // Maps nếu đã cài; nếu không sẽ mở bằng trình duyệt.
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launchUrl(uri);
      } catch (_) {}
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không mở được Google Maps hoặc trình duyệt.'),
        ),
      );
    }
  }

  Future<void> _share(FactoryLocation location, Rect? origin) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: location.shareText,
          subject: location.name,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được bảng chia sẻ.')),
      );
    }
  }

  Future<void> _delete(FactoryLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa nhà máy?'),
        content: Text(
          'Xóa vị trí "${location.name}"? Thao tác này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<FactoryLocationProvider>().delete(location.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Đã xóa "${location.name}".')));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.factory_outlined, size: 56, color: palette.cyan),
            const SizedBox(height: 12),
            Text(
              'Chưa lưu nhà máy nào.',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nhấn "Thêm" khi đang ở nhà máy để lưu vị trí cho lần sau.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FactoryCard extends StatelessWidget {
  const _FactoryCard({
    required this.location,
    required this.onOpenMaps,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  final FactoryLocation location;
  final VoidCallback onOpenMaps;
  final ValueChanged<Rect?> onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final accuracy = location.accuracy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.factory_outlined, color: palette.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    location.name,
                    style: TextStyle(
                      color: palette.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                    PopupMenuItem(value: 'delete', child: Text('Xóa')),
                  ],
                ),
              ],
            ),
            if (location.note.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 34, right: 10),
                child: Text(
                  location.note.trim(),
                  style: TextStyle(color: palette.ink),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 4, right: 10),
              child: Text(
                [
                  '${location.latitude.toStringAsFixed(6)}, '
                      '${location.longitude.toStringAsFixed(6)}',
                  if (accuracy != null) '±${accuracy.round()} m',
                ].join(' · '),
                style: TextStyle(color: palette.muted, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 34, right: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Mở Google Maps'),
                  ),
                  Builder(
                    builder: (buttonContext) => OutlinedButton.icon(
                      onPressed: () => onShare(_originOf(buttonContext)),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Chia sẻ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
