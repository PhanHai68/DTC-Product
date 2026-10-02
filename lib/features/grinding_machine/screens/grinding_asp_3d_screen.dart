import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../theme/dtc_palette.dart';

/// Trình xem mô hình đại diện cho dòng máy nghiền siêu mịn ASP.
///
/// Nguồn hiện tại là video quay mô hình ASP-350, vì vậy màn hình luôn ghi rõ
/// đây là model đại diện, không ngụ ý mọi model ASP có cùng kích thước/cấu hình.
class GrindingAsp3dScreen extends StatefulWidget {
  const GrindingAsp3dScreen({super.key});

  static const assetPath = 'assets/videos/ASP-350-3D.mp4';

  @override
  State<GrindingAsp3dScreen> createState() => _GrindingAsp3dScreenState();
}

class _GrindingAsp3dScreenState extends State<GrindingAsp3dScreen> {
  late final VideoPlayerController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(GrindingAsp3dScreen.assetPath);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể mở mô hình 3D ASP-350 trên thiết bị này.';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
  }

  Future<void> _restart() async {
    if (!_controller.value.isInitialized) return;
    await _controller.seekTo(Duration.zero);
    await _controller.play();
  }

  Future<void> _toggleMute() async {
    if (!_controller.value.isInitialized) return;
    await _controller.setVolume(_controller.value.volume == 0 ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      appBar: AppBar(title: const Text('Mô hình 3D - ASP-350')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Container(
              key: const Key('grinding_asp_3d_viewer'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: _VideoContent(
                controller: _controller,
                error: _error,
                onTogglePlayback: _togglePlayback,
              ),
            ),
            const SizedBox(height: 14),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final initialized = _controller.value.isInitialized;
                final playing = initialized && _controller.value.isPlaying;
                final muted = initialized && _controller.value.volume == 0;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      key: const Key('grinding_asp_3d_restart_button'),
                      tooltip: 'Phát lại từ đầu',
                      onPressed: initialized ? _restart : null,
                      icon: const Icon(Icons.replay_rounded),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      key: const Key('grinding_asp_3d_play_button'),
                      onPressed: initialized ? _togglePlayback : null,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(playing ? 'Tạm dừng' : 'Phát'),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      key: const Key('grinding_asp_3d_mute_button'),
                      tooltip: muted ? 'Bật âm thanh' : 'Tắt âm thanh',
                      onPressed: initialized ? _toggleMute : null,
                      icon: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.view_in_ar_rounded, color: palette.cyan),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mô hình đại diện dòng ASP',
                          style: TextStyle(
                            color: palette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Video mô phỏng model ASP-350 thuộc dòng Máy nghiền siêu '
                    'mịn. Chạm vào hình hoặc dùng các nút bên dưới để điều '
                    'khiển; kéo thanh thời gian để xem nhanh từng góc máy.',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({
    required this.controller,
    required this.error,
    required this.onTogglePlayback,
  });

  final VideoPlayerController controller;
  final String? error;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.value.isInitialized) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final aspectRatio = controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 16 / 9;
        return Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTogglePlayback,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(controller),
                    if (!controller.value.isPlaying)
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF14916A),
                bufferedColor: Color(0xFF8AA2AE),
                backgroundColor: Color(0xFF263B46),
              ),
            ),
          ],
        );
      },
    );
  }
}
