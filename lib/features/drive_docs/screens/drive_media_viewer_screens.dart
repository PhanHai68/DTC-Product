import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/drive_item.dart';
import '../services/drive_docs_service.dart';
import '../widgets/drive_file_loader.dart';
import '../widgets/drive_share_sheet.dart';

Future<void> _openInDrive(DriveItem item) =>
    launchUrl(item.driveViewUri, mode: LaunchMode.externalApplication);

/// Xem ảnh trên Google Drive, chụm hai ngón để phóng to.
class DriveImageViewerScreen extends StatelessWidget {
  const DriveImageViewerScreen({super.key, required this.item});

  final DriveItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          DriveShareButton(item: item),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Đóng',
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: DriveFileLoader(
        load: () => DriveDocsService.instance.loadFile(item),
        foregroundColor: Colors.white70,
        builder: (context, bytes) => InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text(
                'Không hiển thị được ảnh này.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phát video trên Google Drive (stream, không lưu offline).
class DriveVideoPlayerScreen extends StatefulWidget {
  const DriveVideoPlayerScreen({super.key, required this.item});

  final DriveItem item;

  @override
  State<DriveVideoPlayerScreen> createState() => _DriveVideoPlayerScreenState();
}

class _DriveVideoPlayerScreenState extends State<DriveVideoPlayerScreen> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(
        DriveDocsService.instance.mediaUri(widget.item),
      );
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
      await _controller.play();
    } catch (error) {
      debugPrint(
        'DriveDocs: không phát được video ${widget.item.name}: $error',
      );
      _failed = true;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          DriveShareButton(item: widget.item),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Mở bằng Google Drive',
            onPressed: () => _openInDrive(widget.item),
          ),
        ],
      ),
      body: Center(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_failed) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'Không phát được video trong ứng dụng.\n'
              'Kiểm tra kết nối mạng, hoặc mở bằng Google Drive.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openInDrive(widget.item),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Mở bằng Google Drive'),
            ),
          ],
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          _PlayPauseOverlay(controller: _controller),
          VideoProgressIndicator(_controller, allowScrubbing: true),
        ],
      ),
    );
  }
}

class _PlayPauseOverlay extends StatelessWidget {
  const _PlayPauseOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => value.isPlaying ? controller.pause() : controller.play(),
        child: Center(
          child: AnimatedOpacity(
            opacity: value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 72,
              semanticLabel: 'Phát / tạm dừng',
            ),
          ),
        ),
      ),
    );
  }
}
