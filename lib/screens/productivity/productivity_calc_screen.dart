import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/productivity_calc.dart';
import '../../services/productivity_pdf_service.dart';

class ProductivityCalcScreen extends StatefulWidget {
  const ProductivityCalcScreen({super.key});

  @override
  State<ProductivityCalcScreen> createState() => _ProductivityCalcScreenState();
}

class _ProductivityCalcScreenState extends State<ProductivityCalcScreen> {
  final _customerController = TextEditingController();
  final _materialController = TextEditingController();
  final _notesController = TextEditingController();
  final _weightController = TextEditingController(text: '0');
  final _hoursController = TextEditingController(text: '0');
  final _minutesController = TextEditingController(text: '0');
  final _secondsController = TextEditingController(text: '0');

  // Quản lý đồng hồ bấm giờ (Stopwatch)
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _stopwatchElapsedSeconds = 0;
  bool _isStopwatchActive = false;

  // Trạng thái xuất PDF
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _customerController.addListener(_onFieldChanged);
    _materialController.addListener(_onFieldChanged);
    _notesController.addListener(_onFieldChanged);
    _weightController.addListener(_onFieldChanged);
    _hoursController.addListener(_onFieldChanged);
    _minutesController.addListener(_onFieldChanged);
    _secondsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _customerController.dispose();
    _materialController.dispose();
    _notesController.dispose();
    _weightController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  // --- Logic Đồng hồ bấm giờ ---
  void _startStopwatch() {
    _stopwatch.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (mounted) {
        setState(() {
          _stopwatchElapsedSeconds = _stopwatch.elapsed.inSeconds;
          _isStopwatchActive = true;
        });
      }
    });
    setState(() => _isStopwatchActive = true);
  }

  void _pauseStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _isStopwatchActive = false);
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    _stopwatch.stop();
    _timer?.cancel();
    setState(() {
      _stopwatchElapsedSeconds = 0;
      _isStopwatchActive = false;
    });
  }

  void _applyStopwatchToInputs() {
    final totalSec = _stopwatch.elapsed.inSeconds;
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;

    _hoursController.text = '$h';
    _minutesController.text = '$m';
    _secondsController.text = '$s';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã áp dụng thời gian đo: ${h > 0 ? '$h giờ ' : ''}$m phút $s giây'),
        backgroundColor: const Color(0xFF148147),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatStopwatchTime(int totalSec) {
    final h = (totalSec ~/ 3600).toString().padLeft(2, '0');
    final m = ((totalSec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // --- Tính toán kết quả ---
  ProductivityCalcData _getCalculationData() {
    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final h = int.tryParse(_hoursController.text.trim()) ?? 0;
    final m = int.tryParse(_minutesController.text.trim()) ?? 0;
    final s = int.tryParse(_secondsController.text.trim()) ?? 0;

    return ProductivityCalcData(
      customerName: _customerController.text.trim(),
      materialName: _materialController.text.trim(),
      notes: _notesController.text.trim(),
      weightKg: weight,
      hours: h < 0 ? 0 : h,
      minutes: m < 0 ? 0 : m,
      seconds: s < 0 ? 0 : s,
      measuredAt: DateTime.now(),
    );
  }

  Future<void> _exportPdf() async {
    final data = _getCalculationData();
    if (data.weightKg <= 0 || data.totalSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập khối lượng và thời gian đo lớn hơn 0 để xuất PDF.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);
    try {
      final pdfBytes = await ProductivityPdfService.build(data: data);
      if (!mounted) return;

      final safeName = data.customerName.isNotEmpty
          ? data.customerName.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_')
          : 'Mẫu_Đo';
      final fileName = 'Ket_qua_tinh_nang_suat_${safeName}_${DateFormat('ddMMyyyy_HHmm').format(data.measuredAt)}.pdf';

      // Hiển thị dialog xem trước PDF
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850, maxHeight: 850),
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Xem Trước Phiếu Năng Suất (A4)', style: TextStyle(fontSize: 16)),
                backgroundColor: const Color(0xFF0A2740),
                foregroundColor: Colors.white,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'Chia sẻ / Tải về PDF',
                    onPressed: () async {
                      final box = context.findRenderObject() as RenderBox?;
                      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [
                            XFile.fromData(
                              pdfBytes,
                              mimeType: 'application/pdf',
                              name: fileName,
                            ),
                          ],
                          title: 'Phiếu kết quả tính năng suất - DTC Group',
                          text: 'Phiếu kết quả tính năng suất: ${data.customerName} - ${data.materialName} - Năng suất: ${data.kgPerHour.toStringAsFixed(1)} kg/h (${data.tonPerHour.toStringAsFixed(2)} tấn/h)',
                          sharePositionOrigin: origin,
                          fileNameOverrides: [fileName],
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: SfPdfViewer.memory(pdfBytes),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tạo PDF: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _resetForm() {
    _customerController.clear();
    _materialController.clear();
    _notesController.clear();
    _weightController.text = '0';
    _hoursController.text = '0';
    _minutesController.text = '0';
    _secondsController.text = '0';
    _resetStopwatch();
  }

  @override
  Widget build(BuildContext context) {
    final calcData = _getCalculationData();
    final numberFmt = NumberFormat('#,##0.0');
    final tonFmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      appBar: AppBar(
        title: const Text('Tính Năng Suất Máy Tách Màu'),
        backgroundColor: const Color(0xFF0A2740),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Đặt lại form',
            onPressed: _resetForm,
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Xuất PDF A4 có dấu Verified',
            onPressed: _isExporting ? null : _exportPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Thẻ Kết quả năng suất tổng quan (Hero Dashboard Card)
                _buildResultDashboard(calcData, numberFmt, tonFmt),
                const SizedBox(height: 20),

                // 2. Thẻ Thông tin chung (Khách hàng, Nguyên liệu, Ghi chú)
                _buildGeneralInfoCard(),
                const SizedBox(height: 20),

                // 3. Thẻ Nhập khối lượng & Thời gian đo
                _buildMeasurementInputCard(),
                const SizedBox(height: 24),

                // 4. Nút hành động Xuất PDF A4
                _buildActionButtons(calcData),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultDashboard(
    ProductivityCalcData data,
    NumberFormat numberFmt,
    NumberFormat tonFmt,
  ) {
    final hasValidData = data.weightKg > 0 && data.totalSeconds > 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF0A2740),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF148147),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.speed_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KẾT QUẢ NĂNG SUẤT TÍNH TOÁN',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Quy chuẩn tự động theo giờ & ngày',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: Color(0xFF4CAF50), size: 16),
                      const SizedBox(width: 5),
                      Text(
                        'DTC Verified',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 28),

            // Các chỉ số năng suất
            Row(
              children: [
                Expanded(
                  child: _buildMetricBlock(
                    label: 'NĂNG SUẤT / GIỜ',
                    value: hasValidData ? numberFmt.format(data.kgPerHour) : '0.0',
                    unit: 'Kg / Giờ',
                    highlightColor: const Color(0xFF5CD29A),
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.white24),
                Expanded(
                  child: _buildMetricBlock(
                    label: 'QUY ĐỔI TẤN',
                    value: hasValidData ? tonFmt.format(data.tonPerHour) : '0.00',
                    unit: 'Tấn / Giờ',
                    highlightColor: const Color(0xFFFFD54F),
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.white24),
                Expanded(
                  child: _buildMetricBlock(
                    label: 'ƯỚC TÍNH 24H',
                    value: hasValidData ? numberFmt.format(data.tonPerDay) : '0.0',
                    unit: 'Tấn / Ngày',
                    highlightColor: const Color(0xFF81D4FA),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBlock({
    required String label,
    required String value,
    required String unit,
    required Color highlightColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              color: highlightColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        Text(
          unit,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildGeneralInfoCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_pin_outlined, color: Color(0xFF148147), size: 22),
                SizedBox(width: 8),
                Text(
                  'Thông tin',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: 'Tên Khách Hàng / Nhà Máy',
                hintText: 'Ví dụ: Nhà máy xay xát Tân Phát...',
                prefixIcon: const Icon(Icons.business_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _materialController,
              decoration: InputDecoration(
                labelText: 'Tên Nguyên Liệu',
                hintText: 'Ví dụ: Gạo Jasmine, Cà phê Robusta, Tiêu đen...',
                prefixIcon: const Icon(Icons.grain_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Ghi Chú Thêm (Dòng máy, chế độ, thông số cài đặt)',
                hintText: 'Ví dụ: Máy 5 máng, áp suất 3.5 bar, chạy chế độ tách hạt vàng...',
                prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementInputCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer_outlined, color: Color(0xFF148147), size: 22),
                SizedBox(width: 8),
                Text(
                  'Thông số khối lượng và thời gian đếm giờ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2740)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ô nhập khối lượng
            Text(
              '1. Khối lượng mẫu cân đã hứng được (kg):',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Nhập số kg...',
                      suffixText: 'kg',
                      prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Các chip chọn nhanh khối lượng
                ...[5, 10, 20, 50].map(
                  (kg) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ActionChip(
                      label: Text('$kg kg', style: const TextStyle(fontSize: 12)),
                      onPressed: () => _weightController.text = '$kg',
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ô chọn thời gian
            Text(
              '2. Thời gian đo đạc thực tế:',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13.5),
            ),
            const SizedBox(height: 10),

            // Khung đồng hồ bấm giờ trực tiếp tại chỗ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF9),
                border: Border.all(color: const Color(0xFFBFE5D2)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.timer, color: Color(0xFF148147), size: 18),
                          SizedBox(width: 6),
                          Text(
                            'BẤM GIỜ TRỰC TIẾP TẠI ĐÂY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF148147),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isStopwatchActive ? Colors.green.shade100 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isStopwatchActive ? 'Đang bấm giờ...' : 'Sẵn sàng',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isStopwatchActive ? Colors.green.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatStopwatchTime(_stopwatchElapsedSeconds),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Color(0xFF0A2740),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (!_isStopwatchActive)
                        ElevatedButton.icon(
                          onPressed: _startStopwatch,
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(_stopwatchElapsedSeconds > 0 ? 'Tiếp tục' : 'Bắt đầu bấm giờ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF148147),
                            foregroundColor: Colors.white,
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: _pauseStopwatch,
                          icon: const Icon(Icons.pause_rounded, size: 18),
                          label: const Text('Tạm dừng'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _stopwatchElapsedSeconds > 0 ? _resetStopwatch : null,
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const Text('Đặt lại'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _stopwatchElapsedSeconds > 0 ? _applyStopwatchToInputs : null,
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Áp dụng thời gian này'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2740),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Nhập tay thông số Giờ / Phút / Giây
            Text(
              'Hoặc tự nhập tay thông số thời gian:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Giờ',
                      suffixText: 'giờ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Phút',
                      suffixText: 'phút',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _secondsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Giây',
                      suffixText: 'giây',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ProductivityCalcData data) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isExporting ? null : _exportPdf,
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 22),
            label: const Text(
              'Xuất phiếu PDF',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF148147),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}
