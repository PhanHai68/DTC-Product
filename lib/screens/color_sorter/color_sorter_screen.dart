import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/color_sorter_provider.dart';
import '../../data/specs_data.dart';
import 'spec_image_export_dialog.dart';

class ColorSorterScreen extends StatefulWidget {
  const ColorSorterScreen({super.key, this.initialModel});

  final String? initialModel;

  @override
  State<ColorSorterScreen> createState() => _ColorSorterScreenState();
}

class _ColorSorterScreenState extends State<ColorSorterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconForSpec(String key) {
    if (key.contains('Năng suất')) return Icons.speed;
    if (key.contains('máng')) return Icons.density_medium;
    if (key.contains('ejector')) return Icons.scatter_plot;
    if (key.contains('Camera')) return Icons.camera_alt;
    if (key.contains('Công suất')) return Icons.electrical_services;
    if (key.contains('Điện áp')) return Icons.power;
    if (key.contains('Trọng lượng')) return Icons.scale;
    if (key.contains('Kích thước')) return Icons.straighten;
    if (key.contains('Áp suất')) return Icons.compress;
    if (key.contains('Lưu lượng')) return Icons.wind_power;
    if (key.contains('chính xác')) return Icons.verified;
    if (key.contains('phế phẩm') || key.contains('bắn phế')) {
      return Icons.change_circle;
    }
    if (key.contains('Máy nén khí')) return Icons.precision_manufacturing;
    if (key.contains('Bình tích') || key.contains('Bình chứa')) {
      return Icons.propane_tank;
    }
    if (key.contains('sàn')) return Icons.architecture;
    if (key.contains('Nguyên liệu')) return Icons.grain;
    return Icons.info_outline;
  }

  Color _getColorForSpec(String key) {
    if (key.contains('Năng suất')) return const Color(0xFFEA6C00);
    if (key.contains('máng') || key.contains('ejector')) {
      return const Color(0xFF0D47A1);
    }
    if (key.contains('Camera')) return const Color(0xFF1565C0);
    if (key.contains('chính xác')) return const Color(0xFF2E7D32);
    if (key.contains('phế phẩm') || key.contains('bắn phế')) {
      return const Color(0xFFB71C1C);
    }
    if (key.contains('Công suất') || key.contains('Điện')) {
      return const Color(0xFFF57F17);
    }
    if (key.contains('Áp suất') || key.contains('Lưu lượng')) {
      return const Color(0xFF006064);
    }
    if (key.contains('Trọng lượng')) return const Color(0xFF4A148C);
    if (key.contains('Kích thước') || key.contains('sàn')) {
      return const Color(0xFF1A237E);
    }
    return const Color(0xFF37474F);
  }

  String? _getImagePath(String? model) {
    if (model == null) return null;
    final m = model.toLowerCase().trim();
    if (m.contains('sc16 pro')) {
      return 'assets/images/color_sorter/sc12_pro.png';
    }
    if (m.contains('sc16')) return 'assets/images/color_sorter/sc16.jpeg';
    if (m.contains('sc12')) return 'assets/images/color_sorter/sc12_pro.png';
    if (m.contains('sc10')) return 'assets/images/color_sorter/sc10.jpeg';
    if (m.contains('sc8')) return 'assets/images/color_sorter/sc8.jpeg';
    if (m.contains('sc4')) return 'assets/images/color_sorter/sc4.jpeg';
    if (m.contains('s+80d'))
      return 'assets/images/color_sorter/may_phan_tich_mau_s80d.jpg';
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

  void _showTechDescription(BuildContext context, String title) {
    String description = '';
    switch (title) {
      case 'AI Deep Learning':
        description = '• Tự học và ghi nhớ đặc điểm vật liệu theo thời gian thực.\n• Phân tích – đánh giá mức độ lỗi từ đơn giản đến phức tạp.\n• Nhận diện chính xác các hạt lỗi ngay cả khi hình dạng và màu sắc gần tương đồng.\n• Mở ra khả năng phân loại không giới hạn, tối ưu chất lượng thành phẩm xuất khẩu.';
        break;
      case 'Analyzer Cloud Control':
        description = '• Kết nối dữ liệu và điều khiển các thiết bị trong dây chuyền sản xuất từ xa qua điện thoại/máy tính.\n• Cảnh báo sự cố tức thì và tự động tối ưu hóa thông số vận hành.\n• Quản lý và giám sát máy theo tiêu chuẩn nhà máy thông minh 4.0.';
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
      case 'Deep Learning AI':
        description = 'Mô hình lớn phân loại chất lượng bằng AI đa phương thức tận dụng sức mạnh điện toán để thiết lập mô hình phân loại nhanh hơn, phân biệt chính xác hơn, huấn luyện và triển khai mô hình nhanh hơn, cùng với khả năng phân tích dữ liệu tự động nâng cao.';
        break;
      case 'Nền tảng PLOV 3.0':
        description = 'Cấu trúc trãi liệu đồng đều thông minh đã được nâng cấp lên PLOV 3.0, đảm bảo nguyên liệu luôn được dàn đều mà không bị chồng chéo lên nhau trong suốt quá trình phân loại ở tốc độ cao và năng suất cao.';
        break;
      case 'Camera Hawkeye 4.0':
        description = 'Công nghệ AI kết hợp Camera Hawkeye cho phép chụp ảnh động tốc độ cao rõ nét hơn với khả năng nhận diện thông minh và chính xác hơn.';
        break;
      case 'Hợp nhất đa điểm ảnh MPF':
        description = 'Về cơ bản, công nghệ này phân biệt các chất khác nhau dựa trên các đặc điểm dấu vân tay quang phổ của từng loại vật liệu.';
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
                if (modelName == 'S+80D')
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1.2,
                      ),
                    ),
                    child: const Text(
                      'Máy phân tích mẫu S+80D với khả năng tự động lấy mẫu nhanh chóng và phân tích đến hơn 30 chỉ số trong nguyên liệu, S+ 80D đảm bảo độ chính xác cao trong mọi phép đo. Chỉ cần vài phút, kết quả chi tiết sẽ được cung cấp, hỗ trợ tối ưu hiệu suất cho các quy trình sản xuất hiện đại.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  )
                else ...[
                  // ⭐ ĐẶC QUYỀN DÒNG SC PRO
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade50,
                          Colors.orange.shade50.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade300,
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
                              'ĐẶC QUYỀN DÒNG SC PRO',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Colors.red.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildProFeatureRow(
                          'Trí tuệ nhân tạo AI',
                          'Nhận diện chính xác tuyệt đối các lỗi phức tạp.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Tích hợp máy phân tích mẫu S+80D',
                          'Phân tích hơn 30 chỉ số  gạo trong 3 phút.',
                        ),
                        const SizedBox(height: 6),
                        _buildProFeatureRow(
                          'Cloud Control',
                          'Giám sát mọi lúc trên Smartphone.',
                        ),
                      ],
                    ),
                  ),

                  // 🎨 Tách màu sắc
                  _buildAppCategoryCard(
                    emoji: '🎨',
                    title: 'Tách màu sắc',
                    content: 'Tách sạch gạo vàng, vàng mơ, hạt đỏ, hạt đen, bạc bụng toàn phần, bạc bụng một phần, chấm kim nhỏ nhất.',
                    cardColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    titleColor: const Color(0xFF1D4ED8),
                  ),

                  // ⬜ Tách hình dạng
                  _buildAppCategoryCard(
                    emoji: '⬜',
                    title: 'Tách hình dạng',
                    content: 'Tách riêng hạt tròn lẫn trong gạo dài hoặc ngược lại, phân loại hạt theo kích thước chiều dài/ngắn.',
                    cardColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                    titleColor: const Color(0xFF15803D),
                  ),

                  // 🔻 Tách tạp chất
                  _buildAppCategoryCard(
                    emoji: '🔻',
                    title: 'Tách tạp chất',
                    content: 'Loại bỏ được sạn, đá, mảnh nhựa màu/nhựa trong, bông cỏ, mảnh thủy tinh...',
                    cardColor: const Color(0xFFFFF7ED),
                    borderColor: const Color(0xFFFED7AA),
                    titleColor: const Color(0xFFC2410C),
                  ),

                  // ⇄ Chế độ bắn ngược
                  _buildAppCategoryCard(
                    emoji: '⇄',
                    title: 'Chế độ bắn ngược',
                    content: 'Có thể điều chỉnh tách hạt gạo tốt ra khỏi dòng gạo phế, tiết kiệm tối đa lượng khí nén tiêu thụ.',
                    cardColor: const Color(0xFFFAF5FF),
                    borderColor: const Color(0xFFE9D5FF),
                    titleColor: const Color(0xFF7E22CE),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Đóng',
                style: TextStyle(fontWeight: FontWeight.bold),
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
            color: Colors.red.shade700,
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

  Widget _buildAppCategoryCard({
    required String emoji,
    required String title,
    required String content,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: titleColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  /// Hộp thoại tư vấn chọn máy thông minh theo sản lượng (Dành cho Sales & Khách hàng)
  void _showAdvisorDialog(BuildContext context, ColorSorterProvider provider) {
    final TextEditingController capacityController = TextEditingController();
    Map<String, dynamic>? recommendation;

    showStatefulBuilderDialog(
      context: context,
      builder: (context, setState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Tư Vấn Chọn Máy Tối Ưu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nhập sản lượng cần tách của nhà máy để nhận gợi ý model và cấu hình đồng bộ phù hợp nhất:',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: capacityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Sản lượng mục tiêu (tấn/giờ)',
                    hintText: 'Ví dụ: 5, 8, 12, 18...',
                    prefixIcon: const Icon(Icons.speed),
                    suffixText: 'tấn/h',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (val) {
                    final cap = double.tryParse(val.replaceAll(',', '.'));
                    if (cap != null) {
                      setState(() {
                        recommendation = provider.suggestModelByCapacity(cap);
                      });
                    }
                  },
                ),
                if (recommendation != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Đề xuất: Model ${recommendation!['model']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recommendation!['reason'] ?? '',
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
            if (recommendation != null)
              ElevatedButton(
                onPressed: () {
                  final model = recommendation!['model'] as String;
                  provider.selectModel(model);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                child: Text('Xem chi tiết ${recommendation!['model']}'),
              ),
          ],
        );
      },
    );
  }

  /// Hộp thoại so sánh linh hoạt 2 model bất kỳ
  void _showUniversalComparisonDialog(
    BuildContext context,
    ColorSorterProvider provider,
  ) {
    String model1 = provider.selectedModel;
    String model2 = model1.toLowerCase().contains('pro')
        ? 'SC16'
        : (model1 == 'SC16' ? 'SC16 Pro' : 'SC12');

    showStatefulBuilderDialog(
      context: context,
      builder: (context, setState) {
        final spec1 = provider.getSpecByModel(model1);
        final spec2 = provider.getSpecByModel(model2);

        final allKeys = [
          'Phân khúc',
          'Năng suất (tấn/giờ)',
          'Số máng',
          'Số ejector',
          'Số Camera',
          'Độ chính xác phân loại',
          'Tỉ lệ phế phẩm',
          'Công suất điện (kW)',
          'Điện áp',
          'Áp suất khí nén',
          'Lưu lượng khí tiêu thụ',
          'Trọng lượng (kg)',
          'Kích thước (D x R x C mm)',
          'Kích thước sàn đặt máy',
          'Máy nén khí đồng bộ',
          'Bình tích khí đồng bộ',
        ];

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'So Sánh Trực Quan 2 Model',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                // Chọn 2 model
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: model1,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: colorSorterSpecs
                              .map((e) => e['Model']!)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => model1 = val);
                          },
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.compare_arrows, color: Colors.blue),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: model2,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: colorSorterSpecs
                              .map((e) => e['Model']!)
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => model2 = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: allKeys.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final key = allKeys[index];
                      final val1 = spec1?[key] ?? '-';
                      final val2 = spec2?[key] ?? '-';
                      final bool isDiff = val1 != val2;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        color: isDiff
                            ? Colors.blue.withValues(alpha: 0.04)
                            : Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              key,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    val1,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isDiff
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    val2,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isDiff
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
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

  Widget _buildShareSection(BuildContext context, Map<String, String> specs) {
    void openShareDialog() => showSpecImageExportDialog(
      context: context,
      specs: specs,
      imagePath: _getImagePath(specs['Model']),
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
                  key: const Key('copy_color_sorter_specs_btn'),
                  onPressed: openShareDialog,
                  icon: const Icon(Icons.text_snippet_outlined, size: 18),
                  label: const Text('Chia sẻ text'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  key: const Key('export_color_sorter_specs_pdf_btn'),
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

  Widget _buildSpecRow(String key, String value, int index) {
    final specColor = _getColorForSpec(key);
    final icon = _getIconForSpec(key);
    final bool isLast = false; // divider always except explicitly removed
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11.0, horizontal: 16.0),
          child: Row(
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
        if (!isLast)
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
    return ChangeNotifierProvider(
      create: (_) {
        final provider = ColorSorterProvider();
        final initialModel = widget.initialModel;
        if (initialModel != null && initialModel.trim().isNotEmpty) {
          provider.selectModel(initialModel);
        }
        return provider;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Thông số kỹ thuật Máy Tách Màu'),
          actions: [
            Consumer<ColorSorterProvider>(
              builder: (context, provider, _) => IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Tư vấn chọn máy',
                onPressed: () => _showAdvisorDialog(context, provider),
              ),
            ),
            Consumer<ColorSorterProvider>(
              builder: (context, provider, _) => IconButton(
                icon: const Icon(Icons.compare_arrows),
                tooltip: 'So sánh model',
                onPressed: () =>
                    _showUniversalComparisonDialog(context, provider),
              ),
            ),
          ],
        ),
        body: Consumer<ColorSorterProvider>(
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
                      children:
                          [
                            'SC16 Pro',
                            'SC12',
                            'SC10',
                            'SC8',
                            'SC4',
                            'S+80D',
                          ].map((m) {
                            final isSelected =
                                m.toLowerCase() == selectedModel.toLowerCase();
                            final isPro = m.toLowerCase().contains('pro');

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
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
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
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
                                specs['Model'] == 'S+80D'
                                    ? 'MÁY PHÂN TÍCH MẪU S+80D'
                                    : 'MÁY TÁCH MÀU ${(specs['Model'] ?? 'SC').toUpperCase()}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Machine Image Card with Tap to Zoom & 3D Badge
                              if (_getImagePath(specs['Model']) != null)
                                Builder(
                                  builder: (context) {
                                    final is3dAvailable =
                                        specs['Model']?.toLowerCase().contains(
                                          'pro',
                                        ) ==
                                        true;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        GestureDetector(
                                          onTap: () => _showImageZoomDialog(
                                            context,
                                            _getImagePath(specs['Model'])!,
                                            specs['Model']!,
                                          ),
                                          child: Container(
                                            height: 180,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Stack(
                                              children: [
                                                Center(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: Image.asset(
                                                      _getImagePath(
                                                        specs['Model'],
                                                      )!,
                                                      fit: BoxFit.contain,
                                                    ),
                                                  ),
                                                ),
                                                // 3D badge on image
                                                if (specs['Model'] == 'S+80D')
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            LinearGradient(
                                                              colors: [
                                                                Colors
                                                                    .blue
                                                                    .shade700,
                                                                Colors
                                                                    .purple
                                                                    .shade700,
                                                              ],
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.blue
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                ),
                                                            blurRadius: 6,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: const [
                                                          Icon(
                                                            Icons.auto_awesome,
                                                            color: Colors.white,
                                                            size: 16,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            'AI',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                else if (is3dAvailable)
                                                  Positioned(
                                                    top: 8,
                                                    right: 8,
                                                    child: InkWell(
                                                      onTap: () {
                                                        context.push(
                                                          '/color_sorter_3d',
                                                          extra: {
                                                            'modelName':
                                                                specs['Model'] ??
                                                                'SC16 Pro',
                                                            'modelPath': 'assets/models/sc16_pro.glb',
                                                          },
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          gradient:
                                                              LinearGradient(
                                                                colors: [
                                                                  Colors
                                                                      .blue
                                                                      .shade800,
                                                                  Colors
                                                                      .indigo
                                                                      .shade800,
                                                                ],
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors.blue
                                                                  .withValues(
                                                                    alpha: 0.3,
                                                                  ),
                                                              blurRadius: 6,
                                                              offset:
                                                                  const Offset(
                                                                    0,
                                                                    2,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: const [
                                                            Icon(
                                                              Icons
                                                                  .threed_rotation,
                                                              color:
                                                                  Colors.white,
                                                              size: 16,
                                                            ),
                                                            SizedBox(width: 5),
                                                            Text(
                                                              'Mô hình 3D',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                // Zoom hint
                                                Positioned(
                                                  bottom: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black54,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: const [
                                                        Icon(
                                                          Icons.zoom_in,
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Chạm để phóng to',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (is3dAvailable) ...[
                                          const SizedBox(height: 10),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              context.push(
                                                '/color_sorter_3d',
                                                extra: {
                                                  'modelName':
                                                      specs['Model'] ??
                                                      'SC16 Pro',
                                                  'modelPath': 'assets/models/sc16_pro.glb',
                                                },
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
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                      ],
                                    );
                                  },
                                ),
                              const SizedBox(height: 14),

                              // Highlight Metrics
                              if (specs['Model'] != 'S+80D') ...[
                                Row(
                                  children: [
                                    if (specs['Năng suất (tấn/giờ)'] !=
                                        null) ...[
                                      _buildHighlightCard(
                                        'Năng suất (T/h)',
                                        specs['Năng suất (tấn/giờ)']!,
                                        Icons.speed,
                                        Colors.orange.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    _buildHighlightCard(
                                      'Số Camera',
                                      specs['Số Camera'] ?? '--',
                                      Icons.camera_alt,
                                      Colors.blue.shade800,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildHighlightCard(
                                      'Số Ejector',
                                      specs['Số ejector'] ?? '--',
                                      Icons.air,
                                      Colors.green.shade800,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                              ],
                              const SizedBox(height: 14),

                              // Core Technologies Badges - Center Aligned
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runAlignment: WrapAlignment.center,
                                  spacing: 6.0,
                                  runSpacing: 6.0,
                                  children: [
                                    if (specs['Model'] == 'S+80D') ...[
                                      _buildTechChip(
                                        context,
                                        'Deep Learning AI',
                                        Colors.blue,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Nền tảng PLOV 3.0',
                                        Colors.orange,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Camera Hawkeye 4.0',
                                        Colors.purple,
                                      ),
                                    ] else if (specs['Model']
                                            ?.toLowerCase()
                                            .contains('pro') ==
                                        true) ...[
                                      _buildTechChip(
                                        context,
                                        'AI Deep Learning',
                                        Colors.blue,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Analyzer Cloud Control',
                                        Colors.orange,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ mắt diều hâu 3.0',
                                        Colors.purple,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ tích hợp đa điểm ảnh',
                                        Colors.indigo,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ PLOV',
                                        Colors.teal,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ hút bụi độc lập',
                                        Colors.blueGrey,
                                      ),
                                    ] else ...[
                                      _buildTechChip(
                                        context,
                                        'Công nghệ mắt diều hâu 3.0',
                                        Colors.purple,
                                      ),

                                      _buildTechChip(
                                        context,
                                        'Công nghệ tích hợp đa điểm ảnh',
                                        Colors.indigo,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ PLOV',
                                        Colors.teal,
                                      ),
                                      _buildTechChip(
                                        context,
                                        'Công nghệ hút bụi độc lập',
                                        Colors.brown,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Highlighted Application Details Button
                              InkWell(
                                onTap: () => _showTechApplicationDialog(
                                  context,
                                  specs['Model']!,
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

                              // Section label
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

                              // Grouped Specifications Tabs – Pill style
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
                                  unselectedLabelColor:
                                      Colors.blueGrey.shade600,
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
                                      height: 48,
                                      child: Text(
                                        'Thông số\nkỹ thuật',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Tab(
                                      height: 48,
                                      child: Text(
                                        'Hệ thống\nkhí nén',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Tab(height: 48, text: 'Lắp đặt'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Tab content mapped to sections
                              AnimatedBuilder(
                                animation: _tabController,
                                builder: (context, _) {
                                  final tabIndex = _tabController.index;

                                  if (tabIndex == 1) {
                                    // Hệ Thống Khí Nén
                                    if (specs['Model'] == 'S+80D') {
                                      return Container(
                                        padding: const EdgeInsets.all(24),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          'Dòng máy phân tích không yêu cầu hệ thống khí nén',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      );
                                    }

                                    // custom icon-chip grid layout
                                    final compressor =
                                        specs['Máy nén khí đồng bộ'] != null
                                        ? 'Máy nén khí ${specs['Máy nén khí đồng bộ']}'
                                        : 'Máy nén khí 100HP';
                                    final tank =
                                        specs['Bình tích khí đồng bộ'] != null
                                        ? 'Bình tích khí ${specs['Bình tích khí đồng bộ']}'
                                        : 'Bình tích khí 2000 lít';

                                    final khiNenItems = [
                                      (
                                        compressor,
                                        Icons.compress,
                                        const Color(0xFF006064),
                                      ),
                                      (
                                        'Máy sấy khí đi kèm',
                                        Icons.air,
                                        const Color(0xFF01579B),
                                      ),
                                      (
                                        tank,
                                        Icons.propane_tank,
                                        const Color(0xFF1B5E20),
                                      ),
                                      (
                                        'Bộ lọc thô và bộ lọc tinh',
                                        Icons.filter_alt,
                                        const Color(0xFF4A148C),
                                      ),
                                    ];
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.04,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          ...khiNenItems.asMap().entries.map((
                                            entry,
                                          ) {
                                            final i = entry.key;
                                            final (label, icon, color) =
                                                entry.value;
                                            final isLastItem =
                                                i == khiNenItems.length - 1;
                                            return Column(
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 12,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              color.withValues(
                                                                alpha: 0.18,
                                                              ),
                                                              color.withValues(
                                                                alpha: 0.08,
                                                              ),
                                                            ],
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          icon,
                                                          size: 20,
                                                          color: color,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 14),
                                                      Expanded(
                                                        child: Text(
                                                          label,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF1A1A2E,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color:
                                                              const Color(
                                                                0xFF1B5E20,
                                                              ).withValues(
                                                                alpha: 0.1,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                const Color(
                                                                  0xFF2E7D32,
                                                                ).withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .check_circle_outline,
                                                              size: 13,
                                                              color: Color(
                                                                0xFF2E7D32,
                                                              ),
                                                            ),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Có sẵn',
                                                              style: TextStyle(
                                                                fontSize: 11.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Color(
                                                                  0xFF2E7D32,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (!isLastItem)
                                                  Divider(
                                                    height: 1,
                                                    thickness: 0.6,
                                                    indent: 70,
                                                    endIndent: 16,
                                                    color: Colors.grey.shade200,
                                                  ),
                                              ],
                                            );
                                          }),
                                          // Banner khuyến cáo ACOMP
                                          Container(
                                            margin: const EdgeInsets.fromLTRB(
                                              12,
                                              8,
                                              12,
                                              12,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFFFF8E1),
                                                  Color(0xFFFFF3CD),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFFFB300)
                                                    .withValues(alpha: 0.6),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFF8F00,
                                                    ).withValues(alpha: 0.15),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .verified_user_outlined,
                                                    size: 18,
                                                    color: Color(0xFFE65100),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                const Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Khuyến cáo từ DTC',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Color(
                                                            0xFFBF360C,
                                                          ),
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Sử dụng hệ thống máy nén khí chuyên dụng ACOMP để đảm bảo nguồn khí sạch, áp suất ổn định — bảo vệ ejector và kéo dài tuổi thọ máy tách màu.',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Color(
                                                            0xFF5D4037,
                                                          ),
                                                          height: 1.45,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  List<String> currentKeys = [];
                                  if (specs['Model'] == 'S+80D') {
                                    if (tabIndex == 0) {
                                      currentKeys = [
                                        'Công suất điện (kw)',
                                        'Điện áp (V/Hz)',
                                        'Trọng lượng (Kg)',
                                        'Kích thước (DxRxC) (mm)',
                                      ];
                                    }
                                  } else {
                                    if (tabIndex == 0) {
                                      currentKeys = [
                                        'Năng suất (tấn/giờ)',
                                        'Số máng',
                                        'Số ejector',
                                        'Số ejector/ máng',
                                        'Số Camera',
                                        'Độ chính xác phân loại',
                                        'Tỉ lệ phế phẩm',
                                      ];
                                    } else {
                                      currentKeys = [
                                        'Công suất điện (kW)',
                                        'Điện áp',
                                        'Trọng lượng (kg)',
                                        'Kích thước (D x R x C mm)',
                                        'Kích thước sàn đặt máy',
                                      ];
                                    }
                                  }
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: currentKeys.asMap().entries.map(
                                        (entry) {
                                          final key = entry.value;
                                          final val = specs[key] ?? '--';
                                          return _buildSpecRow(
                                            key,
                                            val,
                                            entry.key,
                                          );
                                        },
                                      ).toList(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),

                              // Thiết bị phụ trợ
                              if (specs['Model'] != 'S+80D') ...[
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50.withValues(
                                      alpha: 0.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.teal.shade100,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          12,
                                          12,
                                          0,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.settings_outlined,
                                                color: Colors.teal.shade800,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                'Thiết bị phụ trợ đồng bộ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13.5,
                                                  color: Colors.teal.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Divider(
                                        height: 16,
                                        thickness: 0.7,
                                        indent: 14,
                                        endIndent: 14,
                                        color: Colors.teal.shade200,
                                      ),
                                      // CTA Button
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
                                            onPressed: () {
                                              context.push(
                                                '/aux_equip',
                                                extra: specs['Model'],
                                              );
                                            },
                                            icon: Icon(
                                              Icons.open_in_new,
                                              size: 16,
                                              color: Colors.teal.shade800,
                                            ),
                                            label: Text(
                                              'Xem thiết bị phụ trợ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Colors.teal.shade800,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 11,
                                                    horizontal: 16,
                                                  ),
                                              side: BorderSide(
                                                color: Colors.teal.shade400,
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Sales & ROI Quick Actions
                                ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/payback_analysis');
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
                                const SizedBox(height: 16),
                              ],
                              _buildShareSection(context, specs),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
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
}

/// Helper function to show stateful builder dialog
void showStatefulBuilderDialog({
  required BuildContext context,
  required Widget Function(BuildContext, void Function(void Function()))
  builder,
}) {
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: builder),
  );
}
