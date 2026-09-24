import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../models/grinding_series.dart';
import '../providers/grinding_machine_provider.dart';
import '../widgets/grinding_machine_list_tile.dart';

/// Tìm kiếm nhanh theo model / dòng máy / nguyên liệu / application — khớp
/// yêu cầu mục 3 "Search" (nhập BSP-350, BSZ-630...).
class GrindingMachineSearchScreen extends StatefulWidget {
  const GrindingMachineSearchScreen({super.key});

  @override
  State<GrindingMachineSearchScreen> createState() =>
      _GrindingMachineSearchScreenState();
}

class _GrindingMachineSearchScreenState
    extends State<GrindingMachineSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<GrindingMachine> _results = const [];
  Map<String, GrindingSeries> _seriesByCode = const {};
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      final provider = context.read<GrindingMachineProvider>();
      _seriesByCode = {for (final s in provider.series) s.seriesCode: s};
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await context.read<GrindingMachineProvider>().search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final query = _controller.text.trim();
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(
        title: TextField(
          key: const Key('grinding_machine_search_field'),
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
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
              onPressed: () {
                _controller.clear();
                setState(() => _results = const []);
              },
            ),
        ],
      ),
      body: query.isEmpty
          ? Center(
              child: Text(
                'Nhập model (VD: ASP-350) hoặc từ khóa để tìm.',
                style: TextStyle(color: palette.muted),
              ),
            )
          : _isSearching
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(
              child: Text(
                'Không tìm thấy model phù hợp trong database.',
                style: TextStyle(color: palette.muted),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              itemCount: _results.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final machine = _results[index];
                final series = _seriesByCode[machine.seriesCode];
                return GrindingMachineListTile(
                  machine: machine,
                  subtitle: series?.nameVi,
                  onTap: () => context.push(
                    '/grinding_machine/detail/${machine.machineId}',
                  ),
                );
              },
            ),
    );
  }
}
