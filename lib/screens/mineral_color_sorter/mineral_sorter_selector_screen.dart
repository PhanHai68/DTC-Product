import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/input/localized_number.dart';
import '../../data/product_data.dart';
import '../../services/mineral_sorter_selector.dart';

/// Máy tách màu Khoáng sản → Chọn máy phù hợp: theo tình trạng đá, dải kích
/// thước hạt và sản lượng cần, đọc từ `color_sorter/sx8_mineral.json`.
class MineralSorterSelectorScreen extends StatefulWidget {
  const MineralSorterSelectorScreen({super.key});

  @override
  State<MineralSorterSelectorScreen> createState() =>
      _MineralSorterSelectorScreenState();
}

class _MineralSorterSelectorScreenState
    extends State<MineralSorterSelectorScreen> {
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  final _tphCtrl = TextEditingController();
  StoneCondition _condition = StoneCondition.dry;

  final _number = NumberFormat('#,##0.##', 'vi');

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _tphCtrl.dispose();
    super.dispose();
  }

  String _fmt(double value) => _number.format(value);

  /// Yêu cầu hợp lệ; null kèm thông báo nếu thiếu hoặc sai.
  (MineralSelectionRequest?, String?) _readRequest() {
    if (_minCtrl.text.trim().isEmpty ||
        _maxCtrl.text.trim().isEmpty ||
        _tphCtrl.text.trim().isEmpty) {
      return (null, 'Nhập kích thước hạt và sản lượng cần để xem máy phù hợp.');
    }
    final min = parseLocalizedDouble(_minCtrl.text);
    final max = parseLocalizedDouble(_maxCtrl.text);
    final tph = parseLocalizedDouble(_tphCtrl.text);
    if (min == null || max == null || min <= 0 || max <= 0) {
      return (null, 'Kích thước hạt phải lớn hơn 0.');
    }
    if (max < min) {
      return (null, 'Kích thước "đến" phải lớn hơn hoặc bằng "từ".');
    }
    if (tph == null || tph <= 0) {
      return (null, 'Sản lượng cần phải lớn hơn 0.');
    }
    return (
      MineralSelectionRequest(
        minMm: min,
        maxMm: max,
        tonsPerHour: tph,
        condition: _condition,
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (request, message) = _readRequest();
    final matches = request == null
        ? const <MineralMachineMatch>[]
        : selectMineralSorters(mineralColorSorterSpecs, request);

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn máy phù hợp')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputCard(),
              const SizedBox(height: 12),
              if (message != null)
                Text(
                  message,
                  key: const Key('mineral_select_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _minCtrl.text.trim().isEmpty &&
                            _maxCtrl.text.trim().isEmpty &&
                            _tphCtrl.text.trim().isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                )
              else if (matches.isEmpty)
                _buildNoMatch()
              else
                ..._buildResults(request!, matches),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'THÔNG TIN NGUYÊN LIỆU',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const Divider(),
            const Text(
              'Tình trạng đá',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<StoneCondition>(
              segments: const [
                ButtonSegment(
                  value: StoneCondition.dry,
                  label: Text('Đá khô / bột'),
                  icon: Icon(Icons.grain_rounded),
                ),
                ButtonSegment(
                  value: StoneCondition.wet,
                  label: Text('Đá ướt / ẩm'),
                  icon: Icon(Icons.water_drop_outlined),
                ),
              ],
              selected: {_condition},
              onSelectionChanged: (value) =>
                  setState(() => _condition = value.first),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kích thước hạt (mm)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _minCtrl,
                    'Từ',
                    'mm',
                    const Key('mineral_select_min'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _maxCtrl,
                    'Đến',
                    'mm',
                    const Key('mineral_select_max'),
                  ),
                ),
              ],
            ),
            Text(
              'Chỉ một cỡ hạt thì nhập cùng một số. Ví dụ đá bột 0,1–1,2 mm; '
              'đá hạt 10–30 mm.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _field(
              _tphCtrl,
              'Sản lượng cần',
              'tấn/giờ',
              const Key('mineral_select_tph'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String suffix,
    Key key,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [LocalizedDecimalTextInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildNoMatch() {
    final ranges = mineralSupportedRanges(mineralColorSorterSpecs, _condition);
    final rangeText = ranges
        .map((r) => '${_fmt(r.$1)}–${_fmt(r.$2)} mm')
        .join(', ');
    return Card(
      key: const Key('mineral_select_no_match'),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chưa có model phân loại được trọn dải kích thước này',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _condition == StoneCondition.wet
                  ? 'Với đá ướt, các model hiện có xử lý được: $rangeText.'
                  : 'Các model hiện có xử lý được: $rangeText.',
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy thu hẹp dải kích thước (sàng phân cỡ trước khi tách) hoặc '
              'liên hệ kỹ thuật DTC để tư vấn cấu hình riêng.',
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults(
    MineralSelectionRequest request,
    List<MineralMachineMatch> matches,
  ) {
    return [
      Text(
        'KẾT QUẢ: ${matches.length} model phù hợp với đá '
        '${_condition == StoneCondition.wet ? 'ướt' : 'khô'} '
        '${_fmt(request.minMm)}–${_fmt(request.maxMm)} mm, '
        '${_fmt(request.tonsPerHour)} tấn/giờ',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < matches.length; i++)
        _buildMatchCard(matches[i], recommended: i == 0),
      const SizedBox(height: 8),
      Text(
        'Năng suất tính theo dải kích thước khó nhất trong khoảng bạn nhập '
        '(số liệu catalog). Năng suất thực tế còn phụ thuộc tỷ lệ tạp chất và '
        'độ sạch của nguyên liệu.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Widget _buildMatchCard(
    MineralMachineMatch match, {
    required bool recommended,
  }) {
    final spec = match.spec;
    final model = match.model;
    final image =
        asortSorterImagePath(model) ??
        (model.toLowerCase() == 'sx8'
            ? 'assets/images/color_sorter/sx8.jpg'
            : null);
    final (badge, badgeColor) = switch (match.fit) {
      MineralFit.fits => ('Phù hợp', Colors.green.shade700),
      MineralFit.oversized => ('Dư công suất', Colors.blueGrey.shade600),
      MineralFit.multiple => (
        'Cần ${match.machineCount} máy',
        Colors.orange.shade800,
      ),
    };
    // Dòng SA: "Đá khô · 1.2–30 mm"; SX8 không có thì dùng tên sản phẩm.
    final subtitle = [
      spec['stone_type'],
      spec['sorting_range'],
    ].whereType<String>().join(' · ');
    final details = [
      if (spec['mix_ratio'] case final mix?) 'Tỷ lệ lẫn $mix',
      if (spec['power_kw'] case final kw?) '$kw kW',
      if (spec['air_flow_m3_min'] case final air?) 'Khí nén $air m³/ph',
    ].join(' · ');

    return Card(
      key: Key('mineral_select_result_$model'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: recommended
            ? BorderSide(color: Colors.green.shade600, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      image,
                      width: 96,
                      height: 72,
                      fit: BoxFit.contain,
                      cacheWidth: 288,
                    ),
                  ),
                if (image != null) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            model,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          _chip(badge, badgeColor),
                          if (recommended)
                            _chip('Đề xuất', Colors.green.shade700),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isNotEmpty
                            ? subtitle
                            : spec['product_name'] ?? '',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Năng suất với cỡ hạt yêu cầu: '
              '${_fmt(match.minTph)}–${_fmt(match.maxTph)} tấn/giờ/máy',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (match.fit == MineralFit.multiple)
              Text(
                '${match.machineCount} máy chạy song song: tối đa '
                '${_fmt(match.maxTph * match.machineCount)} tấn/giờ',
              ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details, style: const TextStyle(fontSize: 13)),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.push(
                  Uri(
                    path: '/mineral_color_sorter',
                    queryParameters: {'model': model},
                  ).toString(),
                ),
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('Xem thông số'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
    ),
  );
}
