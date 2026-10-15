import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/input/localized_number.dart';
import '../../data/product_data.dart';
import '../../models/acomp_spec_model.dart';
import '../../models/acomp_vsd_compare_config.dart';
import '../../providers/electricity_bill_provider.dart';
import '../../services/acomp_energy_calculator.dart';

/// So sánh máy nén khí biến tần (PM VSD) và tốc độ cố định cùng cỡ: tiền
/// điện theo nhu cầu khí của khách, hoàn vốn phần chênh giá và thông số.
class AcompVsdCompareScreen extends StatefulWidget {
  /// Mã cỡ máy chọn sẵn, ví dụ `ACP-50` (mở từ màn thông số).
  final String? initialSize;

  const AcompVsdCompareScreen({super.key, this.initialSize});

  @override
  State<AcompVsdCompareScreen> createState() => _AcompVsdCompareScreenState();
}

class _AcompVsdCompareScreenState extends State<AcompVsdCompareScreen> {
  static const _vsdColor = Colors.teal;
  static const _fixedColor = Colors.deepOrange;

  final _config = acompVsdCompareConfig;
  late final List<AcompSpeedPair> _pairs = buildAcompSpeedPairs(acompSpecData);
  AcompSpeedPair? _pair;
  int _pressureBar = 8;

  final _loadCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController(text: '16');
  final _daysCtrl = TextEditingController(text: '300');
  late final TextEditingController _electricityCtrl;
  final _vsdPriceCtrl = TextEditingController();
  final _fixedPriceCtrl = TextEditingController();

  late final TextEditingController _unloadCtrl;
  late final TextEditingController _baseCtrl;
  late final TextEditingController _minLoadCtrl;
  late final TextEditingController _bandCtrl;

  final _money = NumberFormat('#,##0.0', 'vi');
  final _integer = NumberFormat('#,##0', 'vi');

  @override
  void initState() {
    super.initState();
    _pair = _pairs
        .where((pair) => pair.sizeCode == widget.initialSize)
        .firstOrNull;
    final rate = context.read<ElectricityBillProvider>().normalRate;
    _electricityCtrl = TextEditingController(text: _plain(rate));
    final a = _config.assumptions;
    _unloadCtrl = TextEditingController(text: _plain(a.unloadPowerRatio * 100));
    _baseCtrl = TextEditingController(text: _plain(a.vsdBaseRatio * 100));
    _minLoadCtrl = TextEditingController(text: _plain(a.vsdMinLoad * 100));
    _bandCtrl = TextEditingController(text: _plain(a.fixedPressureBandBar));
  }

