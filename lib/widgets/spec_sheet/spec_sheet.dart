import 'package:flutter/material.dart';

/// Bộ khung giao diện trang "Thông số kỹ thuật" dùng chung — sao đúng kiểu
/// dáng/màu sắc của trang máy tách màu SC16 Pro
/// (lib/screens/color_sorter/color_sorter_screen.dart) để các chức năng sản
/// phẩm khác (máy nghiền...) nhìn thống nhất với máy tách màu.
///
/// Màu ở đây cố ý dùng hằng số giống trang máy tách màu, không dùng
/// DtcPalette, để 2 chức năng hiển thị y hệt nhau.

/// Thanh chip chọn model ở đầu trang. Tự cuộn để chip đang chọn luôn nằm
/// trong tầm nhìn (dòng máy nhiều model, mở model cuối danh sách).
class SpecModelChipBar extends StatefulWidget {
  const SpecModelChipBar({
    super.key,
    required this.models,
    required this.selected,
    required this.onSelected,
    this.keyPrefix = 'spec_model_chip_',
  });

  final List<String> models;
  final String selected;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  @override
  State<SpecModelChipBar> createState() => _SpecModelChipBarState();
}

class _SpecModelChipBarState extends State<SpecModelChipBar> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(SpecModelChipBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _revealSelected(animate: true);
  }

  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chipContext = _selectedKey.currentContext;
      if (!mounted || chipContext == null) return;
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.5,
        duration: animate ? const Duration(milliseconds: 250) : Duration.zero,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final models = widget.models;
    final selected = widget.selected;
    final keyPrefix = widget.keyPrefix;
    final onSelected = widget.onSelected;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      width: double.infinity,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: models.map((m) {
            final isSelected = m.toLowerCase() == selected.toLowerCase();
            return Padding(
              key: isSelected ? _selectedKey : null,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: FilterChip(
                key: Key('$keyPrefix$m'),
                selected: isSelected,
                label: Text(m),
                selectedColor: Colors.blue.shade800,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? Colors.blue.shade800
                        : Colors.grey.shade300,
                  ),
                ),
                onSelected: (_) => onSelected(m),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Tiêu đề lớn giữa trang, VD "MÁY NGHIỀN AS-180".
class SpecTitle extends StatelessWidget {
  const SpecTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade900,
      ),
    );
  }
}

/// Khung ảnh máy: chạm để phóng to, nhãn "Mô hình 3D" (tuỳ chọn) góc trên.
class SpecImageCard extends StatelessWidget {
  const SpecImageCard({
    super.key,
    required this.imagePath,
    required this.zoomTitle,
    this.on3dTap,
    this.caption,
  });

  final String imagePath;

  /// Tiêu đề hiện trên ảnh khi phóng to.
  final String zoomTitle;
  final VoidCallback? on3dTap;

  /// Dòng chú thích nhỏ góc trái dưới (VD "Ảnh đại diện: ASP-350").
  final String? caption;

  void _showZoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: Image.asset(imagePath, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  zoomTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                tooltip: 'Đóng ảnh',
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showZoom(context),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(imagePath, fit: BoxFit.contain),
              ),
            ),
            if (on3dTap != null)
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: on3dTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade800, Colors.indigo.shade800],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.threed_rotation,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Mô hình 3D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (caption != null)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    caption!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Chạm để phóng to',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nút "Xem Mô Hình 3D 360°" dưới khung ảnh.
class Spec3dButton extends StatelessWidget {
  const Spec3dButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.view_in_ar, size: 20),
      label: Text(label ?? 'Xem Mô Hình 3D 360°'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Thẻ chỉ số nổi bật (dùng trong Row, tự Expanded).
class SpecHighlightCard extends StatelessWidget {
  const SpecHighlightCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip công nghệ / nhãn nhiều màu. Bảng màu xoay vòng giống máy tách màu.
class SpecTechChip extends StatelessWidget {
  const SpecTechChip({
    super.key,
    required this.text,
    required this.color,
    this.onPressed,
  });

  static const palette = <MaterialColor>[
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.teal,
    Colors.brown,
  ];

  final String text;
  final MaterialColor color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: color.shade800,
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );
    final background = color.shade50.withValues(alpha: 0.6);
    final side = BorderSide(color: color.shade200, width: 0.8);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    if (onPressed == null) {
      return Chip(
        label: Text(text),
        labelStyle: labelStyle,
        backgroundColor: background,
        side: side,
        shape: shape,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      );
    }
    return ActionChip(
      onPressed: onPressed,
      label: Text(text),
      labelStyle: labelStyle,
      backgroundColor: background,
      side: side,
      shape: shape,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }
}

/// Nhóm chip căn giữa, tự xoay vòng màu.
class SpecChipWrap extends StatelessWidget {
  const SpecChipWrap({super.key, required this.labels, this.onPressed});

  final List<String> labels;
  final ValueChanged<String>? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 6.0,
        runSpacing: 6.0,
        children: [
          for (var i = 0; i < labels.length; i++)
            SpecTechChip(
              text: labels[i],
              color: SpecTechChip.palette[i % SpecTechChip.palette.length],
              onPressed: onPressed == null ? null : () => onPressed!(labels[i]),
            ),
        ],
      ),
    );
  }
}

