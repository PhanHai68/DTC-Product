import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/fault_machine_model.dart';
import '../providers/fault_bank_provider.dart';
import '../widgets/fault_profile_form.dart';
import '../widgets/machine_model_dialogs.dart';

/// Cài đặt riêng của Ngân hàng lỗi: hồ sơ kỹ sư, danh mục dòng máy.
class FaultBankSettingsScreen extends StatelessWidget {
  const FaultBankSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final provider = context.watch<FaultBankProvider>();
    final profile = provider.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt Ngân hàng lỗi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  key: const Key('fault_settings_profile'),
                  leading: Icon(Icons.badge_outlined, color: palette.cyan),
                  title: const Text('Hồ sơ kỹ sư'),
                  subtitle: Text(
                    profile == null ? 'Chưa có' : profile.engineerName,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/fault-bank/profile'),
                ),
                const Divider(height: 1),
                ListTile(
                  key: const Key('fault_settings_models'),
                  leading: Icon(
                    Icons.label_outline_rounded,
                    color: palette.cyan,
                  ),
                  title: const Text('Danh mục model máy'),
                  subtitle: Text('${provider.machineModels.length} model máy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/fault-bank/machine-models'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cloud_off_rounded, size: 18, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dữ liệu và ảnh chỉ lưu trên máy này, không cần mạng. '
                  'Xóa ứng dụng sẽ mất dữ liệu — tính năng xuất file và sao '
                  'lưu sẽ có ở bản cập nhật sau.',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sửa hồ sơ kỹ sư.
class FaultProfileScreen extends StatelessWidget {
  const FaultProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ kỹ sư')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FaultProfileForm(
            onSaved: () {
              final messenger = ScaffoldMessenger.of(context);
              context.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('Đã lưu hồ sơ kỹ sư.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Danh mục dòng máy: thêm, sửa, xóa (chỉ khi chưa có bản ghi dùng).
class FaultMachineModelsScreen extends StatelessWidget {
  const FaultMachineModelsScreen({super.key});

  Future<void> _delete(BuildContext context, FaultMachineModel model) async {
    final provider = context.read<FaultBankProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final count = await provider.countRecordsOfModel(model.id);
    if (!context.mounted) return;
    if (count > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '"${model.name}" đang có $count bản ghi, không xóa được. '
            'Có thể sửa tên thay vì xóa.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa model máy?'),
        content: Text('Xóa "${model.name}" khỏi danh mục?'),
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
    await provider.deleteMachineModel(model.id);
    messenger.showSnackBar(SnackBar(content: Text('Đã xóa "${model.name}".')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final models = context.watch<FaultBankProvider>().machineModels;
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục model máy')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('fault_models_add'),
        onPressed: () => showMachineModelEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm model máy'),
      ),
      body: models.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Chưa có model máy nào.\nCó thể thêm ngay khi ghi nhận sự cố.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.muted),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: models.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final model = models[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(
                      Icons.label_outline_rounded,
                      color: palette.cyan,
                    ),
                    title: Text(
                      model.name,
                      style: TextStyle(
                        color: palette.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Tùy chọn',
                      onSelected: (value) => value == 'edit'
                          ? showMachineModelEditor(context, existing: model)
                          : _delete(context, model),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Sửa')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
