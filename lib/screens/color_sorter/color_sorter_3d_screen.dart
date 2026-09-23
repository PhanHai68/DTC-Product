import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ColorSorter3dScreen extends StatefulWidget {
  final String modelName;
  final String modelPath;
  final String posterPath;
  final String dimensions;
  final String configuration;
  final String technology;
  final double exposure;
  final bool showHotspots;

  /// Preset ánh sáng môi trường của model-viewer ('neutral' mặc định cho các
  /// máy đã lên màu chuẩn; 'legacy' cho ánh sáng phẳng, ít đổ bóng gắt hơn —
  /// dùng cho các model 3D bị lỗi mặt (facet) do giản lược lưới quá mức,
  /// tránh làm lộ rõ hiệu ứng "giấy bạc nhàu" khi có bóng đổ tương phản cao).
  final String environmentImage;

  const ColorSorter3dScreen({
    super.key,
    this.modelName = 'SC16 Pro',
    this.modelPath = 'assets/models/sc16_pro.glb',
    this.posterPath = 'assets/images/color_sorter/sc16.jpeg',
    this.dimensions = '4830x1690x1915 mm',
    this.configuration = '7:3:2',
    this.technology = 'AI Deep Learning',
    this.exposure = 0.85,
    this.showHotspots = false,
    this.environmentImage = 'neutral',
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
    _progressTimer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
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
      return 'assets/${widget.posterPath}';
    }
    return widget.posterPath;
  }

  void _showHotspotDialog(String partName) {
    final Map<String, String> partDetails = {
      'Bộ phận 1: Sàng trải liệu': 'Phân tán nguyên liệu trên một mặt, dòng liệu được trải mỏng và khoảng cách đồng đều.',
      'Bộ phận 2: Sàng tách đá': 'Dựa trên khác biệt về trọng lượng để loại bỏ vật liệu nặng như: Đá, thuỷ tinh, kim loại…',
      'Bộ phận 3: Trục lăn tách dị vật trọng lượng nhẹ': 'Tách các vật liệu nhẹ như dây nilon, tóc, sợi vải... lẫn trong chè.',
      'Bộ phận 4: Sàng rung cám': 'Tách cám và cấp liệu đồng đều.',
      'Bộ phận 5: Băng tải chữ Z': 'Cấp liệu lên máy tách màu.',
      'Bộ phận 6: Máy tách màu': 'Phân loại cẫng chè, bồm (lá vàng), chè và các loại tạp chất lẫn trong chè…',
      'Bộ phận 7: Sàng rung cấp liệu': 'Rung cấp liệu vào bộ rung máy tách màu',
      'Bộ phận 8: Màn hình': 'Điều khiển thông số vận hành',
      'Bộ phận 9: Băng tải ra': 'Dẫn liệu ra sau khi tách',
      'Bộ phận 10: Băng tải hồi ngang': 'Vận chuyển đường liệu sau khi tách màu',
      'Bộ phận 11: Băng tải hồi nghiêng': 'Vận chuyển đường liệu sau khi tách màu',
    };
    
    final String description = partDetails[partName] ?? 'Đây là thông tin chi tiết về bộ phận $partName trên máy ${widget.modelName}.\n\n(Dữ liệu có thể được cập nhật thêm sau)';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.settings_suggest, color: Colors.blue, size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                partName.contains(':') ? partName.split(':')[1].trim() : partName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: const TextStyle(height: 1.5, fontSize: 14.5),
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
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
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
            rotationPerSecond: '18deg',
            cameraControls: true,
            touchAction: TouchAction.none,
            interactionPrompt: InteractionPrompt.none,
            interpolationDecay: 80,
            environmentImage: widget.environmentImage,
            exposure: widget.exposure,
            shadowIntensity: 0,
            debugLogging: false,
            innerModelViewerHtml: !widget.showHotspots ? '' : '''
              <button class="hotspot" slot="hotspot-1" data-position="-0.202 -1.171 -9.434" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 1: Sàng trải liệu');"></button>
              <button class="hotspot" slot="hotspot-2" data-position="-0.223 -0.992 -6.950" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 2: Sàng tách đá');"></button>
              <button class="hotspot" slot="hotspot-3" data-position="-0.159 -1.290 -5.914" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 3: Trục lăn tách dị vật trọng lượng nhẹ');"></button>
              <button class="hotspot" slot="hotspot-4" data-position="-0.293 -1.595 -5.428" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 4: Sàng rung cám');"></button>
              <button class="hotspot" slot="hotspot-5" data-position="-0.433 -0.120 -3.251" data-normal="0.000 0.500 -0.866" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 5: Băng tải chữ Z');"></button>
              <button class="hotspot" slot="hotspot-6" data-position="0.904 0.364 -0.348" data-normal="0.863 0.505 -0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 6: Máy tách màu');"></button>
              <button class="hotspot" slot="hotspot-7" data-position="-0.340 1.620 -0.326" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 7: Sàng rung cấp liệu');"></button>
              <button class="hotspot" slot="hotspot-8" data-position="1.805 -0.403 1.177" data-normal="1.000 0.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 8: Màn hình');"></button>
              <button class="hotspot" slot="hotspot-9" data-position="0.767 -1.127 1.610" data-normal="0.000 1.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 9: Băng tải ra');"></button>
              <button class="hotspot" slot="hotspot-10" data-position="-0.879 -1.652 -1.684" data-normal="0.000 1.000 0.000" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 10: Băng tải hồi ngang');"></button>
              <button class="hotspot" slot="hotspot-11" data-position="-1.608 -0.958 -4.005" data-normal="0.965 0.008 0.262" onclick="if(window.HotspotChannel) window.HotspotChannel.postMessage('Bộ phận 11: Băng tải hồi nghiêng');"></button>
            ''',
            relatedCss: '''
              model-viewer {
                contain: strict;
                --progress-bar-color: #263238;
              }
              .hotspot-toggle {
                display: flex !important;
                position: fixed !important;
                bottom: 20px !important;
                left: 16px !important;
                transform: none !important;
                opacity: 1 !important;
                visibility: visible !important;
                background: white;
                padding: 8px 16px;
                border-radius: 20px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.25);
                font-family: sans-serif;
                font-weight: bold;
                font-size: 13.5px;
                color: #1976D2;
                cursor: pointer;
                align-items: center;
                z-index: 1000;
                border: 1px solid #e3f2fd;
              }
              .hotspot {
                display: none;
                width: 24px;
                height: 24px;
                border-radius: 12px;
                border: 2px solid #ffffff;
                background-color: #2196F3;
                box-sizing: border-box;
                cursor: pointer;
                box-shadow: 0 0 10px rgba(0, 0, 0, 0.4);
                transition: transform 0.2s, background-color 0.2s;
                align-items: center;
                justify-content: center;
              }
              .hotspot::after {
                content: "+";
                color: white;
                font-size: 18px;
                font-weight: bold;
                font-family: monospace;
              }
              model-viewer.show-hotspots .hotspot {
                display: flex;
              }
              .hotspot:hover {
                transform: scale(1.25);
                background-color: #1565C0;
              }
            ''',
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
              JavascriptChannel(
                'HotspotChannel',
                onMessageReceived: (message) {
                  _showHotspotDialog(message.message);
                },
              ),
            },
            relatedJs: '''
              ${!widget.showHotspots ? '' : '''
              window.toggleHotspots = function() {
                const mv = document.querySelector('model-viewer');
                mv.classList.toggle('show-hotspots');
                const isShow = mv.classList.contains('show-hotspots');
                const text = document.getElementById('toggle-text');
                if(text) text.innerText = isShow ? 'Ẩn vị trí các thiết bị chính' : 'Hiện vị trí các thiết bị chính';
              };

              // Tạo nút bấm ngoài luồng shadow DOM của model-viewer để không bị transform ảnh hưởng
              const btn = document.createElement('button');
              btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="17" height="17" fill="#1976D2" style="margin-right: 6px; flex-shrink: 0;"><path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5z"/></svg><span id="toggle-text">Hiện vị trí các thiết bị chính</span>';
              btn.style.position = 'fixed';
              btn.style.bottom = '120px';
              btn.style.left = '50%';
              btn.style.transform = 'translateX(-50%)';
              btn.style.backgroundColor = 'white';
              btn.style.padding = '10px 20px';
              btn.style.borderRadius = '24px';
              btn.style.boxShadow = '0 4px 12px rgba(0,0,0,0.2)';
              btn.style.fontFamily = 'sans-serif';
              btn.style.fontWeight = 'bold';
              btn.style.fontSize = '14.5px';
              btn.style.color = '#1976D2';
              btn.style.cursor = 'pointer';
              btn.style.border = '1px solid #e3f2fd';
              btn.style.zIndex = '999999';
              btn.style.display = 'flex';
              btn.style.alignItems = 'center';
              btn.style.whiteSpace = 'nowrap';
              btn.onclick = window.toggleHotspots;
              document.body.appendChild(btn);
              '''}

              const mv = document.querySelector('model-viewer');
              customElements.whenDefined('model-viewer').then(() => {
                const ModelViewerElement = customElements.get('model-viewer');
                if (ModelViewerElement) {
                  ModelViewerElement.minimumRenderScale = 0.35;
                }
              });
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

          // Brand identity is kept outside the WebView so it stays sharp while
          // the 3D renderer dynamically lowers its resolution during gestures.
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Center(
              child: Container(
                width: 168,
                height: 56,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Semantics(
                  image: true,
                  label: 'Logo DTC Group',
                  child: Image.asset(
                    'assets/images/DTCGroup-Slogan.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
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
                  constraints: const BoxConstraints(maxWidth: 260),
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
            top: 78,
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
                      textAlign: TextAlign.center,
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
                    widget.dimensions,
                    Icons.straighten,
                  ),
                  Container(height: 28, width: 1, color: Colors.grey.shade300),
                  _buildQuickSpecItem(
                    'Cấu hình',
                    widget.configuration,
                    Icons.view_stream,
                  ),
                  Container(height: 28, width: 1, color: Colors.grey.shade300),
                  _buildQuickSpecItem(
                    'Công nghệ',
                    widget.technology,
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
