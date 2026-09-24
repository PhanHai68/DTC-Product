import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/grinding_machine.dart';
import '../providers/grinding_machine_provider.dart';
import 'grinding_machine_list_tile.dart';

/// Mở bottom sheet tìm & chọn 1 model — dùng cho màn hình So sánh.
Future<GrindingMachine?> showGrindingMachinePickerSheet(
  BuildContext context, {
  Set<String> excludeMachineIds = const {},
}) {
  return showModalBottomSheet<GrindingMachine>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _PickerSheet(excludeMachineIds: excludeMachineIds),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.excludeMachineIds});

  final Set<String> excludeMachineIds;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<GrindingMachine> _results = const [];

  @override
  void initState() {
    super.initState();
    final provider = context.read<GrindingMachineProvider>();
    _results = provider.machines
        .where((m) => !widget.excludeMachineIds.contains(m.machineId))
        .toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final provider = context.read<GrindingMachineProvider>();
      final results = value.trim().isEmpty
          ? provider.machines
          : await provider.search(value);
      if (!mounted) return;
      setState(() {
        _results = results
            .where((m) => !widget.excludeMachineIds.contains(m.machineId))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  key: const Key('grinding_picker_search_field'),
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: 'Tìm model để so sánh...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy model phù hợp.',
                          style: TextStyle(color: palette.muted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final machine = _results[index];
                          return GrindingMachineListTile(
                            machine: machine,
                            onTap: () => Navigator.of(context).pop(machine),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
