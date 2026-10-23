import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/technical_dictionary/repositories/technical_dictionary_repository.dart';
import '../providers/settings_provider.dart';
import '../services/daily_goal_notification_service.dart';
import '../services/note_notification_service.dart';
import '../theme/dtc_palette.dart';
import '../widgets/home_personalization_widget.dart';

const _displayNameMaxLength = 30;
const _shortTextMaxLength = 60;

const _nameFontSizeRange = (min: 12.0, max: 28.0);
const _shortTextFontSizeRange = (min: 16.0, max: 40.0);
const _dailyGoalsFontSizeRange = (min: 12.0, max: 24.0);

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

class _HomePersonalizationScreenState extends State<HomePersonalizationScreen> {
  late bool _enabled;
  late double _nameFontSize;
  late Color? _nameColor;
  late bool _nameItalic;
  late double _shortTextFontSize;
  late Color? _shortTextColor;
  late bool _shortTextItalic;
  late bool _dailyGoalsEnabled;
  late double _dailyGoalsFontSize;
  late Color? _dailyGoalsColor;
  late bool _dailyGoalsItalic;
  late bool _dailyGoalsReminderEnabled;
  late int _dailyGoalsReminderHour;
  late int _dailyGoalsReminderMinute;
  late bool _dailyWordEnabled;
  late DailyWordMode _dailyWordMode;
  late Set<String> _dailyWordGroups;
  late bool _dailyWordReview;