/// Nút gradient xanh "Chi Tiết Ứng Dụng".
class SpecGradientButton extends StatelessWidget {
  const SpecGradientButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.amberAccent,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white70,
              size: 12,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn mục có vạch xanh bên trái, VD "Thông số chi tiết".
class SpecSectionLabel extends StatelessWidget {
  const SpecSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh tab dạng viên thuốc. Nhãn có thể chứa "\n" để xuống 2 dòng.
class SpecPillTabBar extends StatelessWidget {
  const SpecPillTabBar({
    super.key,
    required this.controller,
    required this.labels,
  });

  final TabController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3F5)),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade900.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.blueGrey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.08,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          height: 1.08,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: [
          for (final label in labels)
            Tab(height: 48, child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Khung trắng chứa các dòng thông số của 1 tab.
class SpecRowsCard extends StatelessWidget {
  const SpecRowsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// Thông báo rỗng bên trong [SpecRowsCard].
class SpecEmptyRows extends StatelessWidget {
  const SpecEmptyRows(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// 1 dòng thông số: icon màu + nhãn + ô giá trị màu. Giá trị dài/nhiều dòng
/// tự chuyển xuống dưới nhãn để không bị bó hẹp.
class SpecRow extends StatelessWidget {
  const SpecRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool showDivider;

  static const _labelStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 13,
    color: Color(0xFF1A1A2E),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _buildRow(context, constraints.maxWidth),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.6,
            indent: 60,
            endIndent: 16,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }

  /// Chọn bố cục theo bề rộng chữ thật (không đếm ký tự):
  /// 1. Vừa ô giá trị nửa hàng → nhãn / giá trị chia đôi như các dòng khác.
  /// 2. Không vừa nửa hàng nhưng nhãn + giá trị vẫn vừa 1 hàng → ô giá trị
  ///    nới theo nội dung, vẫn nằm cùng hàng, canh phải với các ô khác.
  /// 3. Không vừa nữa → chuyển xuống dưới nhãn, trải hết chiều ngang.
  Widget _buildRow(BuildContext context, double maxWidth) {
    final valueStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: color,
      height: 1.3,
    );
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final lines = value.split('\n');
    final valueTextWidth = lines
        .map((l) => measure(l, valueStyle))
        .reduce((a, b) => a > b ? a : b);
    // 10px padding mỗi bên + viền 1px mỗi bên + 2px dư làm tròn.
    final pillWidth = valueTextWidth + 24;
    // Phần còn lại sau icon (34) + khoảng cách (11) + khe nhãn/giá trị (8).
    final rest = maxWidth - 34 - 11 - 8;
    final labelWidth = measure(label, _labelStyle);
    final fitsHalf = lines.length <= 2 && pillWidth <= rest / 2;
    final fitsHug =
        lines.length <= 2 &&
        pillWidth <= rest - (labelWidth < rest * 0.4 ? labelWidth : rest * 0.4);
    final isLong = !fitsHalf && !fitsHug;

    final iconBox = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 17, color: color),
    );
    final labelText = Text(label, style: _labelStyle);
    final valueBox = Container(
      width: isLong ? double.infinity : null,
      padding: EdgeInsets.symmetric(
        horizontal: isLong ? 12 : 10,
        vertical: isLong ? 8 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(isLong ? 12 : 16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(value, textAlign: TextAlign.center, style: valueStyle),
    );

    if (isLong) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              iconBox,
              const SizedBox(width: 11),
              Expanded(child: labelText),
            ],
          ),
          const SizedBox(height: 8),
          valueBox,
        ],
      );
    }
    return Row(
      children: [
        iconBox,
        const SizedBox(width: 11),
        if (fitsHalf) ...[
          Expanded(flex: 5, child: labelText),
          const SizedBox(width: 8),
          Expanded(flex: 5, child: valueBox),
        ] else ...[
          Expanded(child: labelText),
          const SizedBox(width: 8),
          valueBox,
        ],
      ],
    );
  }
}

