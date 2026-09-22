import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/dtc_palette.dart';
import '../widgets/home_personalization_widget.dart';

const _displayNameMaxLength = 30;
const _shortTextMaxLength = 60;

const _nameFontSizeRange = (min: 10.0, max: 20.0);
const _shortTextFontSizeRange = (min: 14.0, max: 30.0);

/// Bảng màu gợi ý cho chữ trên Home — giữ đơn giản (không cần color wheel),
/// phần tử đầu (null) nghĩa là dùng màu mặc định theo theme sáng/tối.
const _colorPresets = <Color?>[
  null,
  Color(0xFF0A2740),
  Color(0xFF148147),
  Color(0xFF00A6A6),
  Color(0xFFEA580C),
  Color(0xFFDC2626),
  Color(0xFF7C3AED),
  Color(0xFF111827),
];

/// Màn hình "Cá nhân hóa trang chủ" — chỉnh sửa được lưu nháp cục bộ (chưa
/// ghi vào SettingsProvider) và chỉ áp dụng vào Home khi bấm "Lưu thay đổi",
/// để khu vực Xem trước phản ánh đúng thay đổi trước khi người dùng chốt.
class HomePersonalizationScreen extends StatefulWidget {
  const HomePersonalizationScreen({super.key});

  @override
  State<HomePersonalizationScreen> createState() =>
      _HomePersonalizationScreenState();
}

class _HomePersonalizationScreenState
    extends State<HomePersonalizationScreen> {
  late bool _enabled;
  late double _nameFontSize;
  late Color? _nameColor;
  late bool _nameItalic;
  late double _shortTextFontSize;
  late Color? _shortTextColor;
  late bool _shortTextItalic;
  late final TextEditingController _nameController;
  late final TextEditingController _shortTextController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _enabled = settings.homePersonalizationEnabled;
    _nameFontSize = settings.homeNameFontSize;
    _nameColor = settings.homeNameColor;
    _nameItalic = settings.homeNameItalic;
    _shortTextFontSize = settings.homeShortTextFontSize;
    _shortTextColor = settings.homeShortTextColor;
    _shortTextItalic = settings.homeShortTextItalic;
    _nameController = TextEditingController(text: settings.homeDisplayName)
      ..addListener(() => setState(() {}));
    _shortTextController =
        TextEditingController(text: settings.homeShortText)
          ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortTextController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await context.read<SettingsProvider>().saveHomePersonalization(
      enabled: _enabled,
      displayName: _nameController.text.trim(),
      shortText: _shortTextController.text.trim(),
      nameFontSize: _nameFontSize,
      nameColor: _nameColor,
      nameItalic: _nameItalic,
      shortTextFontSize: _shortTextFontSize,
      shortTextColor: _shortTextColor,
      shortTextItalic: _shortTextItalic,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật trang chủ')),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Khôi phục mặc định?'),
        content: const Text(
          'Tên hiển thị và nội dung cá nhân hóa sẽ được xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Khôi phục'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SettingsProvider>().resetHomePersonalization();
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _nameFontSize = SettingsProvider.defaultHomeNameFontSize;
      _nameColor = null;
      _nameItalic = false;
      _shortTextFontSize = SettingsProvider.defaultHomeShortTextFontSize;
      _shortTextColor = null;
      _shortTextItalic = false;
      _nameController.text = '';
      _shortTextController.text = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã khôi phục mặc định')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final hasContent =
        _nameController.text.trim().isNotEmpty ||
        _shortTextController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân hóa trang chủ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Section(
            label: 'HIỂN THỊ',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hiển thị trên trang chủ'),
              subtitle: const Text(
                'Chỉ hiển thị trên thiết bị này, không liên quan tài khoản',
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            label: 'THÔNG TIN',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  maxLength: _displayNameMaxLength,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    hintText: 'VD: Kevin',
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _shortTextController,
                  maxLength: _shortTextMaxLength,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dòng giới thiệu',
                    hintText: 'VD: DTC Engineer',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            label: 'TÙY CHỈNH HIỂN THỊ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cỡ chữ - Tên hiển thị',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                _FontSizeSlider(
                  value: _nameFontSize,
                  min: _nameFontSizeRange.min,
                  max: _nameFontSizeRange.max,
                  onChanged: (value) => setState(() => _nameFontSize = value),
                ),
                const SizedBox(height: 4),
                Text(
                  'Màu chữ - Tên hiển thị',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                _ColorSwatchRow(
                  selected: _nameColor,
                  onChanged: (color) => setState(() => _nameColor = color),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('In nghiêng'),
                  value: _nameItalic,
                  onChanged: (value) => setState(() => _nameItalic = value),
                ),
                const Divider(height: 32),
                Text(
                  'Cỡ chữ - Dòng giới thiệu',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                _FontSizeSlider(
                  value: _shortTextFontSize,
                  min: _shortTextFontSizeRange.min,
                  max: _shortTextFontSizeRange.max,
                  onChanged: (value) =>
                      setState(() => _shortTextFontSize = value),
                ),
                const SizedBox(height: 4),
                Text(
                  'Màu chữ - Dòng giới thiệu',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                _ColorSwatchRow(
                  selected: _shortTextColor,
                  onChanged: (color) =>
                      setState(() => _shortTextColor = color),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('In nghiêng'),
                  value: _shortTextItalic,
                  onChanged: (value) =>
                      setState(() => _shortTextItalic = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            label: 'XEM TRƯỚC',
            child: !_enabled
                ? Text(
                    'Đang tắt — trang chủ sẽ dùng giao diện mặc định.',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  )
                : !hasContent
                ? Text(
                    'Chưa có nội dung để hiển thị.',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: HomePersonalizationPreview(
                      displayName: _nameController.text,
                      shortText: _shortTextController.text,
                      nameFontSize: _nameFontSize,
                      nameColor: _nameColor,
                      nameItalic: _nameItalic,
                      shortTextFontSize: _shortTextFontSize,
                      shortTextColor: _shortTextColor,
                      shortTextItalic: _shortTextItalic,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            child: const Text('Lưu thay đổi'),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _confirmReset,
              child: const Text('Khôi phục mặc định'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  const _FontSizeSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: '${clamped.round()} pt',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${clamped.round()} pt', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow({required this.selected, required this.onChanged});

  final Color? selected;
  final ValueChanged<Color?> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colorPresets.map((color) {
        final isSelected = color == null
            ? selected == null
            : selected != null && selected!.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color ?? Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? palette.cyan : palette.border,
                width: isSelected ? 2.4 : 1.2,
              ),
            ),
            child: color == null
                ? Icon(
                    Icons.format_color_reset_outlined,
                    size: 15,
                    color: palette.muted,
                  )
                : (isSelected
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null),
          ),
        );
      }).toList(),
    );
  }
}
