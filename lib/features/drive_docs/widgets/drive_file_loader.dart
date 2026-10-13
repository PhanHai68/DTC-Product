import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/drive_docs_service.dart';

/// Tải file (PDF, ảnh) từ Google Drive rồi giao bytes cho [builder]; hiện vòng chờ khi
/// đang tải và thông báo lỗi kèm nút "Thử lại" khi thất bại.
class DriveFileLoader extends StatefulWidget {
  const DriveFileLoader({
    super.key,
    required this.load,
    required this.builder,
    this.foregroundColor,
  });

  /// Gọi lại mỗi lần thử tải, ví dụ `() => service.loadPdfByName(name)`.
  final Future<Uint8List> Function() load;
  final Widget Function(BuildContext context, Uint8List bytes) builder;
  final Color? foregroundColor;

  @override
  State<DriveFileLoader> createState() => _DriveFileLoaderState();
}

class _DriveFileLoaderState extends State<DriveFileLoader> {
  late Future<Uint8List> _future = widget.load();

  void _retry() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    final color =
        widget.foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(context, snapshot.data!);
        if (snapshot.hasError) {
          return DriveDocsErrorView(
            message: _messageOf(snapshot.error!),
            onRetry: _retry,
            color: color,
          );
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Đang tải tài liệu...', style: TextStyle(color: color)),
            ],
          ),
        );
      },
    );
  }
}

String _messageOf(Object error) => error is DriveDocsException
    ? error.message
    : 'Không mở được tài liệu. Vui lòng thử lại.';

class DriveDocsErrorView extends StatelessWidget {
  const DriveDocsErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.color,
  });

  final String message;
  final VoidCallback onRetry;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 15),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
