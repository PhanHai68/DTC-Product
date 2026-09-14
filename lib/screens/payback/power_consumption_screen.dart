import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/power_consumption_provider.dart';
import '../../data/power_consumption_data.dart';

class PowerConsumptionScreen extends StatefulWidget {
  const PowerConsumptionScreen({super.key});

  @override
  _PowerConsumptionScreenState createState() => _PowerConsumptionScreenState();
}

class _PowerConsumptionScreenState extends State<PowerConsumptionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PowerConsumptionProvider(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Công Suất Tiêu Thụ')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<PowerConsumptionProvider>(
                builder: (context, provider, child) {
                  return Row(
                    children: [
                      Expanded(
                        child: DropdownMenu<String>(
                          controller: _searchController,
                          expandedInsets: EdgeInsets.zero,
                          label: const Text('Chọn tên model máy'),
                          enableFilter: true,
                          leadingIcon: const Icon(Icons.search),
                          dropdownMenuEntries: powerConsumptionData.keys
                              .map(
                                (modelName) => DropdownMenuEntry<String>(
                                  value: modelName,
                                  label: modelName,
                                ),
                              )
                              .toList(),
                          onSelected: (value) {
                            if (value != null) {
                              provider.selectModel(value);
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: provider.isLoading
                            ? null
                            : () {
                                provider.selectModel(_searchController.text);
                                FocusScope.of(context).unfocus();
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: const Text('Tra cứu'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Consumer<PowerConsumptionProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.errorMessage != null) {
                      return Center(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    if (provider.specs == null) {
                      return const Center(
                        child: Text(
                          'Chọn tên model máy để xem thông số',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: constraints.maxWidth,
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                headingRowColor: WidgetStateProperty.all(
                                  Colors.blue.withValues(alpha: 0.1),
                                ),
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Tiêu chí',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Center(
                                      child: Text(
                                        'Thông số',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                rows: provider.specs!.asMap().entries.map((
                                  entry,
                                ) {
                                  int index = entry.key;
                                  var item = entry.value;
                                  return DataRow(
                                    color: index % 2 == 0
                                        ? WidgetStateProperty.all(
                                            Colors.grey.withValues(alpha: 0.05),
                                          )
                                        : null,
                                    cells: [
                                      DataCell(Text(item['Tiêu chí'] ?? '')),
                                      DataCell(
                                        Center(
                                          child: Text(item['Thông số'] ?? ''),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
