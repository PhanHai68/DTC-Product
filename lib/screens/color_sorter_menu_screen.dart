import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/technology_menu.dart';

const _installationDrawingUrl =
    'https://drive.google.com/drive/folders/1m1M3_H8M5pAoN4K3lQjoRHk_iSgzf62v?usp=sharing';

class ColorSorterMenuScreen extends StatelessWidget {
  const ColorSorterMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Máy tách màu Gạo',
      entries: [
        TechnologyMenuEntry(
          id: 'color_sorter_specs_btn',
          title: 'Thông số kỹ thuật',
          icon: Icons.fact_check_outlined,
          featured: true,
          onTap: () => context.push('/color_sorter'),
        ),
        TechnologyMenuEntry(
          id: 'color_sorter_aux_btn',
          title: 'Thiết bị phụ trợ',
          icon: Icons.settings_outlined,
          onTap: () => context.push('/aux_equip'),
        ),
        TechnologyMenuEntry(
          id: 'color_sorter_payback_btn',
          title: 'Phân tích hoàn vốn',
          icon: Icons.query_stats_rounded,
          onTap: () => context.push('/payback_analysis'),
        ),
        TechnologyMenuEntry(
          id: 'color_sorter_drawing_btn',
          title: 'Bản vẽ lắp đặt',
          icon: Icons.architecture_rounded,
          onTap: () => _showDrawingDialog(context),
        ),
        TechnologyMenuEntry(
          id: 'color_sorter_errors_btn',
          title: 'Tra cứu lỗi',
          icon: Icons.troubleshoot_rounded,
          statusLabel: 'Sắp có',
        ),
        TechnologyMenuEntry(
          id: 'color_sorter_manual_btn',
          title: 'Tài liệu vận hành',
          icon: Icons.menu_book_rounded,
          onTap: () => context.push('/color_sorter_manual'),
        ),
      ],
    );
  }

  Future<void> _showDrawingDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.folder_shared_outlined,
          color: DtcPalette.cyan,
          size: 34,
        ),
        title: const Text(
          'Thư viện bản vẽ lắp đặt',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Text(
            'Tài liệu được lưu trên Google Drive. Bạn có thể mở thư viện để xem hoặc sao chép liên kết để chia sẻ.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DtcPalette.muted, height: 1.45),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _installationDrawingUrl),
              );
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép liên kết')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Sao chép'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final opened = await launchUrl(
                  Uri.parse(_installationDrawingUrl),
                  mode: LaunchMode.externalApplication,
                );
                if (!opened && dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Không thể mở Google Drive trên thiết bị này.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Không thể mở liên kết. Vui lòng thử lại.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Mở thư viện'),
          ),
        ],
      ),
    );
  }
}
