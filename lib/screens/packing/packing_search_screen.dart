// Màn hình Tra cứu Model với search realtime và debounce.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/packing_provider.dart';
import '../../providers/compare_provider.dart';
import '../../routes/route_locations.dart';
import '../../widgets/packing/machine_card.dart';
import '../../widgets/packing/packing_back_button.dart';

class PackingSearchScreen extends StatefulWidget {
  const PackingSearchScreen({super.key});

  @override
  State<PackingSearchScreen> createState() => _PackingSearchScreenState();
}

class _PackingSearchScreenState extends State<PackingSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // Load data nếu chưa có
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PackingProvider>();
      if (provider.machines.isEmpty) {
        provider.loadAll();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Xử lý search với debounce 300ms
  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<PackingProvider>().search(value);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    context.read<PackingProvider>().clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleSpacing: 0,
        leadingWidth: 64,
        leading: PackingBackButton(
          foregroundColor: colorScheme.primary,
          tooltip: 'Về Cân đóng gói',
        ),
        title: Hero(
          tag: 'packing_search',
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Nhập model máy (vd: LZB-600)',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                          color: colorScheme.onSurfaceVariant,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer2<PackingProvider, CompareProvider>(
        builder: (context, packingProvider, compareProvider, _) {
          // Loading
          if (packingProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error
          if (packingProvider.hasError) {
            return _ErrorView(
              message: packingProvider.errorMessage!,
              onRetry: () => packingProvider.loadAll(),
            );
          }

          // Searching
          if (packingProvider.isSearching) {
            return const Center(child: CircularProgressIndicator());
          }

          final results = packingProvider.searchResults;

          // Empty state
          if (results.isEmpty) {
            return _EmptyView(query: _searchController.text);
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                children: [
                  // Kết quả count
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          '${results.length} kết quả',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (compareProvider.count > 0)
                          TextButton.icon(
                            onPressed: () => context.push('/machine_compare'),
                            icon: const Icon(Icons.compare_arrows, size: 16),
                            label: Text('Đã chọn ${compareProvider.count}/3'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Danh sách kết quả
                  Expanded(
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final machine = results[index];
                        return MachineCard(
                          machine: machine,
                          isSelected: compareProvider.isSelected(machine.model),
                          onTap: () {
                            context.push(
                              packingDetailLocation(
                                machine.model,
                                showCatalog: false,
                              ),
                            );
                          },
                          onCompare: () {
                            if (compareProvider.isSelected(machine.model)) {
                              compareProvider.removeMachine(machine.model);
                            } else {
                              compareProvider.addMachineObject(machine);
                              if (compareProvider.isFull) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Đã chọn tối đa 3 model để so sánh',
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String query;

  const _EmptyView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'Nhập model máy để tìm kiếm'
                  : 'Không tìm thấy model "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Thử tìm: LZB-600, PZB-1200, DCS-50...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
