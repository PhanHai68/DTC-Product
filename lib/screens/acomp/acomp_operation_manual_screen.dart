import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/acomp_manual_data.dart';

class AcompOperationManualScreen extends StatelessWidget {
  const AcompOperationManualScreen({super.key});

  Future<void> _openOriginalPdf() async {
    final Uri url = Uri.parse('assets/docs/HUONG_DAN_VAN_HANH_5.pdf');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch \$url');
    }
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'play_circle_outline':
        return Icons.play_circle_outline;
      case 'build_circle_outlined':
        return Icons.build_circle_outlined;
      case 'warning_amber_rounded':
        return Icons.warning_amber_rounded;
      case 'inventory_2_outlined':
        return Icons.inventory_2_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài liệu vận hành (Rút gọn)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Mở PDF gốc',
            onPressed: _openOriginalPdf,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: 80,
        ), // bottom padding for FAB
        itemCount: manualSummary.length,
        itemBuilder: (context, index) {
          final section = manualSummary[index];
          final items = section['items'] as List<String>;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              leading: Icon(
                _getIcon(section['icon']),
                color: Colors.blue,
                size: 28,
              ),
              title: Text(
                section['title'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openOriginalPdf,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Xem file PDF chi tiết'),
      ),
    );
  }
}