  @override
  void dispose() {
    for (final ctrl in [
      _loadCtrl,
      _hoursCtrl,
      _daysCtrl,
      _electricityCtrl,
      _vsdPriceCtrl,
      _fixedPriceCtrl,
      _unloadCtrl,
      _baseCtrl,
      _minLoadCtrl,
      _bandCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _plain(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');

  String _vnd(double value) {
    final abs = value.abs();
    if (abs >= 1e9) return '${_money.format(value / 1e9)} tỷ ₫';
    return '${_money.format(value / 1e6)} triệu ₫';
  }

  void _resetAssumptions() {
    final a = _config.assumptions;
    setState(() {
      _unloadCtrl.text = _plain(a.unloadPowerRatio * 100);
      _baseCtrl.text = _plain(a.vsdBaseRatio * 100);
      _minLoadCtrl.text = _plain(a.vsdMinLoad * 100);
      _bandCtrl.text = _plain(a.fixedPressureBandBar);
    });
  }

  /// Giả định đang dùng; null kèm thông báo nếu ô nào sai.
  (AcompVsdAssumptions?, String?) _readAssumptions() {
    double? percent(TextEditingController ctrl) {
      final value = parseLocalizedDouble(ctrl.text);
      if (value == null || value < 0 || value > 100) return null;
      return value / 100;
    }

    final unload = percent(_unloadCtrl);
    final base = percent(_baseCtrl);
    final minLoad = percent(_minLoadCtrl);
    final band = parseLocalizedDouble(_bandCtrl.text);
    if (unload == null || base == null || minLoad == null) {
      return (null, 'Giả định nâng cao: các tỷ lệ phải từ 0 đến 100%.');
    }
    if (band == null || band < 0 || band > 3) {
      return (null, 'Giả định nâng cao: dải áp phải từ 0 đến 3 bar.');
    }
    return (
      _config.assumptions.copyWith(
        unloadPowerRatio: unload,
        vsdBaseRatio: base,
        vsdMinLoad: minLoad,
        fixedPressureBandBar: band,
      ),
      null,
    );
  }

  /// Điều kiện vận hành; null kèm thông báo nếu thiếu hoặc sai.
  (AcompOperatingInput?, String?) _readInput() {
    if (_pair == null) return (null, null);
    if (_loadCtrl.text.trim().isEmpty) {
      return (
        null,
        'Nhập nhu cầu khí trung bình của khách (%) để xem kết quả.',
      );
    }
    final load = parseLocalizedDouble(_loadCtrl.text);
    if (load == null || load < 10 || load > 100) {
      return (null, 'Nhu cầu khí trung bình phải từ 10 đến 100%.');
    }
    final hours = parseLocalizedDouble(_hoursCtrl.text);
    if (hours == null || hours <= 0 || hours > 24) {
      return (null, 'Giờ chạy mỗi ngày phải lớn hơn 0 và không quá 24.');
    }
    final days = parseLocalizedDouble(_daysCtrl.text);
    if (days == null || days <= 0 || days > 366) {
      return (null, 'Số ngày chạy mỗi năm phải từ 1 đến 366.');
    }
    final electricity = parseLocalizedDouble(_electricityCtrl.text);
    if (electricity == null || electricity <= 0) {
      return (null, 'Giá điện phải lớn hơn 0.');
    }
    double? price(TextEditingController ctrl) {
      final value = parseLocalizedDouble(ctrl.text);
      return value == null || value <= 0 ? null : value * 1e6;
    }

    return (
      AcompOperatingInput(
        loadPercent: load,
        pressureBar: _pressureBar,
        hoursPerDay: hours,
        daysPerYear: days,
        electricityPrice: electricity,
        vsdPrice: price(_vsdPriceCtrl),
        fixedPrice: price(_fixedPriceCtrl),
      ),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final (assumptions, assumptionError) = _readAssumptions();
    final (input, inputError) = _readInput();
    final pair = _pair;
    AcompSpeedComparison? result;
    AcompEnergyCalculator? calculator;
    if (pair != null && input != null && assumptions != null) {
      calculator = AcompEnergyCalculator(assumptions);
      result = calculator.compare(pair, input);
    }
    final message = assumptionError ?? inputError;

    return Scaffold(
      appBar: AppBar(title: const Text('So sánh biến tần – cố định')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPairCard(),
              const SizedBox(height: 12),
              _buildInputCard(),
              if (message != null && pair != null) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  key: const Key('vsd_compare_message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: inputError != null && _loadCtrl.text.trim().isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (result != null && calculator != null) ...[
                const SizedBox(height: 12),
                _buildAdviceCard(adviseAcompSpeed(result, _config)),
                const SizedBox(height: 12),
                _buildResultCard(result),
                const SizedBox(height: 12),
                _buildSavingsChart(calculator, result),
                if (result.hasPrices) ...[
                  const SizedBox(height: 12),
                  _buildCostChart(result),
                ],
              ],
              if (pair != null) ...[
                const SizedBox(height: 12),
                _buildSpecCard(pair),
                const SizedBox(height: 12),
                _buildNotesCard(),
                const SizedBox(height: 12),
                Text(
                  'Kết quả là ước tính theo giả định: công suất ghi trên catalog '
                  'được coi là công suất điện khi chạy đầy tải; máy cố định chạy '
                  'có tải/không tải; máy biến tần giảm tốc theo nhu cầu khí. '
                  'Điện năng thực tế phụ thuộc cách vận hành của khách.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, {Color color = Colors.teal}) {
    return Text(
      text,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildPairCard() {
    final pair = _pair;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('CHỌN CÔNG SUẤT MÁY'),
            const Divider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AcompSpeedPair>(
                  key: const Key('vsd_compare_pair'),
                  isExpanded: true,
                  hint: const Text('Chọn công suất...'),
                  value: pair,
                  items: [
                    for (final item in _pairs)
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          '${_plain(item.vsd.powerHP)} HP '
                          '(${_plain(item.vsd.powerKW)} kW) – ${item.sizeCode}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _pair = value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Áp suất làm việc',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 bar')),
                    ButtonSegment(value: 8, label: Text('8 bar')),
                  ],
                  selected: {_pressureBar},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _pressureBar = value.first),
                ),
              ],
            ),
            if (pair != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _modelChip(pair.vsd, 'Biến tần', _vsdColor)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.compare_arrows_rounded),
                  ),
                  Expanded(
                    child: _modelChip(pair.fixed, 'Cố định', _fixedColor),
                  ),
                ],
              ),
              if (pair.isMismatched(_pressureBar)) ...[
                const SizedBox(height: 8),
                Text(
                  'Hai máy cỡ này lệch công suất hoặc lưu lượng. Nhu cầu khí '
                  'được tính theo lưu lượng của máy nhỏ hơn để cả hai cùng '
                  'cấp một lượng khí.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _modelChip(AcompSpecModel model, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            model.modelCode,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            '$label · ${_plain(model.powerKW)} kW · '
            '${_plain(_pair!.flowAt(model, _pressureBar))} m³/ph',
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
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
            _sectionTitle('ĐIỀU KIỆN VẬN HÀNH'),
            const Divider(),
            _field(
              _loadCtrl,
              'Nhu cầu khí trung bình',
              suffix: '%',
              hint: 'VD: 60',
              key: const Key('vsd_compare_load'),
              helper: 'Theo lưu lượng định mức của máy; khách hàng cung cấp',
            ),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _hoursCtrl,
                    'Giờ chạy/ngày',
                    suffix: 'giờ',
                    key: const Key('vsd_compare_hours'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _daysCtrl,
                    'Ngày chạy/năm',
                    suffix: 'ngày',
                    key: const Key('vsd_compare_days'),
                  ),
                ),
              ],
            ),
            _field(
              _electricityCtrl,
              'Giá điện bình quân',
              suffix: 'đ/kWh',
              key: const Key('vsd_compare_electricity'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Giá mua (không bắt buộc, để tính hoàn vốn)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(
                    _vsdPriceCtrl,
                    'Máy biến tần',
                    suffix: 'triệu ₫',
                    key: const Key('vsd_compare_vsd_price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _fixedPriceCtrl,
                    'Máy cố định',
                    suffix: 'triệu ₫',
                    key: const Key('vsd_compare_fixed_price'),
                  ),
                ),
              ],
            ),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  'Giả định nâng cao',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                children: [
                  _field(
                    _unloadCtrl,
                    'Công suất khi chạy không tải',
                    suffix: '% đầy tải',
                  ),
                  _field(
                    _bandCtrl,
                    'Máy cố định đặt áp cao hơn',
                    suffix: 'bar',
                    helper:
                        'Mỗi 1 bar tốn thêm khoảng '
                        '${_plain(_config.assumptions.energyPerBar * 100)}% điện',
                  ),
                  _field(
                    _baseCtrl,
                    'Phần công suất cố định của biến tần',
                    suffix: '% đầy tải',
                  ),
                  _field(
                    _minLoadCtrl,
                    'Tốc độ tối thiểu của biến tần',
                    suffix: '% lưu lượng',
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetAssumptions,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Khôi phục mặc định'),
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

  Widget _field(
    TextEditingController controller,
    String label, {
    String? suffix,
    String? hint,
    String? helper,
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [LocalizedDecimalTextInputFormatter()],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildAdviceCard(AcompAdvice advice) {
    final color = switch (advice.level) {
      AcompAdviceLevel.vsd => _vsdColor,
      AcompAdviceLevel.fixed => _fixedColor,
      AcompAdviceLevel.consider => Colors.amber.shade800,
    };
    return Container(
      key: const Key('vsd_compare_advice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  advice.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(advice.detail),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(AcompSpeedComparison result) {
    final savings = result.savingsPerYear;
    final payback = result.paybackYears;
    final rows = <(String, String, String)>[
      (
        'Tải thực của máy',
        '${_money.format(result.vsd.load * 100)}%',
        '${_money.format(result.fixed.load * 100)}%',
      ),
      (
        'Công suất trung bình',
        '${_money.format(result.vsd.averageKW)} kW',
        '${_money.format(result.fixed.averageKW)} kW',
      ),
      (
        'Điện năng/năm',
        '${_integer.format(result.vsd.kwhPerYear)} kWh',
        '${_integer.format(result.fixed.kwhPerYear)} kWh',
      ),
      (
        'Tiền điện/năm',
        _vnd(result.vsd.costPerYear),
        _vnd(result.fixed.costPerYear),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('KẾT QUẢ', color: Colors.blue),
            Text(
              'Nhu cầu khí: ${_money.format(result.demandFlow)} m³/phút ở '
              '${result.input.pressureBar} bar · '
              '${_integer.format(result.input.hoursPerYear)} giờ/năm',
              style: const TextStyle(fontSize: 13),
            ),
            const Divider(),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.3),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    _headerCell('Biến tần', _vsdColor),
                    _headerCell('Cố định', _fixedColor),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      _cell(row.$1, bold: true),
                      _cell(row.$2, align: TextAlign.right),
                      _cell(row.$3, align: TextAlign.right),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _highlight(
              savings >= 0 ? 'Biến tần tiết kiệm/năm' : 'Biến tần tốn thêm/năm',
              '${_vnd(savings.abs())}\n'
              '(${_money.format(result.savingsPercent.abs())}% · '
              '${_integer.format(result.kwhSavedPerYear.abs())} kWh)',
              key: const Key('vsd_compare_savings'),
            ),
            if (result.hasPrices) ...[
              _highlight(
                'Chênh lệch giá mua',
                result.priceDifference! >= 0
                    ? 'Biến tần đắt hơn ${_vnd(result.priceDifference!)}'
                    : 'Biến tần rẻ hơn ${_vnd(-result.priceDifference!)}',
              ),
              _highlight(
                'Hoàn vốn phần chênh giá',
                payback == null
                    ? 'Không hoàn vốn'
                    : payback == 0
                    ? 'Ngay từ đầu'
                    : '${_money.format(payback)} năm '
                          '(~${_integer.format(payback * 12)} tháng)',
                key: const Key('vsd_compare_payback'),
              ),
              _highlight(
                'Lợi thế lũy kế của biến tần',
                '5 năm: ${_signed(result.netBenefitAfter(5))}\n'
                    '10 năm: ${_signed(result.netBenefitAfter(10))}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _signed(double value) =>
      value >= 0 ? '+${_vnd(value)}' : '−${_vnd(-value)}';

  Widget _headerCell(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    ),
  );

  Widget _cell(String text, {bool bold = false, TextAlign? align}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: 14,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      ),
    ),
  );

  Widget _highlight(String label, String value, {Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartCard(String title, String subtitle, Widget chart) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(title, color: Colors.blue),
            Text(subtitle, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(height: 240, child: chart),
          ],
        ),
      ),
    );
  }

  FlTitlesData _titles({
    required String bottomName,
    required String Function(double) bottomLabel,
    required double bottomInterval,
    required String Function(double) leftLabel,
  }) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        axisNameWidget: Text(bottomName, style: const TextStyle(fontSize: 12)),
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: bottomInterval,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(
              bottomLabel(value),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child: Text(leftLabel(value), style: const TextStyle(fontSize: 10)),
          ),
        ),
      ),
    );
  }

  Widget _buildSavingsChart(
    AcompEnergyCalculator calculator,
    AcompSpeedComparison result,
  ) {
    final curve = calculator.savingsCurve(result.pair, result.input);
    final values = curve.map((point) => point.$2);
    final maxY = (values.reduce((a, b) => a > b ? a : b) / 5).ceil() * 5.0;
    final minY = [
      0.0,
      (values.reduce((a, b) => a < b ? a : b) / 5).floor() * 5.0,
    ].reduce((a, b) => a < b ? a : b);

    return _chartCard(
      'TIẾT KIỆM THEO MỨC TẢI',
      '% tiền điện máy biến tần tiết kiệm so với máy cố định. Đường đứt là '
          'mức tải của khách.',
      LineChart(
        LineChartData(
          minX: 10,
          maxX: 100,
          minY: minY,
          maxY: maxY <= minY ? minY + 5 : maxY,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black12),
          ),
          titlesData: _titles(
            bottomName: 'Nhu cầu khí (%)',
            bottomLabel: (value) => value.toInt().toString(),
            bottomInterval: 10,
            leftLabel: (value) => '${value.toInt()}%',
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final (x, y) in curve) FlSpot(x, y)],
              color: _vsdColor,
              barWidth: 3,
              isCurved: false,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: _vsdColor.withValues(alpha: 0.12),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: Colors.black38, strokeWidth: 1),
            ],
            verticalLines: [
              VerticalLine(
                x: result.input.loadPercent,
                color: _fixedColor,
                strokeWidth: 1.5,
                dashArray: [5, 4],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _fixedColor,
                  ),
                  labelResolver: (_) =>
                      '${_money.format(result.savingsPercent)}%',
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    'Tải ${spot.x.toInt()}%: ${_money.format(spot.y)}%',
                    const TextStyle(color: Colors.white, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCostChart(AcompSpeedComparison result) {
    const years = 10.0;
    final vsdEnd = result.totalCostAfter(years, vsdMachine: true);
    final fixedEnd = result.totalCostAfter(years, vsdMachine: false);
    final maxY = [vsdEnd, fixedEnd].reduce((a, b) => a > b ? a : b) * 1.05;
    final payback = result.paybackYears;

    LineChartBarData line(bool vsdMachine, Color color) => LineChartBarData(
      spots: [
        FlSpot(0, result.totalCostAfter(0, vsdMachine: vsdMachine)),
        FlSpot(years, result.totalCostAfter(years, vsdMachine: vsdMachine)),
      ],
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    );

    return _chartCard(
      'CHI PHÍ LŨY KẾ (GIÁ MUA + TIỀN ĐIỆN)',
      'Xanh: biến tần · Cam: cố định. Hai đường cắt nhau ở điểm hoàn vốn.',
      LineChart(
        LineChartData(
          minX: 0,
          maxX: years,
          minY: 0,
          maxY: maxY,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.black12),
          ),
          titlesData: _titles(
            bottomName: 'Năm',
            bottomLabel: (value) => value.toInt().toString(),
            bottomInterval: 1,
            leftLabel: (value) => value >= 1e9
                ? '${_money.format(value / 1e9)}tỷ'
                : '${(value / 1e6).round()}tr',
          ),
          lineBarsData: [line(true, _vsdColor), line(false, _fixedColor)],
          extraLinesData: ExtraLinesData(
            verticalLines: [
              if (payback != null && payback > 0 && payback <= years)
                VerticalLine(
                  x: payback,
                  color: Colors.black45,
                  strokeWidth: 1,
                  dashArray: [5, 4],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    labelResolver: (_) =>
                        'Hoàn vốn ${_money.format(payback)} năm',
                  ),
                ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    _vnd(spot.y),
                    TextStyle(color: spot.bar.color, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, String>? _mccb(String model) =>
      acompMccbData.where((row) => row['model'] == model).firstOrNull;

  String _amp(String? raw) {
    final value = raw
        ?.replaceAll(RegExp(r'\s*A$'), '')
        .replaceAll('.', ',')
        .trim();
    return value == null || value.isEmpty ? '–' : '$value A';
  }

  /// `1720x1220x1600` → `1720 × 1220 × 1600` để ngắt dòng giữa các số.
  String _dimensions(AcompSpecModel model) =>
      model.dimensions.split('x').join(' × ');

  Widget _buildSpecCard(AcompSpeedPair pair) {
    final vsd = pair.vsd;
    final fixed = pair.fixed;
    final vsdMccb = _mccb(vsd.modelCode);
    final fixedMccb = _mccb(fixed.modelCode);
    final rows = <(String, String, String)>[
      ('Công suất', '${_plain(vsd.powerKW)} kW', '${_plain(fixed.powerKW)} kW'),
      (
        'Lưu lượng 7 bar',
        '${_plain(vsd.flow7Bar)} m³/ph',
        '${_plain(fixed.flow7Bar)} m³/ph',
      ),
      (
        'Lưu lượng 8 bar',
        '${_plain(vsd.flow8Bar)} m³/ph',
        '${_plain(fixed.flow8Bar)} m³/ph',
      ),
      (
        'Dòng định mức',
        _amp(vsdMccb?['ratedCurrent']),
        _amp(fixedMccb?['ratedCurrent']),
      ),
      (
        'Dòng khởi động',
        _amp(vsdMccb?['startingCurrent']),
        _amp(fixedMccb?['startingCurrent']),
      ),
      (
        'Kiểu khởi động',
        vsdMccb?['startingNote'] ?? '–',
        fixedMccb?['startingNote'] ?? '–',
      ),
      (
        'MCCB máy nén',
        _amp(vsdMccb?['mccbComp']),
        _amp(fixedMccb?['mccbComp']),
      ),
      (
        'Cáp máy nén',
        vsdMccb?['cableComp'] ?? '–',
        fixedMccb?['cableComp'] ?? '–',
      ),
      ('Cổng ra khí', vsd.airOutlet, fixed.airOutlet),
      (
        'Dầu bôi trơn',
        '${_plain(vsd.lubricant)} L',
        '${_plain(fixed.lubricant)} L',
      ),
      ('Trọng lượng', '${_plain(vsd.weight)} kg', '${_plain(fixed.weight)} kg'),
      ('Kích thước (mm)', _dimensions(vsd), _dimensions(fixed)),
    ];
    final highlight = Colors.amber.withValues(alpha: 0.15);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('THÔNG SỐ ĐẶT CẠNH NHAU'),
            const Text(
              'Dòng tô màu là thông số khác nhau giữa hai máy.',
              style: TextStyle(fontSize: 13),
            ),
            const Divider(),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    _headerCell(vsd.modelCode, _vsdColor),
                    _headerCell(fixed.modelCode, _fixedColor),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    decoration: row.$2 != row.$3
                        ? BoxDecoration(color: highlight)
                        : null,
                    children: [
                      _cell(row.$1, bold: true),
                      _cell(row.$2, align: TextAlign.right),
                      _cell(row.$3, align: TextAlign.right),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    Widget notes(String title, List<String> items, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('ƯU ĐIỂM TỪNG DÒNG MÁY'),
            const Divider(),
            notes('Máy biến tần (PM VSD)', _config.vsdNotes, _vsdColor),
            const SizedBox(height: 8),
            notes('Máy tốc độ cố định', _config.fixedNotes, _fixedColor),
          ],
        ),
      ),
    );
  }
}
