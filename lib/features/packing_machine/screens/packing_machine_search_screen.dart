import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/packing_catalog.dart';
import '../providers/packing_machine_provider.dart';
import '../widgets/packing_machine_list_tile.dart';

/// Tìm nhanh model máy đóng gói theo model / dòng máy / nguyên liệu.
class PackingMachineSearchScreen extends StatefulWidget {
  const PackingMachineSearchScreen({super.key});

  @override
  State<PackingMachineSearchScreen> createState() =>
      _PackingMachineSearchScreenState();
}

class _PackingMachineSearchScreenState
    extends State<PackingMachineSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      context.read<PackingMachineProvider>().load();
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
    final palette = DtcPalette.of(context);
    final provider = context.watch<PackingMachineProvider>();
    final query = _controller.text.trim();
    final List<PackingMachine> results = query.isEmpty
        ? const []
        : provider.search(query);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: TextField(
          key: const Key('packing_machine_search_field'),
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
                'Nhập model (VD: ASPM-520) hoặc từ khóa để tìm.',
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
                return PackingMachineListTile(
                  machine: machine,
                  imagePath: provider.imageOf(machine),
                  subtitle: provider.seriesOf(machine.seriesCode)?.nameVi,
                  onTap: () => context.push(
                    '/packing_machine/detail/${machine.machineId}',
                  ),
                );
              },
            ),
    );
  }
}
