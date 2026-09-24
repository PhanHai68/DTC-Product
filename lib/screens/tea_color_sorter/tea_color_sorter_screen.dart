import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/tea_color_sorter_provider.dart';
import '../color_sorter/spec_image_export_dialog.dart';

class TeaColorSorterScreen extends StatefulWidget {
  const TeaColorSorterScreen({
    super.key,
    this.initialModel,
    this.availableModels = const [
      'DF53 Pro',
      'DF36 Pro',
      'DF21 Pro',
      'DF12 Pro',
    ],
  });

  final String? initialModel;
  final List<String> availableModels;

  @override
  State<TeaColorSorterScreen> createState() => _TeaColorSorterScreenState();
}

class _TeaColorSorterScreenState extends State<TeaColorSorterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final initialModel = widget.initialModel;
    if (initialModel != null && initialModel.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TeaColorSorterProvider>().selectModel(initialModel);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconForSpec(String key) {
    if (key.contains('năng suất') ||
        key.contains('Năng suất') ||
        key.contains('capacity')) {
      return Icons.speed;
    }
    if (key.contains('máng') || key.contains('chute')) {
      return Icons.density_medium;
    }
    if (key.contains('ejector')) return Icons.scatter_plot;
    if (key.contains('Camera') || key.contains('camera')) {
      return Icons.camera_alt;
    }
    if (key.contains('Công suất') || key.contains('power')) {
      return Icons.electrical_services;
    }
    if (key.contains('Điện áp') || key.contains('voltage')) return Icons.power;
    if (key.contains('Trọng lượng') ||
        key.contains('Khối lượng') ||
        key.contains('weight')) {
      return Icons.scale;
    }
    if (key.contains('Kích thước') || key.contains('dim')) {
      return Icons.straighten;
    }
    if (key.contains('Áp suất') || key.contains('pressure')) {
      return Icons.compress;
    }
    if (key.contains('Lưu lượng')) return Icons.wind_power;
    if (key.contains('Tần số') || key.contains('frequency')) {
      return Icons.waves;
    }
    if (key.toLowerCase().contains('tầng') || key.toLowerCase().contains('layer')) {
      return Icons.layers;
    }
    if (key.contains('chính xác') || key.contains('quality')) {
      return Icons.verified;
    }
    if (key.contains('phế phẩm') || key.contains('bắn phế')) {
      return Icons.change_circle;
    }
    if (key.contains('Máy nén khí') || key.contains('air_compressor')) {
      return Icons.compress;
    }
    if (key.contains('Bình tích') ||
        key.contains('Bình chứa') ||
        key.contains('air_tank')) {
      return Icons.propane_tank;
    }
    if (key.contains('Máy sấy') || key.contains('air_dryer')) return Icons.air;
    if (key.contains('Bộ lọc') || key.contains('air_filter')) {
      return Icons.filter_alt;
    }
    if (key.contains('sàn')) return Icons.architecture;
    if (key.contains('Nguyên liệu')) return Icons.grain;
    return Icons.info_outline;
  }

  Color _getColorForSpec(String key) {
    if (key.contains('năng suất') || key.contains('Năng suất')) {
      return const Color(0xFFEA6C00);
    }
    if (key.contains('máng') || key.contains('ejector')) {
      return const Color(0xFF0D47A1);
    }
    if (key.contains('Camera')) return const Color(0xFF1565C0);
    if (key.contains('chính xác') || key.contains('quality')) {
      return const Color(0xFF2E7D32);
    }
    if (key.contains('phế phẩm') || key.contains('bắn phế')) {
      return const Color(0xFFB71C1C);
    }
    if (key.contains('Công suất') ||
        key.contains('Điện') ||
        key.contains('power') ||
        key.contains('voltage')) {
      return const Color(0xFFF57F17);
    }
    if (key.contains('Áp suất') ||
        key.contains('Lưu lượng') ||
        key.contains('pressure') ||
        key.contains('air_compressor')) {
      return const Color(0xFF006064);
    }
    if (key.contains('Trọng lượng') ||
        key.contains('Khối lượng') ||
        key.contains('weight') ||
        key.contains('air_filter')) {
      return const Color(0xFF4A148C);
    }
    if (key.contains('Kích thước') ||
        key.contains('sàn') ||
        key.contains('dim')) {
      return const Color(0xFF1A237E);
    }
    if (key.contains('Máy sấy') || key.contains('air_dryer')) {
      return const Color(0xFF01579B);
    }
    if (key.contains('Bình tích') || key.contains('air_tank')) {
      return const Color(0xFF1B5E20);
    }
    return const Color(0xFF37474F);
  }

  String _getDisplayName(String key) {
    switch (key) {
      case 'id':
        return 'ID';
      case 'category':
        return 'Danh mục';
      case 'series':
        return 'Dòng máy (Series)';
      case 'model':
        return 'Model';
      case 'product_name':
        return 'Tên sản phẩm';
      case 'capacity_display':
        return 'Năng suất';
      case 'capacity_max_kg_h':
        return 'Năng suất tối đa (kg/h)';
      case 'layers_qty':
        return 'Số tầng';
      case 'chutes_qty':
        return 'Số máng';
      case 'ejector_qty':
        return 'Số ejector';
      case 'ejector_per_chute':
        return 'Số ejector/ máng';
      case 'camera_qty':
        return 'Số camera';
      case 'finished_quality_min_pct':
        return 'Độ phân loại chính xác (%)';
      case 'power_kw':
        return 'Công suất (kW)';
      case 'voltage_v':
        return 'Điện áp (V)';
      case 'frequency_hz':
        return 'Tần số (Hz)';
      case 'air_flow_m3_min':
        return 'Lưu lượng khí nén (m³/phút)';
      case 'dimensions_display_mm':
        return 'Kích thước (D R C)';
      case 'weight_kg':
        return 'Trọng lượng';
      case 'key_features':
        return 'Tính năng nổi bật';
      case 'air_compressor':
        return 'Máy nén khí';
      case 'air_dryer':
        return 'Máy sấy khí';
      case 'air_tank':
        return 'Bình tích khí';
      case 'air_filter':
        return 'Bộ lọc khí';
      default:
        return key;
    }
  }

  String? _getImagePath(String? model) {
    if (model == null) return null;
    final m = model.toLowerCase().trim();
    if (m.contains('df53')) return 'assets/images/color_sorter/DF53Pro.jpg';
    if (m.contains('df36')) return 'assets/images/color_sorter/DF36Pro.jpg';
    if (m.contains('df21')) return 'assets/images/color_sorter/DF21Pro.jpg';
    if (m.contains('df12')) return 'assets/images/color_sorter/DF12Pro.jpg';
    if (m == 'sx8') return 'assets/images/color_sorter/sx8.jpg';
    if (m == 'h7') return 'assets/images/color_sorter/Hinh_anh H7.jpg';
    return null;
  }

  Map<String, dynamic>? _get3dConfig(Map<String, String> specs) {
    final model = (specs['model'] ?? '').toLowerCase().trim();
    if (model == 'df53 pro') {
      return {
        'modelName': specs['model'] ?? 'DF53 Pro',
        'modelPath': 'assets/models/df53_pro.glb',
        'posterPath': 'assets/images/color_sorter/DF53Pro.jpg',
        'dimensions': '${specs['dimensions_display_mm']} mm',
        'configuration': '5 tầng 6 máng',
        'technology': 'AI Deep Learning',
        'exposure': 0.35,
        'showHotspots': true,
      };
    }
    if (model == 'sx8') {
      return {
        'modelName': 'SX8',
        'modelPath': 'assets/models/sx8.glb',
        'posterPath': 'assets/images/color_sorter/sx8.jpg',
        'dimensions': '${specs['dimensions_display_mm']} mm',
        'configuration':
            '${specs['layers_qty']} tầng, ${specs['chutes_qty']} máng',
        'technology': 'AI · PLOV 3.0',
        'exposure': 0.25,
      };
    }
    if (model == 'h7') {
      return {
        // Tiêu đề màn hình 3D dùng tên nội bộ "H8" theo yêu cầu, tách biệt
        // với tên thương mại "H7" hiển thị ở các nơi khác trong app.
        'modelName': 'H8',
        'modelPath': 'assets/models/h7.glb',
        'posterPath': 'assets/images/color_sorter/Hinh_anh H7.jpg',
        'dimensions': '${specs['dimensions_display_mm']} mm',
        'configuration': '${specs['chutes_qty']} máng',
        'technology': 'AI · PLOV',
        // Hình học dựng từ nguồn Meshy AI (đã giản lược + làm mượt normal
        // có "ngưỡng góc gấp", giữ cạnh sắc, chỉ mượt bề mặt gần phẳng).
        // Texture màu của Meshy AI bị lỗi vân camo vàng-đen (không dùng
        // được) nên đã bỏ hẳn, thay bằng đúng màu + metallic/roughness của
        // material SC16 Pro để đồng nhất chất liệu giữa 2 model.
        'exposure': 0.85,
        'environmentImage': 'neutral',
      };
    }
    return null;
  }

  void _showImageZoomDialog(
    BuildContext context,
    String imagePath,
    String modelName,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.asset(imagePath, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Máy tách màu ${modelName.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  tooltip: 'Đóng ảnh',
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTechApplicationDialog(BuildContext context, String modelName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chi Tiết Ứng Dụng Thực Tế',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (modelName.toLowerCase().startsWith('h') || modelName.toLowerCase() == 'sx8')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue.shade50,
                          Colors.indigo.shade50.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Khả năng phân loại hạt',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Colors.blue.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Máy tách màu dòng H phù hợp với mọi nguyên liệu dạng hạt: hạt ít dầu, hạt nhiều dầu, hạt ít bụi, hạt nhiều bụi',
                          style: TextStyle(fontSize: 12.5, height: 1.35, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        _buildProFeatureRow(
                          'Công nghệ AI đột phá',
                          'Được hỗ trợ bởi công nghệ phân loại chất lượng AI, máy có khả năng nhận diện chính xác những khác biệt nhỏ về màu sắc, hình dạng, kích thước và vật liệu. Từ đó nâng cao toàn diện khả năng phân loại hình dáng và tạp chất.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Công nghệ đa phổ VNIR',
                          'Công nghệ tích hợp sâu đa phổ VNIR nhận diện chính xác những khác biệt nhỏ.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Công nghệ tự động thông minh',
                          'Nhận biết một cách thông minh những khác biệt nhỏ của nguyên liệu thô và giảm hao hụt.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Dễ dàng kết nối và giám sát',
                          'Kết nối dễ dàng với nhiều thiết bị đầu cuối khác nhau, điều khiển từ xa và phản hồi lập tức cho phép vận hành tự động.\n\nGiám sát sự thay đổi dòng liệu của dây chuyền sản xuất, điều chỉnh lưu lượng thông minh, tương tác và tích hợp hài hòa để hiện thực hóa quy trình sản xuất linh hoạt.',
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade50,
                          Colors.teal.shade50.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.shade300,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              'ĐẶC QUYỀN CÔNG NGHỆ DF PRO',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Colors.green.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildProFeatureRow(
                          'Tích hợp nền tảng tự học Deep Learning AI, công nghệ PLOV 3.0',
                          'giúp đạt được mức hiệu quả >20% về chất lượng và năng suất.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Tối ưu hóa khả năng phân biệt các kích cỡ lá trà',
                          'giảm thiểu vỡ vụn và hiện tượng chồng chéo nguyên liệu, tách hiệu quả cẫng, bồm, tạp chất... trong một lần xử lý.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Đáp ứng mọi bài toán phân loại',
                          'phù hợp với mọi loại trà và quy trình sản xuất, yêu cầu phân loại cao hoàn toàn nằm trong tầm kiểm soát.',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Đóng',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProFeatureRow(String label, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 6),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: Colors.black87,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 5.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
                color: color,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapacityOverview(String value) {
    final capacityBands = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final color = Colors.orange.shade800;

    return Container(
      key: const Key('multiline_capacity_overview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            Colors.orange.shade50.withValues(alpha: 0.55),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.speed, color: color, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Năng suất',
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...capacityBands.map((line) {
            final separator = line.indexOf(':');
            final materialSize = separator < 0
                ? line
                : line.substring(0, separator).trim();
            final capacity = separator < 0
                ? ''
                : line.substring(separator + 1).trim();
            return Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      materialSize.toLowerCase().contains('cà phê') ? Icons.coffee : Icons.grain_rounded,
                      color: color, 
                      size: 16
                    ),
                    const SizedBox(width: 7),
                    Text(
                      materialSize,
                      style: const TextStyle(
                        color: Color(0xFF5D4037),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      capacity,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showTechDescription(BuildContext context, String title) {
    String description = '';
    switch (title) {
      case 'Nền tảng PLOV 3.0':
        description = 'Đảm bảo nguyên liệu trên mỗi máng dẫn được trải đều, tránh chồng xếp lên nhau.';
        break;
      case 'AI':
      case 'Deep Learning AI':
        description = 'Bằng trí tuệ nhân tạo AI, mang tính đột phá cho ngành phân loại màu, đánh dấu bước tiến từ "nhận diện" sang "hiểu biết".';
        break;
      case 'Điện toán đám mây':
        description = 'Công nghệ phân loại chất lượng được hỗ trợ bởi AI, giúp xử lý tốc độ cao với các thuật toán thông minh và phân tích dữ liệu logic.';
        break;
      case 'Hợp nhất đa điểm ảnh':
        description = 'Căn cứ vào đặc điểm vùng quang phổ hồng ngoại từ đó phân biệt được nhiều nguyên liệu khác nhau về bản chất ngoại quang.';
        break;
      case 'Camera mắt diều hâu 3.0':
        description = 'Hệ thống camera mắt diều hâu kết hợp camera holographic nhận biết chính xác những khác biệt nhỏ về màu sắc và hình dạng.';
        break;
      case 'AI Deep Learning':
        description = '• Tự học và ghi nhớ đặc điểm vật liệu theo thời gian thực.\n• Phân tích – đánh giá mức độ lỗi từ đơn giản đến phức tạp.\n• Nhận diện chính xác các hạt lỗi ngay cả khi hình dạng và màu sắc gần tương đồng.\n• Mở ra khả năng phân loại không giới hạn, tối ưu chất lượng thành phẩm xuất khẩu.';
        break;
      case 'Công nghệ mắt diều hâu 3.0':
        description = '• Chụp sắc nét từng hạt vật liệu chuyển động ở vận tốc siêu cao.\n• Phân biệt rõ các hạt có sắc thái màu gần tương tự nhau (như đốm kim, bạc bụng nhẹ).\n• Tăng khả năng nhận diện nguyên liệu khó lên đến 50%.';
        break;
      case 'Công nghệ tích hợp đa điểm ảnh':
        description = '• Ánh sáng khả kiến (Visible): Tách các hạt khác màu.\n• Hồng ngoại gần (NIR): Nhận diện cấu trúc vật chất bên trong hạt.\n• Hồng ngoại sóng ngắn (SWIR): Phát hiện tạp chất vô cơ như nhựa trong, thủy tinh, đá sỏi.';
        break;
      case 'Công nghệ PLOV':
        description = '• Kiểm soát tối ưu biên độ và tần số rung máng trượt hợp kim chống mài mòn.\n• Phân phối hạt gạo dàn đều, chuyển động song song ổn định.\n• Triệt tiêu tình trạng hạt nhảy cẫng, tăng độ chính xác của tia phun tách.';
        break;
      case 'Công nghệ hút bụi độc lập':
        description = '• Hệ thống ống hút bụi khí động học bố trí riêng biệt tại từng máng.\n• Ngăn bụi bám vào thấu kính camera và đèn LED chiếu sáng.\n• Duy trì độ chính xác phân loại liên tục suốt ca làm việc 24/7.';
        break;
      default:
        description = 'Thông tin chi tiết công nghệ đang được cập nhật...';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.memory, color: Colors.blue[800], size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: const TextStyle(
              height: 1.6,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
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
        );
      },
    );
  }

  Widget _buildTechChip(
    BuildContext context,
    String text,
    MaterialColor color,
  ) {
    return ActionChip(
      onPressed: () => _showTechDescription(context, text),
      label: Text(text),
      labelStyle: TextStyle(
        color: color.shade800,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: color.shade50.withValues(alpha: 0.6),
      side: BorderSide(color: color.shade200, width: 0.8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildShareSection(
    BuildContext context,
    Map<String, dynamic> rawSpecs,
  ) {
    // Convert to String map for the dialog
    final specs = rawSpecs.map(
      (k, v) => MapEntry(_getDisplayName(k), v.toString()),
    );
    // Re-add 'Model' key which the dialog expects
    specs['Model'] = rawSpecs['model']?.toString() ?? 'DF';

    void openShareDialog() => showSpecImageExportDialog(
      context: context,
      specs: specs,
      imagePath: _getImagePath(rawSpecs['model']?.toString()),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ios_share_rounded, color: Color(0xFF168052), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Chia sẻ thông số cho khách hàng',
                  style: TextStyle(
                    color: Color(0xFF102F46),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('copy_tea_sorter_specs_btn'),
                  onPressed: openShareDialog,
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Chia sẻ text'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const Key('export_tea_sorter_specs_pdf_btn'),
                  onPressed: openShareDialog,
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                  label: const Text('Xuất PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String rawKey, String value, int index) {
    final key = _getDisplayName(rawKey);
    final specColor = _getColorForSpec(rawKey);
    final icon = _getIconForSpec(rawKey);
    final isMultiline = value.contains('\n');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
          child: isMultiline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: specColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 17, color: specColor),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: specColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: specColor.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: specColor,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: specColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 17, color: specColor),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      flex: 5,
                      child: Text(
                        key,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: specColor.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: specColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: specColor,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        Divider(
          height: 1,
          thickness: 0.6,
          indent: 60,
          endIndent: 16,
          color: Colors.grey.shade200,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông số kỹ thuật')),
      body: Consumer<TeaColorSorterProvider>(
        builder: (context, provider, child) {
          final specs = provider.specs;
          final selectedModel = provider.selectedModel;

          return Column(
            children: [
              // Quick Model Selector Chips
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                width: double.infinity,
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.availableModels.map((m) {
                      final isSelected =
                          m.toLowerCase() == selectedModel.toLowerCase();
                      final isPro = m.toLowerCase().contains('pro');

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m),
                              if (isPro) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.amber
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'AI',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.black87
                                          : Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          selectedColor: Colors.blue.shade800,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          backgroundColor: Colors.grey.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade800
                                  : Colors.grey.shade300,
                            ),
                          ),
                          onSelected: (_) => provider.selectModel(m),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Main Content Area
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : specs == null
                    ? const Center(
                        child: Text('Không tìm thấy thông số kỹ thuật'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'MÁY TÁCH MÀU ${(specs['model'] ?? 'DF').toUpperCase()}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Machine Image Card with Tap to Zoom & 3D Badge
                            if (_getImagePath(specs['model']) != null)
                              Builder(
                                builder: (context) {
                                  final model3dConfig = _get3dConfig(specs);
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showImageZoomDialog(
                                          context,
                                          _getImagePath(specs['model'])!,
                                          specs['model'] ?? 'DF',
                                        ),
                                        child: Container(
                                          height: 180,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Hero(
                                                tag:
                                                    'machine-image-${specs['model']}',
                                                child: Image.asset(
                                                  _getImagePath(
                                                    specs['model'],
                                                  )!,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Positioned(
                                                right: 12,
                                                bottom: 12,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.6),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.zoom_in,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      if (model3dConfig != null)
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            context.push(
                                              '/color_sorter_3d',
                                              extra: model3dConfig,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.view_in_ar,
                                            size: 20,
                                          ),
                                          label: const Text(
                                            'Xem Mô Hình 3D 360°',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.blue.shade900,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              // Application Material Image
                              if ((specs['model'] ?? '').toLowerCase().startsWith('h'))
                                Column(
                                  children: [
                                    const SizedBox(height: 14),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 12.0),
                                            child: Text(
                                              'Nguyên liệu máy có khả năng tách',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue.shade900,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.asset(
                                                'assets/images/color_sorter/Lieu-H.jpg',
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 14),
                            // Highlight Metrics
                            Builder(
                              builder: (context) {
                                final capText = specs['capacity_highlight'] ?? specs['capacity_display'] ?? '--';
                                if (capText.contains('\n') || capText.length > 15) {
                                  return Column(
                                    children: [
                                      _buildCapacityOverview(capText),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildHighlightCard(
                                            'Số Camera',
                                            specs['camera_qty'] ?? '--',
                                            Icons.camera_alt,
                                            Colors.blue.shade800,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildHighlightCard(
                                            'Số Ejector',
                                            specs['ejector_qty'] ?? '--',
                                            Icons.air,
                                            Colors.green.shade800,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                } else {
                                  return Row(
                                    children: [
                                      _buildHighlightCard(
                                        'Năng suất',
                                        capText,
                                        Icons.speed,
                                        Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildHighlightCard(
                                        'Số Camera',
                                        specs['camera_qty'] ?? '--',
                                        Icons.camera_alt,
                                        Colors.blue.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildHighlightCard(
                                        'Số Ejector',
                                        specs['ejector_qty'] ?? '--',
                                        Icons.air,
                                        Colors.green.shade800,
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            // Core Technologies Badges
                            if (specs['key_features'] != null)
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runAlignment: WrapAlignment.center,
                                  spacing: 6.0,
                                  runSpacing: 6.0,
                                  children: (specs['key_features'] as String)
                                      .split(';')
                                      .where((e) => e.trim().isNotEmpty)
                                      .map(
                                        (e) => e.trim().endsWith('.')
                                            ? e.trim().substring(
                                                0,
                                                e.trim().length - 1,
                                              )
                                            : e.trim(),
                                      )
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                        final colors = [
                                          Colors.blue,
                                          Colors.orange,
                                          Colors.purple,
                                          Colors.indigo,
                                          Colors.teal,
                                          Colors.brown,
                                        ];
                                        return _buildTechChip(
                                          context,
                                          entry.value,
                                          colors[entry.key % colors.length],
                                        );
                                      })
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 12),

                            // Highlighted Application Details Button
                            InkWell(
                              onTap: () => _showTechApplicationDialog(
                                context,
                                specs['model'] ?? 'DF',
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1E3A8A),
                                      Color(0xFF2563EB),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome,
                                        color: Colors.amberAccent,
                                        size: 17,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Chi Tiết Ứng Dụng',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white70,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade800,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thông số chi tiết',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Grouped Specifications Tabs
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFDDE3F5),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: TabBar(
                                controller: _tabController,
                                indicator: BoxDecoration(
                                  color: Colors.blue.shade800,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.shade900.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.blueGrey.shade600,
                                labelStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  height: 1.08,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.5,
                                  height: 1.08,
                                ),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                tabs: const [
                                  Tab(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Thông số\nkỹ thuật',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Hệ thống\nkhí nén',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  Tab(
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Lắp đặt',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tab Views
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, _) {
                                  List<String> visibleKeys = [];

                                  // For Tea, we put most specs in Tech Specs for now.
                                  if (_tabController.index == 0) {
                                    // Sắp xếp đồng bộ thông tin theo thứ tự yêu cầu
                                    final List<String> orderedKeys = [
                                      'capacity_display',
                                      'layers_qty',
                                      'chutes_qty',
                                      'ejector_qty',
                                      'ejector_per_chute',
                                      'camera_qty',
                                      'finished_quality_min_pct',
                                      'power_kw',
                                      'voltage_v',
                                      'frequency_hz',
                                    ];

                                    // Add any remaining keys that belong to tab 0 but weren't ordered
                                    final otherKeys = specs.keys
                                        .where(
                                          (k) =>
                                              !orderedKeys.contains(k) &&
                                              k != 'id' &&
                                              k != 'category' &&
                                              k != 'series' &&
                                              k != 'model' &&
                                              k != 'product_name' &&
                                              k != 'key_features' &&
                                              !k.contains('air_') &&
                                              !k.contains('dim_') &&
                                              k != 'dimensions_display_mm' &&
                                              k != 'weight_kg' &&
                                              k != 'capacity_max_kg_h',
                                        )
                                        .toList();

                                    visibleKeys = [...orderedKeys, ...otherKeys]
                                        .where((k) => specs.containsKey(k))
                                        .toList();
                                  } else if (_tabController.index == 1) {
                                    visibleKeys = specs.keys
                                        .where(
                                          (k) =>
                                              k == 'air_compressor' ||
                                              k == 'air_dryer' ||
                                              k == 'air_tank' ||
                                              k == 'air_filter' ||
                                              k == 'air_flow_m3_min',
                                        )
                                        .toList();
                                  } else {
                                    visibleKeys = specs.keys
                                        .where(
                                          (k) =>
                                              k == 'dimensions_display_mm' ||
                                              k == 'weight_kg',
                                        )
                                        .toList();
                                  }

                                  if (visibleKeys.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(32.0),
                                      child: Center(
                                        child: Text(
                                          'Thông tin đang cập nhật',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: [
                                      ...List.generate(
                                        visibleKeys.length,
                                        (index) => _buildSpecRow(
                                          visibleKeys[index],
                                          specs[visibleKeys[index]] ?? '',
                                          index,
                                        ),
                                      ),
                                      if (_tabController.index == 0) ...[
                                        Divider(
                                          height: 16,
                                          thickness: 0.7,
                                          indent: 14,
                                          endIndent: 14,
                                          color: Colors.blue.shade200,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            12,
                                          ),
                                          child: SizedBox(
                                            width: double.infinity,
                                            child: OutlinedButton.icon(
                                              key: const Key(
                                                'tea_aux_equip_button',
                                              ),
                                              onPressed: () {
                                                final modelName =
                                                    (specs['model'] ??
                                                            selectedModel)
                                                        .trim();
                                                final isDf53Pro =
                                                    modelName.toLowerCase() ==
                                                    'df53 pro';

                                                if (!isDf53Pro) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Chức năng đang được phát triển. Vui lòng quay lại sau!',
                                                          ),
                                                          duration: Duration(
                                                            seconds: 2,
                                                          ),
                                                        ),
                                                      );
                                                  return;
                                                }

                                                context.push(
                                                  '/tea_aux_equip',
                                                  extra: modelName,
                                                );
                                              },
                                              icon: Icon(
                                                Icons.settings_outlined,
                                                size: 18,
                                                color: Colors.blue.shade800,
                                              ),
                                              label: Text(
                                                'Thiết bị phụ trợ đồng bộ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.blue.shade300,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                backgroundColor:
                                                    Colors.blue.shade50,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Sales & ROI Quick Actions
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Chức năng Phân tích hoàn vốn đang được phát triển. Vui lòng quay lại sau!',
                                      ),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.analytics_outlined),
                                label: const Text('Phân tích hoàn vốn (ROI)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo.shade800,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildShareSection(context, specs),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