/// Khối teal có tiêu đề + nút viền (giống "Thiết bị phụ trợ đồng bộ").
class SpecCtaBlock extends StatelessWidget {
  const SpecCtaBlock({
    super.key,
    required this.title,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
    this.description,
    this.buttonIcon = Icons.open_in_new,
    this.buttonKey,
  });

  final String title;
  final IconData icon;
  final String? description;
  final String buttonLabel;
  final IconData buttonIcon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.teal.shade800, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                description!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Colors.teal.shade900.withValues(alpha: 0.8),
                ),
              ),
            ),
          Divider(
            height: 16,
            thickness: 0.7,
            indent: 14,
            endIndent: 14,
            color: Colors.teal.shade200,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: OutlinedButton.icon(
              key: buttonKey,
              onPressed: onPressed,
              icon: Icon(buttonIcon, size: 16, color: Colors.teal.shade800),
              label: Text(
                buttonLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.teal.shade800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 16,
                ),
                side: BorderSide(color: Colors.teal.shade400, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút đặc indigo toàn chiều ngang (giống "Phân tích hoàn vốn (ROI)").
class SpecPrimaryButton extends StatelessWidget {
  const SpecPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Khối "Chia sẻ thông số cho khách hàng" với 2 nút text / PDF.
class SpecShareSection extends StatelessWidget {
  const SpecShareSection({
    super.key,
    required this.onShare,
    this.textButtonKey,
    this.pdfButtonKey,
  });

  final VoidCallback onShare;
  final Key? textButtonKey;
  final Key? pdfButtonKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ios_share_rounded, color: Color(0xFF168052), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chia sẻ thông số cho khách hàng',
                  style: TextStyle(
                    color: Color(0xFF102F46),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: textButtonKey,
                  onPressed: onShare,
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Chia sẻ text'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: pdfButtonKey,
                  onPressed: onShare,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                  label: const Text('Xuất PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại nội dung chi tiết (tiêu đề + các mục có màu), dùng cho
/// "Chi Tiết Ứng Dụng".
Future<void> showSpecDetailDialog({
  required BuildContext context,
  required String title,
  required List<SpecDetailSection> sections,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.green.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < sections.length; i++)
              _SpecDetailCard(
                section: sections[i],
                style: _detailStyles[i % _detailStyles.length],
              ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            'Đóng',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class SpecDetailSection {
  const SpecDetailSection({
    required this.emoji,
    required this.title,
    required this.content,
  });

  final String emoji;
  final String title;
  final String content;
}

// Cùng bộ màu 4 thẻ "Chi tiết ứng dụng" của máy tách màu.
const _detailStyles = <(Color card, Color border, Color title)>[
  (Color(0xFFEFF6FF), Color(0xFFBFDBFE), Color(0xFF1D4ED8)),
  (Color(0xFFF0FDF4), Color(0xFFBBF7D0), Color(0xFF15803D)),
  (Color(0xFFFFF7ED), Color(0xFFFED7AA), Color(0xFFC2410C)),
  (Color(0xFFFAF5FF), Color(0xFFE9D5FF), Color(0xFF7E22CE)),
];

class _SpecDetailCard extends StatelessWidget {
  const _SpecDetailCard({required this.section, required this.style});

  final SpecDetailSection section;
  final (Color, Color, Color) style;

  @override
  Widget build(BuildContext context) {
    final (cardColor, borderColor, titleColor) = style;
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(section.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            section.content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
