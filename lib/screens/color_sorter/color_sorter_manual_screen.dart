import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ColorSorterManualScreen extends StatefulWidget {
  const ColorSorterManualScreen({super.key});

  @override
  State<ColorSorterManualScreen> createState() =>
      _ColorSorterManualScreenState();
}

class _ColorSorterManualScreenState extends State<ColorSorterManualScreen> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _pdfController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          if (_isSearchVisible) _buildSearchBar(),
          Expanded(child: _buildPdfViewer()),
        ],
      ),
      bottomNavigationBar: _buildPageNavigator(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài liệu vận hành',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          Text(
            'SC16 Pro - Hướng dẫn kỹ thuật',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade200,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchVisible ? Icons.search_off : Icons.search,
            color: Colors.white,
          ),
          tooltip: 'Tìm kiếm',
          onPressed: () {
            setState(() {
              _isSearchVisible = !_isSearchVisible;
              if (!_isSearchVisible) {
                _pdfController.clearSelection();
              }
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.first_page, color: Colors.white),
          tooltip: 'Về đầu trang',
          onPressed: () => _pdfController.jumpToPage(1),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'last') {
              _pdfController.jumpToPage(_totalPages);
            } else if (value == 'zoom_in') {
              _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25)
                  .clamp(0.5, 4.0);
            } else if (value == 'zoom_out') {
              _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25)
                  .clamp(0.5, 4.0);
            } else if (value == 'zoom_fit') {
              _pdfController.zoomLevel = 1.0;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'zoom_in',
              child: ListTile(
                leading: Icon(Icons.zoom_in),
                title: Text('Phóng to'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'zoom_out',
              child: ListTile(
                leading: Icon(Icons.zoom_out),
                title: Text('Thu nhỏ'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'zoom_fit',
              child: ListTile(
                leading: Icon(Icons.fit_screen),
                title: Text('Vừa màn hình'),
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'last',
              child: ListTile(
                leading: Icon(Icons.last_page),
                title: Text('Về cuối tài liệu'),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF283593),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nhập từ cần tìm...',
                hintStyle: TextStyle(color: Colors.blue.shade200),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.blue.shade200,
                  size: 20,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _pdfController.searchText(value);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              if (_searchController.text.isNotEmpty) {
                _pdfController.searchText(_searchController.text);
              }
            },
            child: const Text('Tìm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Stack(
      children: [
        SfPdfViewer.asset(
          'assets/docs/SC16Pro_VanHanh.pdf',
          key: _pdfViewerKey,
          controller: _pdfController,
          pageLayoutMode: PdfPageLayoutMode.continuous,
          scrollDirection: PdfScrollDirection.vertical,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onDocumentLoaded: (details) {
            setState(() {
              _isLoading = false;
              _totalPages = details.document.pages.count;
            });
          },
          onDocumentLoadFailed: (details) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
          onPageChanged: (details) {
            setState(() {
              _currentPage = details.newPageNumber;
            });
          },
        ),
        if (_isLoading) _buildLoadingOverlay(),
        if (_hasError) _buildErrorOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Color(0xFF3F51B5),
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Đang tải tài liệu...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'SC16 Pro - Hướng dẫn kỹ thuật vận hành',
              style: TextStyle(color: Colors.blue.shade300, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade300, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Không thể tải tài liệu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vui lòng kiểm tra lại ứng dụng',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNavigator() {
    if (_totalPages == 0) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFF1A237E),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
            tooltip: 'Trang trước',
            onPressed: _currentPage > 1
                ? () => _pdfController.jumpToPage(_currentPage - 1)
                : null,
          ),
          GestureDetector(
            onTap: _showGoToPageDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Trang $_currentPage / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    color: Colors.white54,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 28,
            ),
            tooltip: 'Trang sau',
            onPressed: _currentPage < _totalPages
                ? () => _pdfController.jumpToPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  void _showGoToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đến trang'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Nhập số trang (1 - $_totalPages)',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            final page = int.tryParse(value);
            if (page != null && page >= 1 && page <= _totalPages) {
              _pdfController.jumpToPage(page);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _pdfController.jumpToPage(page);
                Navigator.pop(context);
              }
            },
            child: const Text('Đến'),
          ),
        ],
      ),
    );
  }
}
