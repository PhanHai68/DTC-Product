import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../equipment_catalog_config.dart';
import '../models/equipment_catalog.dart';
import '../providers/equipment_catalog_provider.dart';
import '../widgets/equipment_machine_list_tile.dart';

/// Tìm nhanh model theo model / dòng máy / nguyên liệu.
class EquipmentSearchScreen extends StatefulWidget {
  const EquipmentSearchScreen({super.key, required this.config});

  final EquipmentCatalogConfig config;

  @override
  State<EquipmentSearchScreen> createState() => _EquipmentSearchScreenState();
}

class _EquipmentSearchScreenState extends State<EquipmentSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      context.read<EquipmentCatalogProvider>().load(widget.config);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    final palette = DtcPalette.of(context);
    final catalog = context.watch<EquipmentCatalogProvider>().catalog(config);
    final query = _controller.text.trim();
    final List<EquipmentMachine> results = query.isEmpty || catalog == null
        ? const []
        : catalog.search(query);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: TextField(
          key: Key('${config.id}_machine_search_field'),
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Model, dòng máy, nguyên liệu...',
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Xóa',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(_controller.clear),
            ),
        ],
      ),
      body: query.isEmpty
          ? Center(
              child: Text(
                'Nhập model hoặc từ khóa để tìm.',
                style: TextStyle(color: palette.muted),
              ),
            )
          : results.isEmpty
          ? Center(
              child: Text(
                'Không tìm thấy model phù hợp trong catalog.',
                style: TextStyle(color: palette.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              itemCount: results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final machine = results[index];
                return EquipmentMachineListTile(
                  config: config,
                  machine: machine,
                  imagePath: catalog!.imageOf(machine),
                  subtitle: catalog.seriesOf(machine.seriesCode)?.nameVi,
                  onTap: () => context.push(
                    '${config.routeBase}/detail/${machine.machineId}',
                  ),
                );
              },
            ),
    );
  }
}
