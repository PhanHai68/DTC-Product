import 'package:flutter/material.dart';

import '../../data/acomp_common_errors_data.dart';

class AcompCommonErrorsScreen extends StatefulWidget {
  const AcompCommonErrorsScreen({super.key});

  @override
  State<AcompCommonErrorsScreen> createState() =>
      _AcompCommonErrorsScreenState();
}

class _AcompCommonErrorsScreenState extends State<AcompCommonErrorsScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Các lỗi thường gặp'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.blue.shade700,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(vertical: 8),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.blue.shade600,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            tabs: const [
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Lỗi chung'),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Lỗi bộ điều khiển'),
                ),
              ),
              Tab(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Lỗi hao dầu'),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm lỗi...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildGeneralErrorsTab(),
                  _buildControllerErrorsTab(),
                  _buildOilLossErrorsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatText(String text) {
    if (text.isEmpty) return '';

    // Bảo vệ các phân số (ví dụ: 2/3) để không bị tách
    text = text.replaceAllMapped(
      RegExp(r'(\d)/(\d)'),
      (match) => '${match.group(1)}<SLASH>${match.group(2)}',
    );

    // Tách theo '/', '\n', hoặc '_'
    var parts = text.split(RegExp(r'[/_\n]'));
    List<String> formatted = [];

    for (var p in parts) {
      p = p.replaceAll('<SLASH>', '/');
      p = p.trim();
      if (p.isEmpty) continue;

      if (p.startsWith('-')) p = p.substring(1).trim();
      if (p.startsWith('+')) p = p.substring(1).trim();
      if (p.startsWith('_')) p = p.substring(1).trim();

      // Xóa các dấu câu thừa ở cuối câu (;, :, ,, .) để chuẩn hóa
      p = p.replaceAll(RegExp(r'[;:,.\s]+$'), '');

      if (p.isNotEmpty) {
        // Viết hoa chữ cái đầu tiên
        p = p[0].toUpperCase() + p.substring(1);
        // Luôn thêm một dấu chấm ở cuối
        formatted.add('- $p.');
      }
    }
    return formatted.join('\n');
  }

  Widget _buildGeneralErrorsTab() {
    var filtered = commonErrorsGeneral.where((e) {
      return e['error']!.toLowerCase().contains(searchQuery) ||
          e['solution']!.toLowerCase().contains(searchQuery);
    }).toList();

    // Group by error name
    Map<String, List<Map<String, String>>> grouped = {};
    for (var item in filtered) {
      String key = item['error']!;
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(item);
    }
    var keys = grouped.keys.toList();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        var key = keys[index];
        var items = grouped[key]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Kiểm tra / Khắc phục:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_formatText(item['solution']!)),
                    if (item != items.last) const Divider(height: 32),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildControllerErrorsTab() {
    var filtered = commonErrorsController.where((e) {
      return e['mainError']!.toLowerCase().contains(searchQuery) ||
          e['description']!.toLowerCase().contains(searchQuery) ||
          e['solution']!.toLowerCase().contains(searchQuery);
    }).toList();

    // Group by mainError
    Map<String, List<Map<String, String>>> grouped = {};
    for (var item in filtered) {
      String key = item['mainError']!.isNotEmpty
          ? item['mainError']!
          : 'Lỗi liên quan';
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(item);
    }
    var keys = grouped.keys.toList();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        var key = keys[index];
        var items = grouped[key]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item['description']!.isNotEmpty) ...[
                      const Text(
                        'Mô tả / Nguyên nhân:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_formatText(item['description']!)),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Khắc phục:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_formatText(item['solution']!)),
                    if (item != items.last) const Divider(height: 32),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildOilLossErrorsTab() {
    var filtered = commonErrorsOilLoss.where((e) {
      return e['cause']!.toLowerCase().contains(searchQuery) ||
          e['explanation']!.toLowerCase().contains(searchQuery) ||
          e['solution']!.toLowerCase().contains(searchQuery);
    }).toList();

    // Group by cause
    Map<String, List<Map<String, String>>> grouped = {};
    for (var item in filtered) {
      String key = item['cause']!;
      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(item);
    }
    var keys = grouped.keys.toList();

    return ListView.builder(
      itemCount: keys.length,
      itemBuilder: (context, index) {
        var key = keys[index];
        var items = grouped[key]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text(
              key,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (item['explanation']!.isNotEmpty) ...[
                      const Text(
                        'Giải thích:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_formatText(item['explanation']!)),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Cách khắc phục:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_formatText(item['solution']!)),
                    if (item != items.last) const Divider(height: 32),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
