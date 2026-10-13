import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/technology_menu.dart';
import '../document_library_catalog.dart';

/// Thư viện tài liệu: chọn sản phẩm.
class DocumentLibraryScreen extends StatelessWidget {
  const DocumentLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: 'Thư viện tài liệu',
      backButtonKey: const Key('documents_back_button'),
      entries: [
        for (final product in docProducts)
          TechnologyMenuEntry(
            id: 'documents_${product.id}',
            title: product.title,
            icon: Icons.folder_copy_outlined,
            imagePath: product.imagePath,
            featured: true,
            onTap: () => context.push('/documents/product/${product.id}'),
          ),
        TechnologyMenuEntry(
          id: 'documents_all',
          title: 'Tất cả tài liệu',
          subtitle: 'Duyệt toàn bộ thư mục Google Drive',
          icon: Icons.cloud_outlined,
          onTap: () => context.push('/documents/folder'),
        ),
      ],
    );
  }
}

/// Tài liệu của một sản phẩm: chọn loại tài liệu.
class DocumentProductScreen extends StatelessWidget {
  const DocumentProductScreen({super.key, required this.product});

  final DocProduct product;

  @override
  Widget build(BuildContext context) {
    return TechnologyMenuScaffold(
      title: product.title,
      backButtonKey: const Key('documents_product_back_button'),
      entries: [
        for (final type in docTypes)
          TechnologyMenuEntry(
            id: 'documents_${product.id}_${type.id}',
            title: type.title,
            icon: type.icon,
            featured: true,
            onTap: () =>
                context.push('/documents/product/${product.id}/${type.id}'),
          ),
      ],
    );
  }
}