  /// Danh sách nhóm máy lấy từ Từ điển chuyên ngành (đúng thứ tự trong Excel).
  late final Future<List<String>> _dictionaryGroups =
      TechnicalDictionaryRepository().loadDictionary().then((d) => d.groups);
  late final TextEditingController _nameController;
  late final TextEditingController _shortTextController;
  late final TextEditingController _dailyGoalsTitleController;

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
    _dailyGoalsEnabled = settings.homeDailyGoalsEnabled;
    _dailyGoalsFontSize = settings.homeDailyGoalsFontSize;
    _dailyGoalsColor = settings.homeDailyGoalsColor;
    _dailyGoalsItalic = settings.homeDailyGoalsItalic;
    _dailyGoalsReminderEnabled = settings.homeDailyGoalsReminderEnabled;
    _dailyGoalsReminderHour = settings.homeDailyGoalsReminderHour;
    _dailyGoalsReminderMinute = settings.homeDailyGoalsReminderMinute;
    _dailyWordEnabled = settings.homeDailyWordEnabled;
    _dailyWordMode = settings.homeDailyWordMode;
    _dailyWordGroups = {...settings.homeDailyWordGroups};
    _dailyWordReview = settings.homeDailyWordReviewLearned;
    _nameController = TextEditingController(text: settings.homeDisplayName)
      ..addListener(() => setState(() {}));
    _shortTextController = TextEditingController(text: settings.homeShortText)
      ..addListener(() => setState(() {}));
    _dailyGoalsTitleController = TextEditingController(
      text: settings.homeDailyGoalsTitle,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortTextController.dispose();
    _dailyGoalsTitleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final reminderActive = _dailyGoalsEnabled && _dailyGoalsReminderEnabled;
    if (reminderActive) {
      final granted = await NoteNotificationService.requestPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa cấp quyền thông báo nên nhắc nhở có thể không hiển thị.',
            ),
          ),
        );
      }
    }

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
      dailyGoalsEnabled: _dailyGoalsEnabled,
      dailyGoalsTitle: _dailyGoalsTitleController.text,
      dailyGoalsFontSize: _dailyGoalsFontSize,
      dailyGoalsColor: _dailyGoalsColor,
      dailyGoalsColorIsSet: true,
      dailyGoalsItalic: _dailyGoalsItalic,
      dailyGoalsReminderEnabled: _dailyGoalsReminderEnabled,
      dailyGoalsReminderHour: _dailyGoalsReminderHour,
      dailyGoalsReminderMinute: _dailyGoalsReminderMinute,
      dailyWordEnabled: _dailyWordEnabled,
      dailyWordMode: _dailyWordMode,
      dailyWordGroups: _dailyWordGroups.toList(),
      dailyWordReviewLearned: _dailyWordReview,
    );
    if (reminderActive) {
      await DailyGoalNotificationService.scheduleDailyReminder(
        hour: _dailyGoalsReminderHour,
        minute: _dailyGoalsReminderMinute,
      );
    } else {
      await DailyGoalNotificationService.cancelDailyReminder();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã cập nhật trang chủ')));
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _dailyGoalsReminderHour,
        minute: _dailyGoalsReminderMinute,
      ),
      helpText: 'Chọn giờ nhắc',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dailyGoalsReminderHour = picked.hour;
      _dailyGoalsReminderMinute = picked.minute;
    });
  }

  String _formatReminderTime() =>
      '${_dailyGoalsReminderHour.toString().padLeft(2, '0')}:'
      '${_dailyGoalsReminderMinute.toString().padLeft(2, '0')}';

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
    await DailyGoalNotificationService.cancelDailyReminder();
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _nameFontSize = SettingsProvider.defaultHomeNameFontSize;
      _nameColor = null;
      _nameItalic = false;
      _shortTextFontSize = SettingsProvider.defaultHomeShortTextFontSize;
      _shortTextColor = null;
      _shortTextItalic = false;
      _dailyGoalsEnabled = false;
      _dailyGoalsFontSize = SettingsProvider.defaultHomeDailyGoalsFontSize;
      _dailyGoalsColor = null;
      _dailyGoalsItalic = false;
      _dailyGoalsReminderEnabled = false;
      _dailyGoalsReminderHour =
          SettingsProvider.defaultHomeDailyGoalsReminderHour;
      _dailyGoalsReminderMinute =
          SettingsProvider.defaultHomeDailyGoalsReminderMinute;
      _dailyWordEnabled = true;
      _dailyWordMode = DailyWordMode.perDay;
      _dailyWordGroups = {};
      _dailyWordReview = true;
      _nameController.text = '';
      _shortTextController.text = '';
      _dailyGoalsTitleController.text =
          SettingsProvider.defaultHomeDailyGoalsTitle;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã khôi phục mặc định')));
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
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _shortTextController,
                  maxLength: _shortTextMaxLength,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Dòng giới thiệu',
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
                  onChanged: (color) => setState(() => _shortTextColor = color),
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
            label: 'MỤC TIÊU HÔM NAY',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const Key('daily_goals_enabled_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị "Mục tiêu hôm nay"'),
                  subtitle: const Text(
                    'Tắt chỉ ẩn khỏi trang chủ, không xóa mục tiêu đã tạo',
                  ),
                  value: _dailyGoalsEnabled,
                  onChanged: (value) =>
                      setState(() => _dailyGoalsEnabled = value),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _dailyGoalsTitleController,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Tiêu đề hiển thị',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cỡ chữ - Tiêu đề',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                _FontSizeSlider(
                  value: _dailyGoalsFontSize,
                  min: _dailyGoalsFontSizeRange.min,
                  max: _dailyGoalsFontSizeRange.max,
                  onChanged: (value) =>
                      setState(() => _dailyGoalsFontSize = value),
                ),
                const SizedBox(height: 4),
                Text(
                  'Màu chữ - Tiêu đề',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                _ColorSwatchRow(
                  selected: _dailyGoalsColor,
                  onChanged: (color) =>
                      setState(() => _dailyGoalsColor = color),
                ),
                SwitchListTile(
                  key: const Key('daily_goals_italic_switch'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('In nghiêng'),
                  value: _dailyGoalsItalic,
                  onChanged: (value) =>
                      setState(() => _dailyGoalsItalic = value),
                ),
                const Divider(height: 28),
                SwitchListTile(
                  key: const Key('daily_goals_reminder_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nhắc nhở cuối ngày'),
                  subtitle: Text(
                    _dailyGoalsReminderEnabled
                        ? 'Nhắc lúc ${_formatReminderTime()} mỗi ngày'
                        : 'Thông báo nhắc kiểm tra mục tiêu vào 1 giờ cố định',
                  ),
                  value: _dailyGoalsReminderEnabled,
                  onChanged: (value) =>
                      setState(() => _dailyGoalsReminderEnabled = value),
                ),
                if (_dailyGoalsReminderEnabled)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Giờ nhắc'),
                    subtitle: Text(_formatReminderTime()),
                    trailing: TextButton(
                      key: const Key('daily_goals_reminder_time_button'),
                      onPressed: _pickReminderTime,
                      child: const Text('Đổi giờ'),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Section(
            label: 'TỪ VỰNG HÔM NAY',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const Key('daily_word_enabled_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiển thị "Từ vựng hôm nay"'),
                  subtitle: const Text(
                    'Học thụ động một thuật ngữ trong Từ điển chuyên ngành',
                  ),
                  value: _dailyWordEnabled,
                  onChanged: (value) =>
                      setState(() => _dailyWordEnabled = value),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đổi từ',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                SegmentedButton<DailyWordMode>(
                  key: const Key('daily_word_mode'),
                  segments: [
                    for (final mode in DailyWordMode.values)
                      ButtonSegment(value: mode, label: Text(mode.label)),
                  ],
                  selected: {_dailyWordMode},
                  onSelectionChanged: _dailyWordEnabled
                      ? (value) => setState(() => _dailyWordMode = value.first)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nhóm máy ưu tiên',
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<String>>(
                  future: _dictionaryGroups,
                  builder: (context, snapshot) {
                    final groups = snapshot.data;
                    if (groups == null) {
                      return Text(
                        snapshot.hasError
                            ? 'Không tải được danh sách nhóm máy.'
                            : 'Đang tải nhóm máy…',
                        style: TextStyle(color: palette.muted, fontSize: 13),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final group in groups)
                          FilterChip(
                            key: Key('daily_word_group_$group'),
                            label: Text(group),
                            selected: _dailyWordGroups.contains(group),
                            onSelected: _dailyWordEnabled
                                ? (selected) => setState(
                                    () => selected
                                        ? _dailyWordGroups.add(group)
                                        : _dailyWordGroups.remove(group),
                                  )
                                : null,
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  _dailyWordGroups.isEmpty
                      ? 'Chưa chọn nhóm nào: lấy từ mọi nhóm máy.'
                      : 'Chỉ lấy từ trong ${_dailyWordGroups.length} nhóm đã chọn.',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  key: const Key('daily_word_review_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Thỉnh thoảng ôn lại từ đã thuộc'),
                  value: _dailyWordReview,
                  onChanged: _dailyWordEnabled
                      ? (value) => setState(() => _dailyWordReview = value)
                      : null,
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
          FilledButton(onPressed: _save, child: const Text('Lưu thay đổi')),
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
