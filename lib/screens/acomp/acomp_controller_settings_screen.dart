import 'package:flutter/material.dart';

/// Tham số cài đặt một bộ điều khiển (DS8011, CT8893D…): mỗi danh mục một thẻ
/// mở rộng, mỗi tham số gồm mã, mô tả, giá trị / dải cài đặt. Danh mục có thể
/// kèm ghi chú (`note`) hiện ở đầu thẻ.
class AcompControllerSettingsScreen extends StatelessWidget {
  const AcompControllerSettingsScreen({
    super.key,
    required this.title,
    required this.categories,
  });

  final String title;

  /// Mỗi phần tử: `category`, `note` (tuỳ chọn), `items` (`code`, `value`,
  /// `description`).
  final List<Map<String, dynamic>> categories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final categoryData = categories[index];
          final category = categoryData['category'] as String;
          final note = categoryData['note'] as String?;
          final items = categoryData['items'] as List<dynamic>;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ExpansionTile(
              initiallyExpanded: index == 0,
              title: Text(
                category,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
              children: [
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      note,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ...items.map((item) {
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          radius: 24,
                          // Mã dài (vd "Quạt", "▲▼") tự co cho vừa vòng tròn.
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item['code'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          item['description'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            item['value'],
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (item != items.last)
                        const Divider(height: 1, indent: 70),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
