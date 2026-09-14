import 'package:flutter/material.dart';

import '../../data/acomp_ds8011_data.dart';

class AcompDs8011SettingsScreen extends StatelessWidget {
  const AcompDs8011SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tham số cài đặt DS8011')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ds8011Parameters.length,
        itemBuilder: (context, index) {
          var categoryData = ds8011Parameters[index];
          String category = categoryData['category'];
          List<dynamic> items = categoryData['items'];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
              children: items.map((item) {
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
                        child: Text(
                          item['code'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontSize: 16,
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
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
