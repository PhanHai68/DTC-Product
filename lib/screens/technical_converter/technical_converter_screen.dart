import 'package:flutter/material.dart';

import '../../models/technical_conversion.dart';

class TechnicalConverterScreen extends StatefulWidget {
  const TechnicalConverterScreen({super.key});

  @override
  State<TechnicalConverterScreen> createState() =>
      _TechnicalConverterScreenState();
}

class _TechnicalConverterScreenState extends State<TechnicalConverterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text('Quy Đổi Kỹ Thuật Máy Tách Màu'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF148147),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF148147),
          indicatorWeight: 3.5,
          tabs: const [
            Tab(icon: Icon(Icons.grain_rounded, size: 20), text: 'Mesh - Micron - mm'),
            Tab(icon: Icon(Icons.adjust_rounded, size: 20), text: 'Kích Thước Ống (DN)'),
            Tab(icon: Icon(Icons.compress_rounded, size: 20), text: 'Áp Suất (Pressure)'),
            Tab(icon: Icon(Icons.air_rounded, size: 20), text: 'Lưu Lượng Khí (Air Flow)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MeshMicronTab(),
          _PipeSizeTab(),
          _PressureConverterTab(),
          _AirFlowConverterTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: MESH - MICRON - MILIMET - INCH
// ============================================================================
class _MeshMicronTab extends StatefulWidget {
  const _MeshMicronTab();

  @override
  State<_MeshMicronTab> createState() => _MeshMicronTabState();
}

class _MeshMicronTabState extends State<_MeshMicronTab> {
  final _searchController = TextEditingController();
  MeshConversionItem? _selectedItem = TechnicalConversionData.meshList[10]; // Mặc định Mesh 18

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = TechnicalConversionData.meshList.where((item) {
      if (query.isEmpty) return true;
      return item.mesh.toLowerCase().contains(query) ||
          item.micron.toLowerCase().contains(query) ||
          item.mm.toLowerCase().contains(query) ||
          item.inch.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Thẻ tra cứu nhanh mục đang chọn
              if (_selectedItem != null) _buildSelectedCard(_selectedItem!),
              const SizedBox(height: 16),

              // 2. Ô tìm kiếm
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Tìm kiếm theo Mesh, Micron, mm hoặc Inch',
                  hintText: 'Ví dụ: 18, 1000, 1.0...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Bảng dữ liệu Mesh - Micron
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: const Color(0xFF148147).withValues(alpha: 0.1),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('Mesh (US)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Micron (μm)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Milimet (mm)', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Inch', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = filtered[idx];
                          final isSelected = item.mesh == _selectedItem?.mesh;
                          return InkWell(
                            onTap: () => setState(() => _selectedItem = item),
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFFE8F5E9)
                                  : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Mesh ${item.mesh}',
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? const Color(0xFF148147) : const Color(0xFF0A2740),
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 3, child: Text('${item.micron} μm', style: const TextStyle(fontWeight: FontWeight.w500))),
                                  Expanded(flex: 3, child: Text('${item.mm} mm', style: const TextStyle(fontWeight: FontWeight.w500))),
                                  Expanded(flex: 3, child: Text('${item.inch}"', style: TextStyle(color: Colors.grey.shade700))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedCard(MeshConversionItem item) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF148147), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'KÍCH THƯỚC ĐANG TRA CỨU',
                      style: TextStyle(color: Color(0xFF148147), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Mesh ${item.mesh}',
                    style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.black12, height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoSub(
                    'MICRON (μm)',
                    '${item.micron} μm',
                    const Color(0xFF148147),
                  ),
                ),
                Expanded(
                  child: _buildInfoSub(
                    'MILIMET (mm)',
                    '${item.mm} mm',
                    const Color(0xFFF57F17),
                  ),
                ),
                Expanded(
                  child: _buildInfoSub(
                    'INCH (in)',
                    '${item.inch}"',
                    const Color(0xFF0288D1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSub(String title, String value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ============================================================================
// TAB 2: KÍCH THƯỚC ỐNG (DN - PHI - INCH - OD - ID)
// ============================================================================
class _PipeSizeTab extends StatefulWidget {
  const _PipeSizeTab();

  @override
  State<_PipeSizeTab> createState() => _PipeSizeTabState();
}

class _PipeSizeTabState extends State<_PipeSizeTab> {
  PipeSizeItem _selectedPipe = TechnicalConversionData.pipeSizeList[4]; // Mặc định DN20 (3/4")

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Thẻ hiển thị ống đang chọn
              Card(
                elevation: 2,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radio_button_checked_rounded, color: Color(0xFF148147), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedPipe.dn} (${_selectedPipe.inch})',
                                style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Tiêu Chuẩn Công Nghiệp', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11)),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.black12, height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('ĐƯỜNG KÍNH NGOÀI OD', style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Ø ${_selectedPipe.odMm} mm', style: const TextStyle(color: Color(0xFF148147), fontSize: 22, fontWeight: FontWeight.bold)),
                                Text('Phi tiêu chuẩn', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 50, color: Colors.black12),
                          Expanded(
                            child: Column(
                              children: [
                                Text('ĐƯỜNG KÍNH TRONG ID', style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('${_selectedPipe.idMm} mm', style: const TextStyle(color: Color(0xFFF57F17), fontSize: 22, fontWeight: FontWeight.bold)),
                                Text('Ống SCH40', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bảng danh sách kích thước ống
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: const Color(0xFF148147).withValues(alpha: 0.1),
                        child: const Row(
                          children: [
                            Expanded(flex: 2, child: Text('DN', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('Hệ Inch', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('OD (mm) - Phi', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                            Expanded(flex: 3, child: Text('ID (mm) - SCH40', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                          ],
                        ),
                      ),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: TechnicalConversionData.pipeSizeList.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final item = TechnicalConversionData.pipeSizeList[idx];
                          final isSelected = item.dn == _selectedPipe.dn;
                          return InkWell(
                            onTap: () => setState(() => _selectedPipe = item),
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFFE8F5E9)
                                  : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      item.dn,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? const Color(0xFF148147) : const Color(0xFF0A2740),
                                      ),
                                    ),
                                  ),
                                  Expanded(flex: 3, child: Text(item.inch, style: const TextStyle(fontWeight: FontWeight.w600))),
                                  Expanded(flex: 3, child: Text('${item.odMm} mm', style: const TextStyle(fontWeight: FontWeight.w500))),
                                  Expanded(flex: 3, child: Text('${item.idMm} mm', style: TextStyle(color: Colors.grey.shade700))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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

// ============================================================================
// TAB 3: ÁP SUẤT KHÍ NÉN (BAR, PSI, MPA, KGF/CM2, KPA)
// ============================================================================
class _PressureConverterTab extends StatefulWidget {
  const _PressureConverterTab();

  @override
  State<_PressureConverterTab> createState() => _PressureConverterTabState();
}

class _PressureConverterTabState extends State<_PressureConverterTab> {
  final _barCtrl = TextEditingController(text: '3.0');
  final _psiCtrl = TextEditingController();
  final _mpaCtrl = TextEditingController();
  final _kgfCtrl = TextEditingController();
  final _kpaCtrl = TextEditingController();

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _updateFromUnit(3.0, 'Bar');
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    _psiCtrl.dispose();
    _mpaCtrl.dispose();
    _kgfCtrl.dispose();
    _kpaCtrl.dispose();
    super.dispose();
  }

  void _updateFromUnit(double value, String unit) {
    if (_isUpdating) return;
    _isUpdating = true;

    final results = TechnicalConversionData.convertPressure(value, unit);

    if (unit != 'Bar') _barCtrl.text = _formatNum(results['Bar']!);
    if (unit != 'PSI') _psiCtrl.text = _formatNum(results['PSI']!);
    if (unit != 'MPa') _mpaCtrl.text = _formatNum(results['MPa']!);
    if (unit != 'kgf/cm²') _kgfCtrl.text = _formatNum(results['kgf/cm²']!);
    if (unit != 'kPa') _kpaCtrl.text = _formatNum(results['kPa']!);

    _isUpdating = false;
    setState(() {});
  }

  String _formatNum(double val) {
    if (val == 0) return '0';
    if (val >= 100) return val.toStringAsFixed(1);
    if (val >= 10) return val.toStringAsFixed(2);
    return val.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hướng dẫn
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, color: Color(0xFF148147), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Máy Tính Quy Đổi Áp Suất',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nhập bất kỳ giá trị nào dưới đây, các đơn vị còn lại sẽ tự động quy đổi đồng bộ tức thì:',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),

                      // Ô Bar
                      _buildUnitField('Bar', 'Áp suất Bar (chuẩn Châu Âu / Máy nén khí)', _barCtrl, Colors.green),
                      const SizedBox(height: 12),

                      // Ô PSI
                      _buildUnitField('PSI', 'Pound per square inch (hệ Mỹ / Đồng hồ áp)', _psiCtrl, Colors.blue),
                      const SizedBox(height: 12),

                      // Ô MPa
                      _buildUnitField('MPa', 'Megapascal (tiêu chuẩn SI)', _mpaCtrl, Colors.teal),
                      const SizedBox(height: 12),

                      // Ô kgf/cm²
                      _buildUnitField('kgf/cm²', 'Ký hơi (áp lực thực tế nhà xưởng)', _kgfCtrl, Colors.orange),
                      const SizedBox(height: 12),

                      // Ô kPa
                      _buildUnitField('kPa', 'Kilopascal (1 Bar = 100 kPa)', _kpaCtrl, Colors.indigo),
                      const SizedBox(height: 18),

                      // Các nút bấm nhanh áp suất thường dùng máy tách màu
                      Text(
                        'Mức áp suất thường gặp trong máy tách màu & máy nén khí:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.0, 8.0].map((barVal) {
                          return ActionChip(
                            label: Text('$barVal Bar', style: const TextStyle(fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFE8F5E9),
                            onPressed: () {
                              _barCtrl.text = '$barVal';
                              _updateFromUnit(barVal, 'Bar');
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bảng tham chiếu mẫu
              _buildReferenceTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitField(String unit, String desc, TextEditingController ctrl, MaterialColor color) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            unit,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final d = double.tryParse(val.trim()) ?? 0.0;
              _updateFromUnit(d, unit);
            },
            decoration: InputDecoration(
              hintText: '0.0',
              helperText: desc,
              helperStyle: const TextStyle(fontSize: 11),
              suffixText: unit,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceTable() {
    final sampleBars = [0.5, 1.0, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0];

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Bảng Quy Đổi Mẫu Chuẩn (Database_QuyDoi)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2740)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF148147).withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Expanded(child: Text('Bar', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('PSI', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('MPa', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('kgf/cm²', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('kPa', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12.5))),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sampleBars.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final bar = sampleBars[idx];
                final res = TechnicalConversionData.convertPressure(bar, 'Bar');
                return Container(
                  color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text('$bar', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF148147)))),
                      Expanded(child: Text(res['PSI']!.toStringAsFixed(1))),
                      Expanded(child: Text(res['MPa']!.toStringAsFixed(2))),
                      Expanded(child: Text(res['kgf/cm²']!.toStringAsFixed(2))),
                      Expanded(child: Text(res['kPa']!.toStringAsFixed(0))),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 4: LƯU LƯỢNG KHÍ NÉN (M3/MIN, L/MIN, CFM, M3/H, L/S)
// ============================================================================
class _AirFlowConverterTab extends StatefulWidget {
  const _AirFlowConverterTab();

  @override
  State<_AirFlowConverterTab> createState() => _AirFlowConverterTabState();
}

class _AirFlowConverterTabState extends State<_AirFlowConverterTab> {
  final _m3MinCtrl = TextEditingController(text: '1.0');
  final _lMinCtrl = TextEditingController();
  final _cfmCtrl = TextEditingController();
  final _m3HCtrl = TextEditingController();
  final _lSCtrl = TextEditingController();

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _updateFromUnit(1.0, 'm³/min');
  }

  @override
  void dispose() {
    _m3MinCtrl.dispose();
    _lMinCtrl.dispose();
    _cfmCtrl.dispose();
    _m3HCtrl.dispose();
    _lSCtrl.dispose();
    super.dispose();
  }

  void _updateFromUnit(double value, String unit) {
    if (_isUpdating) return;
    _isUpdating = true;

    final results = TechnicalConversionData.convertAirFlow(value, unit);

    if (unit != 'm³/min') _m3MinCtrl.text = _formatNum(results['m³/min']!);
    if (unit != 'L/min') _lMinCtrl.text = _formatNum(results['L/min']!);
    if (unit != 'CFM') _cfmCtrl.text = _formatNum(results['CFM']!);
    if (unit != 'm³/h') _m3HCtrl.text = _formatNum(results['m³/h']!);
    if (unit != 'L/s') _lSCtrl.text = _formatNum(results['L/s']!);

    _isUpdating = false;
    setState(() {});
  }

  String _formatNum(double val) {
    if (val == 0) return '0';
    if (val >= 100) return val.toStringAsFixed(1);
    if (val >= 10) return val.toStringAsFixed(2);
    return val.toStringAsFixed(3);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.air_rounded, color: Color(0xFF148147), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Máy Tính Quy Đổi Lưu Lượng Khí Nén',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nhập giá trị vào bất kỳ ô nào để tính toán đồng thời các đơn vị còn lại:',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),

                      _buildUnitField('m³/min', 'Mét khối / phút (tiêu chuẩn máy nén khí)', _m3MinCtrl),
                      const SizedBox(height: 12),

                      _buildUnitField('L/min', 'Lít / phút (1 m³/min = 1,000 L/min)', _lMinCtrl),
                      const SizedBox(height: 12),

                      _buildUnitField('CFM', 'Cubic feet per minute (hệ Anh/Mỹ)', _cfmCtrl),
                      const SizedBox(height: 12),

                      _buildUnitField('m³/h', 'Mét khối / giờ (1 m³/min = 60 m³/h)', _m3HCtrl),
                      const SizedBox(height: 12),

                      _buildUnitField('L/s', 'Lít / giây (1 L/s = 60 L/min)', _lSCtrl),
                      const SizedBox(height: 18),

                      Text(
                        'Dải lưu lượng thường gặp của máy nén khí máy tách màu:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0].map((flowVal) {
                          return ActionChip(
                            label: Text('$flowVal m³/min', style: const TextStyle(fontWeight: FontWeight.w600)),
                            backgroundColor: const Color(0xFFE8F5E9),
                            onPressed: () {
                              _m3MinCtrl.text = '$flowVal';
                              _updateFromUnit(flowVal, 'm³/min');
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildReferenceTable(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitField(String unit, String desc, TextEditingController ctrl) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            unit,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
          ),
        ),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (val) {
              final d = double.tryParse(val.trim()) ?? 0.0;
              _updateFromUnit(d, unit);
            },
            decoration: InputDecoration(
              hintText: '0.0',
              helperText: desc,
              helperStyle: const TextStyle(fontSize: 11),
              suffixText: unit,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceTable() {
    final sampleFlows = [0.2, 0.5, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0];

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Bảng Quy Đổi Mẫu Chuẩn (Database_QuyDoi)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2740)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF0A2740),
              child: const Row(
                children: [
                  Expanded(child: Text('m³/min', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('L/min', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('CFM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('m³/h', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
                  Expanded(child: Text('L/s', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5))),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sampleFlows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final flow = sampleFlows[idx];
                final res = TechnicalConversionData.convertAirFlow(flow, 'm³/min');
                return Container(
                  color: idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text('$flow', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF148147)))),
                      Expanded(child: Text(res['L/min']!.toStringAsFixed(0))),
                      Expanded(child: Text(res['CFM']!.toStringAsFixed(2))),
                      Expanded(child: Text(res['m³/h']!.toStringAsFixed(0))),
                      Expanded(child: Text(res['L/s']!.toStringAsFixed(2))),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
