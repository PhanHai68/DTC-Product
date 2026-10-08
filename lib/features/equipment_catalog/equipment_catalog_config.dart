import 'package:flutter/material.dart';

/// Cấu hình 1 catalog thiết bị đi kèm máy nghiền (đóng gói, trộn, sàng).
/// Mọi màn hình catalog dùng chung code, chỉ khác dữ liệu và các nhãn ở đây.
class EquipmentCatalogConfig {
  const EquipmentCatalogConfig({
    required this.id,
    required this.assetPath,
    required this.title,
    required this.menuTitle,
    required this.productLabel,
    required this.routeBase,
    required this.icon,
    required this.menuImage,
    required this.searchExample,
    required this.chipKeys,
    required this.selectorCtaDescription,
  });

  /// Tiền tố key widget và khoá trong provider (packing / mixer / sifter).
  final String id;
  final String assetPath;

  /// Tiêu đề màn hình, VD "Máy đóng gói".
  final String title;

  /// Tên trên menu trung gian, VD "Máy trộn (Mixer)".
  final String menuTitle;

  /// Tên loại máy viết thường dùng trong câu, VD "máy đóng gói".
  final String productLabel;
  final String routeBase;
  final IconData icon;
  final String menuImage;

  /// Model ví dụ trong ô tìm kiếm, VD "ASPM-520".
  final String searchExample;

  /// Các ô giá trị trên thẻ model: mỗi nhóm lấy khoá thông số đầu tiên mà
  /// model có (VD dung tích làm việc, không có thì tổng dung tích).
  final List<List<String>> chipKeys;
  final String selectorCtaDescription;

  String get upperLabel => productLabel.toUpperCase();
}

abstract final class EquipmentCatalogs {
  static const packing = EquipmentCatalogConfig(
    id: 'packing',
    assetPath: 'assets/database/packing_machine_catalog.json',
    title: 'Máy đóng gói',
    menuTitle: 'Máy đóng gói',
    productLabel: 'máy đóng gói',
    routeBase: '/packing_machine',
    icon: Icons.inventory_2_outlined,
    menuImage: 'assets/images/catalog_packing_aspm_vertical.png',
    searchExample: 'ASPM-520',
    chipKeys: [
      ['pack_weight'],
      ['speed'],
    ],
    selectorCtaDescription:
        'Nhập dạng nguyên liệu, khối lượng gói, tốc độ và bao bì để được gợi '
        'ý model phù hợp.',
  );

  static const mixer = EquipmentCatalogConfig(
    id: 'mixer',
    assetPath: 'assets/database/mixer_machine_catalog.json',
    title: 'Máy trộn',
    menuTitle: 'Máy trộn (Mixer)',
    productLabel: 'máy trộn',
    routeBase: '/mixer_machine',
    icon: Icons.blender_outlined,
    menuImage: 'assets/images/catalog_mixer_ribbon.png',
    searchExample: 'ASR-1000',
    chipKeys: [
      ['work_volume', 'total_volume'],
      ['power_kw'],
    ],
    selectorCtaDescription:
        'Nhập dung tích mẻ trộn, khối lượng mẻ và dạng nguyên liệu để được '
        'gợi ý model phù hợp.',
  );

  static const sifter = EquipmentCatalogConfig(
    id: 'sifter',
    assetPath: 'assets/database/sifter_machine_catalog.json',
    title: 'Máy sàng',
    menuTitle: 'Máy sàng (Sifter)',
    productLabel: 'máy sàng',
    routeBase: '/sifter_machine',
    icon: Icons.grid_on_rounded,
    menuImage: 'assets/images/catalog_sifter_vibro.png',
    searchExample: 'ASST-1000',
    chipKeys: [
      ['capacity'],
      ['mesh'],
    ],
    selectorCtaDescription:
        'Nhập năng suất, cỡ lưới và dạng nguyên liệu để được gợi ý model phù '
        'hợp.',
  );

  /// Dây chuyền xay xát lúa - gạo: mục riêng ở Home, không nằm trong menu
  /// máy nghiền.
  static const riceMilling = EquipmentCatalogConfig(
    id: 'rice_milling',
    assetPath: 'assets/database/rice_milling_catalog.json',
    title: 'Xay xát Lúa - Gạo',
    menuTitle: 'Xay xát Lúa - Gạo',
    productLabel: 'thiết bị xay xát',
    routeBase: '/rice_milling',
    icon: Icons.rice_bowl_outlined,
    menuImage: 'assets/images/home_rice_milling.jpg',
    searchExample: 'MLGQ36B',
    chipKeys: [
      ['capacity', 'capacity_long', 'capacity_paddy', 'air_flow'],
      ['power_kw', 'weight'],
    ],
    selectorCtaDescription:
        'Chọn công đoạn, nhập năng suất dây chuyền và giới hạn công suất '
        'điện để được gợi ý model phù hợp.',
  );

  /// Thiết bị dây chuyền bột, hiện trong menu "Máy nghiền".
  static const powderLine = [packing, mixer, sifter];

  static const all = [...powderLine, riceMilling];

  static EquipmentCatalogConfig byId(String id) =>
      all.firstWhere((c) => c.id == id);
}
