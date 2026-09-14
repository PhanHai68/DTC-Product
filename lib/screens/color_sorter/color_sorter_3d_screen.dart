import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ColorSorter3dScreen extends StatefulWidget {
  final String modelName;
  final String modelPath;

  const ColorSorter3dScreen({
    super.key,
    this.modelName = 'SC16 Pro',
    this.modelPath = 'assets/models/sc16_pro.glb',
  });

  @override
  State<ColorSorter3dScreen> createState() => _ColorSorter3dScreenState();
}

class _ColorSorter3dScreenState extends State<ColorSorter3dScreen> {
  bool _autoRotate = false;
  bool _isLoading = true;
  int _loadingProgress = 0;
  Timer? _progressTimer;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _startProgressSimulation();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _fallbackTimer?.cancel();
    super.dispose();
  }

  void _startProgressSimulation() {
    _progressTimer?.cancel();
    // Simulate smooth natural progress up to 92% until 3D engine signals completion
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_loadingProgress < 50) {
          _loadingProgress += 5;
        } else if (_loadingProgress < 80) {
          _loadingProgress += 3;
        } else if (_loadingProgress < 94) {
          _loadingProgress += 1;
        }
      });
    });

    // Fallback: automatically reveal model after 5 seconds in case load event was already fired
    _fallbackTimer = Timer(const Duration(milliseconds: 5000), () {
      _finishLoading();
    });
  }

  void _onRealProgressReceived(int progress) {
    if (!mounted || !_isLoading) return;
    setState(() {
      if (progress > _loadingProgress) {
        _loadingProgress = progress;
      }
    });
    if (progress >= 100) {
      _finishLoading();
    }
  }

  void _finishLoading() {
    if (!mounted || !_isLoading) return;
    _progressTimer?.cancel();
    _fallbackTimer?.cancel();
    setState(() {
      _loadingProgress = 100;
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  String get _effectiveModelPath {
    if (widget.modelPath.startsWith('http')) {
      return widget.modelPath;
    }
    if (kIsWeb) {
      // Trong Flutter Web, asset trong pubspec được phục vụ tại 'assets/<asset-path>'
      return 'assets/${widget.modelPath}';
    }
    return widget.modelPath;
  }

  String get _effectivePosterPath {
    if (kIsWeb) {
      return 'assets/assets/images/color_sorter/sc16.jpeg';
    }
    return 'assets/images/color_sorter/sc16.jpeg';
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.touch_app, color: Colors.blue, size: 26),
            SizedBox(width: 8),
            Text(
              'Hướng dẫn thao tác 3D',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _HelpItem(
              icon: Icons.rotate_right,
              text: 'Vuốt 1 ngón tay để xoay mô hình 360° mọi góc độ.',
            ),
            SizedBox(height: 10),
            _HelpItem(
              icon: Icons.pinch,
              text: 'Dùng 2 ngón tay chụm/mở để phóng to hoặc thu nhỏ.',
            ),
            SizedBox(height: 10),
            _HelpItem(
              icon: Icons.pan_tool,
              text: 'Dùng 2 ngón tay kéo để di chuyển vị trí mô hình.',
            ),
            SizedBox(height: 10),
            _HelpItem(
              icon: Icons.view_in_ar,
              text: 'Nhấn biểu tượng AR (ở góc mô hình) để chiếu máy tỷ lệ thực vào nền nhà xưởng.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Mô hình 3D - ${widget.modelName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[900],
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(
              _autoRotate
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              color: _autoRotate ? Colors.blue[800] : Colors.grey[600],
            ),
            tooltip: _autoRotate ? 'Tạm dừng tự xoay' : 'Bật tự xoay',
            onPressed: () {
              setState(() {
                _autoRotate = !_autoRotate;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Hướng dẫn tương tác',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 3D Model Viewer
          ModelViewer(
            backgroundColor: const Color(0xFFF1F5F9),
            src: _effectiveModelPath,
            poster: _effectivePosterPath,
            loading: Loading.eager,
            reveal: Reveal.auto,
            alt: 'Mô hình 3D Máy Tách Màu ${widget.modelName.toUpperCase()}',
            ar: true,
            arModes: const ['scene-viewer', 'webxr', 'quick-look'],
            autoRotate: _autoRotate,
            autoRotateDelay: 0,
            rotationPerSecond: '25deg',
            cameraControls: true,
            debugLogging: false,
            javascriptChannels: {
              JavascriptChannel(
                'LoadingChannel',
                onMessageReceived: (message) {
                  final p = int.tryParse(message.message);
                  if (p != null) {
                    _onRealProgressReceived(p);
                  }
                },
              ),
            },
            relatedJs: '''
              const mv = document.querySelector('model-viewer');
              if (mv) {
                mv.addEventListener('progress', (e) => {
                  const p = Math.round((e.detail.totalProgress || 0) * 100);
                  if (window.LoadingChannel && window.LoadingChannel.postMessage) {
                    window.LoadingChannel.postMessage(p.toString());
                  }
                });
                mv.addEventListener('load', () => {
                  if (window.LoadingChannel && window.LoadingChannel.postMessage) {
                    window.LoadingChannel.postMessage('100');
                  }
                });
              }
            ''',
          ),

          // Centered Loading Overlay with Percentage
          IgnorePointer(
            ignoring: !_isLoading,
            child: AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              child: Container(
                color: const Color(0xFFF1F5F9).withValues(alpha: 0.95),
                alignment: Alignment.center,
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 26,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade900.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Circular Progress with percentage inside
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: CircularProgressIndicator(
                              value: _loadingProgress > 0
                                  ? _loadingProgress / 100.0
                                  : null,
                              strokeWidth: 5,
                              backgroundColor: Colors.blue.shade50,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade700,
                              ),
                            ),
                          ),
                          Text(
                            '$_loadingProgress%',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Đang tải...',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Đang nạp mô hình 3D máy tách màu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _loadingProgress > 0
                              ? _loadingProgress / 100.0
                              : null,
                          minHeight: 5,
                          backgroundColor: Colors.blue.shade50,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Top Info Hint Banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.threed_rotation,
                    color: Colors.blue,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vuốt để xoay 360° • Thu phóng chi tiết',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _showHelpDialog,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        SizedBox(width: 2),
                        Text(
                          'Trợ giúp',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Specs Floating Bar
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickSpecItem(
                    'Kích thước',
                    '4830x1690x1915 mm',
                    Icons.straighten,
                  ),
                  Container(height: 28, width: 1, color: Colors.grey.shade300),
                  _buildQuickSpecItem('Cấu hình', '7:3:2', Icons.view_stream),
                  Container(height: 28, width: 1, color: Colors.grey.shade300),
                  _buildQuickSpecItem(
                    'Công nghệ',
                    'AI Deep Learning',
                    Icons.memory,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSpecItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.blue.shade800),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
      ],
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue[800]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, height: 1.3),
          ),
        ),
      ],
    );
  }
}
