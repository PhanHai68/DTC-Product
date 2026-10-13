import 'package:flutter/material.dart';

/// Cấu trúc cố định của thư viện tài liệu: sản phẩm → loại tài liệu.
///
/// Trên Google Drive, thư mục gốc chứa mỗi sản phẩm một thư mục, trong đó có
/// các thư mục loại tài liệu, ví dụ `Máy tách màu/Catalogue/<file>.pdf`. Tên thư
/// mục được so khớp bằng [normalizeDriveName] nên không phân biệt hoa thường,
/// dấu tiếng Việt hay ký tự `/`, `-`, khoảng trắng.
class DocProduct {
  const DocProduct({
    required this.id,
    required this.title,
    required this.imagePath,
    this.aliases = const [],
  });

  final String id;
  final String title;
  final String imagePath;
  final List<String> aliases;

  /// Tên thư mục trên Drive: viết hoa chữ đầu, tiếng Việt có dấu.
  String get folderName => title;
  List<String> get matchNames => [title, ...aliases];
}

class DocType {
  const DocType({
    required this.id,
    required this.title,
    required this.icon,
    this.aliases = const [],
  });

  final String id;
  final String title;
  final IconData icon;
  final List<String> aliases;

  /// Tên thư mục trên Drive: viết hoa chữ đầu, tiếng Việt có dấu.
  String get folderName => title;
  List<String> get matchNames => [title, ...aliases];
}

const docProducts = [
  DocProduct(
    id: 'color_sorter',
    title: 'Máy tách màu',
    imagePath: 'assets/images/home_color_sorter_5_chutes_v5.png',
  ),
  DocProduct(
    id: 'packing',
    title: 'Cân đóng gói',
    imagePath: 'assets/images/home_packing_lzb1200.jpg',
  ),
  DocProduct(
    id: 'compressor',
    title: 'Máy nén khí',
    imagePath: 'assets/images/home_air_compressor_v5.png',
  ),
  DocProduct(
    id: 'grinding',
    title: 'Máy nghiền',
    imagePath: 'assets/images/home_grinding_machine_asp350.png',
  ),
  DocProduct(
    id: 'rice_milling',
    title: 'Xay xát lúa gạo',
    imagePath: 'assets/images/home_rice_milling.jpg',
    aliases: ['Xay xát Lúa-Gạo'],
  ),
];

const docTypes = [
  DocType(
    id: 'catalogue',
    title: 'Catalogue',
    icon: Icons.menu_book_outlined,
    aliases: ['Catalog', 'Cataloge'],
  ),
  DocType(
    id: 'specs',
    title: 'Bảng thông số kỹ thuật',
    icon: Icons.table_chart_outlined,
    aliases: ['Thông số kỹ thuật'],
  ),
  DocType(
    id: 'drawings',
    title: 'Bản vẽ lắp đặt',
    icon: Icons.architecture_outlined,
    aliases: ['Bản vẽ'],
  ),
  DocType(
    id: 'media',
    title: 'Video - hình ảnh',
    icon: Icons.perm_media_outlined,
    aliases: ['Video/hình ảnh', 'Hình ảnh - video', 'Video', 'Hình ảnh'],
  ),
  DocType(
    id: 'manuals',
    title: 'Hướng dẫn vận hành',
    icon: Icons.integration_instructions_outlined,
    aliases: ['Hướng dẫn sử dụng'],
  ),
];

DocProduct? docProductById(String? id) {
  for (final product in docProducts) {
    if (product.id == id) return product;
  }
  return null;
}

DocType? docTypeById(String? id) {
  for (final type in docTypes) {
    if (type.id == id) return type;
  }
  return null;
}

const _vietnameseBase = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final _baseOf = {
  for (final entry in _vietnameseBase.entries)
    for (final char in entry.value.split('')) char: entry.key,
};

final _keep = RegExp(r'[a-z0-9]');

/// Chuẩn hóa tên để so khớp: chữ thường, bỏ dấu (cả dạng dấu tách rời mà
/// macOS hay tạo), chỉ giữ chữ và số. "Video/Hình ảnh" == "video - hinh anh".
String normalizeDriveName(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0x300 && rune <= 0x36F) continue;
    final char = String.fromCharCode(rune);
    final base = _baseOf[char] ?? char;
    if (_keep.hasMatch(base)) buffer.write(base);
  }
  return buffer.toString();
}
