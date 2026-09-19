import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  Future<void> _clearSearchHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa lịch sử tìm kiếm?'),
        content: const Text(
          'Các mục "Đã mở gần đây" ở màn Tra cứu nhanh sẽ bị xóa khỏi thiết bị này.',
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
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('global_search_recent_locations');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã xóa lịch sử tìm kiếm.')));
  }

  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
    ThemeMode.system => 'Theo hệ thống',
  };

  IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
    ThemeMode.system => Icons.brightness_auto_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Giao diện',
            child: RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (value) {
                if (value != null) settings.setThemeMode(value);
              },
              child: Column(
                children: ThemeMode.values.map((mode) {
                  return RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(_themeModeIcon(mode)),
                    title: Text(_themeModeLabel(mode)),
                    value: mode,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            icon: Icons.text_fields_rounded,
            title: 'Cỡ chữ',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<AppTextScale>(
                  segments: AppTextScale.values
                      .map(
                        (scale) => ButtonSegment(
                          value: scale,
                          label: Text(scale.label),
                        ),
                      )
                      .toList(),
                  selected: {settings.textScale},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    settings.setTextScale(selection.first);
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Ví dụ: Máy tách màu SC16 Pro',
                  style: TextStyle(fontSize: 16 * settings.textScale.scale),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            icon: Icons.storage_outlined,
            title: 'Dữ liệu',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Xóa lịch sử tìm kiếm gần đây'),
              subtitle: const Text(
                'Xóa các mục "Đã mở gần đây" ở Tra cứu nhanh',
              ),
              onTap: _clearSearchHistory,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            icon: Icons.info_outline_rounded,
            title: 'Thông tin ứng dụng',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.apps_rounded),
              title: const Text('DTC Product'),
              subtitle: Text(
                _packageInfo == null
                    ? 'Đang tải...'
                    : 'Phiên bản ${_packageInfo!.version} (build ${_packageInfo!.buildNumber})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
