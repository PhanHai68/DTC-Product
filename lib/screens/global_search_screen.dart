import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/paddy_specs_data.dart';
import '../data/specs_data.dart';
import '../data/tea_specs_data.dart';
import '../data/mineral_specs_data.dart';
import '../data/agro_specs_data.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  static const _recentKey = 'global_search_recent_locations';
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  var _query = '';
  var _recentLocations = <String>[];

  late final List<_SearchItem> _items = [
    const _SearchItem(
      title: 'Máy tách màu',
      subtitle: 'Chọn nhóm nguyên liệu',
      location: '/color_sorter_categories',
      icon: Icons.auto_awesome_mosaic_rounded,
      keywords: 'gạo thóc trà chè khoáng sản nông sản',
    ),
    const _SearchItem(
      title: 'Cân đóng gói',
      subtitle: 'Danh mục, chọn máy và so sánh model',
      location: '/packing_menu',
      icon: Icons.scale_rounded,
      keywords: 'đóng bao pe pp model',
    ),
    const _SearchItem(
      title: 'Máy nén khí ACOMP',
      subtitle: 'Thông số, chọn công suất và tính toán',
      location: '/acomp_menu',
      icon: Icons.air_rounded,
      keywords: 'khí nén acomp bình đường ống mccb',
    ),
    const _SearchItem(
      title: 'Tính năng suất',
      subtitle: 'Đo thực tế và xuất biên bản PDF',
      location: '/productivity_calc',
      icon: Icons.speed_rounded,
      keywords: 'kg tấn giờ stopwatch pdf',
    ),
    const _SearchItem(
      title: 'Chuyển đổi đơn vị',
      subtitle: 'Mesh, kích thước ống, áp suất và lưu lượng',
      location: '/technical_converter',
      icon: Icons.swap_horiz_rounded,
      keywords: 'mesh micron mm inch dn bar psi cfm quy doi ky thuat',
    ),
    const _SearchItem(
      title: 'Ghi Chú & Nhắc Hẹn',
      subtitle: 'Ghi chú cá nhân, checklist và nhắc hẹn theo giờ',
      location: '/notes',
      icon: Icons.edit_note_rounded,
      keywords: 'ghi chu note nhac hen checklist cong viec ca nhan',
    ),
    const _SearchItem(
      title: 'Lập Form Lưu Mẫu',
      subtitle: 'Ghi nhận mẫu, ảnh và xuất PDF',
      location: '/sample_record',
      icon: Icons.assignment_turned_in_outlined,
      keywords: 'lưu mẫu form ảnh pdf',
    ),
    const _SearchItem(
      title: 'Nhắc Nhở Lịch Bảo Trì',
      subtitle: 'Theo dõi máy và lịch bảo trì',
      location: '/maintenance',
      icon: Icons.build_circle_outlined,
      keywords: 'bảo dưỡng lịch máy khách hàng quản lý bảo trì theo dõi',
    ),
    const _SearchItem(
      title: 'Phân tích hoàn vốn',
      subtitle: 'Điện, lợi nhuận và biểu đồ hoàn vốn',
      location: '/payback_analysis',
      icon: Icons.query_stats_rounded,
      keywords: 'roi tiền điện doanh thu lợi nhuận',
    ),
    const _SearchItem(
      title: 'Theo Dõi Lắp Đặt Và Nghiệm Thu',
      subtitle: 'Tiến độ thi công, nghiệm thu và hồ sơ dự án',
      location: '/projects',
      icon: Icons.engineering_outlined,
      keywords:
          'du an project tracking tien do nghiem thu cong trinh theo doi du an',
    ),
    ...colorSorterSpecs.map((spec) {
      final model = spec['Model'] ?? '';
      return _SearchItem(
        title: model,
        subtitle: 'Máy tách màu Gạo',
        location: '/color_sorter?model=${Uri.encodeQueryComponent(model)}',
        icon: Icons.precision_manufacturing_outlined,
        keywords: spec.values.join(' '),
      );
    }),
    ...paddyColorSorterSpecs.map((spec) {
      final model = spec['Model'] ?? '';
      return _SearchItem(
        title: model,
        subtitle: 'Máy tách màu Thóc và Gạo xô',
        location:
            '/paddy_color_sorter?model=${Uri.encodeQueryComponent(model)}',
        icon: Icons.grass_rounded,
        keywords: spec.values.join(' '),
      );
    }),
    ...teaColorSorterSpecs.map((spec) {
      final model = spec['model'] ?? '';
      return _SearchItem(
        title: model,
        subtitle: 'Máy tách màu Trà',
        location: '/tea_color_sorter?model=${Uri.encodeQueryComponent(model)}',
        icon: Icons.eco_rounded,
        keywords: spec.values.join(' '),
      );
    }),
    ...mineralColorSorterSpecs.map((spec) {
      final model = spec['model'] ?? '';
      return _SearchItem(
        title: model,
        subtitle: 'Máy tách màu Khoáng sản',
        location: '/mineral_color_sorter',
        icon: Icons.terrain_rounded,
        keywords: spec.values.join(' '),
      );
    }),
    ...agroColorSorterSpecs.map((spec) {
      final model = spec['model'] ?? '';
      return _SearchItem(
        title: model,
        subtitle: 'Máy tách màu Nông sản',
        location: '/agro_color_sorter',
        icon: Icons.spa_rounded,
        keywords: spec.values.join(' '),
      );
    }),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecent() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _recentLocations = preferences.getStringList(_recentKey) ?? const [];
    });
  }

  Future<void> _open(_SearchItem item) async {
    final recent = [
      item.location,
      ..._recentLocations.where((location) => location != item.location),
    ].take(6).toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_recentKey, recent);
    if (!mounted) return;
    context.push(item.location);
  }

  List<_SearchItem> get _results {
    final query = _normalize(_query);
    if (query.isEmpty) return const [];
    return _items.where((item) {
      final haystack = _normalize(
        '${item.title} ${item.subtitle} ${item.keywords}',
      );
      return haystack.contains(query);
    }).toList();
  }

  List<_SearchItem> get _recentItems => _recentLocations
      .map((location) => _items.where((item) => item.location == location))
      .where((items) => items.isNotEmpty)
      .map((items) => items.first)
      .toList();

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final showingRecent = _query.trim().isEmpty;
    final items = showingRecent ? _recentItems : results;
    return Scaffold(
      appBar: AppBar(title: const Text('Tra cứu nhanh')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SearchBar(
                controller: _controller,
                focusNode: _focusNode,
                hintText: 'Nhập model hoặc chức năng, ví dụ: SC12, PDF...',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_query.isNotEmpty)
                    IconButton(
                      tooltip: 'Xóa từ khóa',
                      onPressed: () {
                        _controller.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 22),
              Text(
                showingRecent
                    ? (items.isEmpty ? 'Gợi ý tra cứu' : 'Đã mở gần đây')
                    : '${items.length} kết quả',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (!showingRecent && items.isEmpty)
                const _NoSearchResult()
              else
                ...((showingRecent && items.isEmpty) ? _items.take(8) : items)
                    .map(
                      (item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: Icon(item.icon),
                          title: Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(item.subtitle),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _open(item),
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

class _NoSearchResult extends StatelessWidget {
  const _NoSearchResult();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tìm thấy nội dung phù hợp.\nHãy thử tên model hoặc từ khóa ngắn hơn.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.location,
    required this.icon,
    this.keywords = '',
  });

  final String title;
  final String subtitle;
  final String location;
  final IconData icon;
  final String keywords;
}

String _normalize(String value) {
  const source =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const target =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  var normalized = value.toLowerCase();
  for (var index = 0; index < source.length; index++) {
    normalized = normalized.replaceAll(source[index], target[index]);
  }
  return normalized;
}
