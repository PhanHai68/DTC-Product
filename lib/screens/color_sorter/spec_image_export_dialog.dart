import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/pdf_export_service.dart';

Future<void> showSpecImageExportDialog({
  required BuildContext context,
  required Map<String, String> specs,
  String? imagePath,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    builder: (_) => SpecImageExportDialog(specs: specs, imagePath: imagePath),
  );
}

String buildColorSorterSpecShareText({
  required Map<String, String> specs,
  required String contactName,
  required String contactPhone,
}) {
  final model = specs['Model'] ?? 'SC';
  final buffer = StringBuffer()
    ..writeln('📋 THÔNG SỐ KỸ THUẬT MÁY TÁCH MÀU ${model.toUpperCase()}')
    ..writeln()
    ..writeln('• Năng suất: ${specs['Năng suất (tấn/giờ)'] ?? '--'} tấn/giờ')
    ..writeln(
      '• Số máng / Ejector: ${specs['Số máng'] ?? '--'} máng / '
      '${specs['Số ejector'] ?? '--'} Ejector',
    )
    ..writeln(
      '• Hệ thống Camera: ${specs['Số Camera'] ?? '--'} Camera Full-Color HD',
    )
    ..writeln(
      '• Độ chính xác phân loại: '
      '${specs['Độ chính xác phân loại'] ?? '≥ 99.9%'}',
    )
    ..writeln(
      '• Điện năng: ${specs['Công suất điện (kW)'] ?? '--'} kW '
      '(${specs['Điện áp'] ?? '220V'})',
    )
    ..writeln('• Khí nén yêu cầu: ${specs['Áp suất khí nén'] ?? '0.6-0.8 MPa'}')
    ..writeln(
      '• Kích thước máy (D×R×C): '
      '${specs['Kích thước (D x R x C mm)'] ?? '--'} mm',
    )
    ..writeln(
      '• Cấu hình phụ trợ gợi ý: Máy nén khí '
      '${specs['Máy nén khí đồng bộ'] ?? '--'} + Bình chứa '
      '${specs['Bình tích khí đồng bộ'] ?? '--'}',
    )
    ..writeln()
    ..writeln('👤 Liên hệ tư vấn: $contactName')
    ..writeln('📞 Điện thoại: $contactPhone');
  return buffer.toString().trimRight();
}

class SpecImageExportDialog extends StatefulWidget {
  final Map<String, String> specs;
  final String? imagePath;

  const SpecImageExportDialog({super.key, required this.specs, this.imagePath});

  @override
  State<SpecImageExportDialog> createState() => _SpecImageExportDialogState();
}

class _SpecImageExportDialogState extends State<SpecImageExportDialog> {
  static const _contactNameKey = 'color_sorter_contact_name';
  static const _contactPhoneKey = 'color_sorter_contact_phone';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSharing = false;
  bool _isLoadingContact = true;

  String get _contactName => _nameController.text.trim();
  String get _contactPhone => _phoneController.text.trim();

  @override
  void initState() {
    super.initState();
    _loadContact();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadContact() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _nameController.text = preferences.getString(_contactNameKey) ?? '';
      _phoneController.text = preferences.getString(_contactPhoneKey) ?? '';
    } catch (_) {
      // The fields remain editable if local storage is unavailable.
    } finally {
      if (mounted) setState(() => _isLoadingContact = false);
    }
  }

  Future<void> _saveContact() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await Future.wait([
        preferences.setString(_contactNameKey, _contactName),
        preferences.setString(_contactPhoneKey, _contactPhone),
      ]);
    } catch (_) {
      // Export still works when preferences cannot be written.
    }
  }

  void _contactChanged(String _) {
    final digitCount = RegExp(r'\d').allMatches(_contactPhone).length;
    if (_contactName.isNotEmpty && digitCount >= 8 && digitCount <= 15) {
      unawaited(_saveContact());
    }
  }

  bool _validateContact() {
    FocusScope.of(context).unfocus();
    return _formKey.currentState?.validate() ?? false;
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Vui lòng nhập tên người liên hệ';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    final digitCount = RegExp(r'\d').allMatches(phone).length;
    if (phone.isEmpty) return 'Vui lòng nhập số điện thoại';
    if (digitCount < 8 || digitCount > 15) {
      return 'Số điện thoại cần có từ 8 đến 15 chữ số';
    }
    return null;
  }

  Future<void> _copyText() async {
    if (!_validateContact()) return;
    await _saveContact();
    final text = buildColorSorterSpecShareText(
      specs: widget.specs,
      contactName: _contactName,
      contactPhone: _contactPhone,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép thông số để gửi khách hàng.'),
        backgroundColor: Color(0xFF168052),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (!_validateContact()) return;
    setState(() => _isSharing = true);
    try {
      await _saveContact();
      final bytes = await DtcPdfExportService.buildColorSorterCatalog(
        specs: widget.specs,
        contactName: _contactName,
        contactPhone: _contactPhone,
        machineImagePath: widget.imagePath,
      );
      if (!mounted) return;
      final model = widget.specs['Model'] ?? 'SC';
      final safeModel = model.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
      final fileName = 'catalog-may-tach-mau-$safeModel.pdf';
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
          ],
          text:
              'Catalog máy tách màu ${model.toUpperCase()}\n'
              'Liên hệ tư vấn: $_contactName - $_contactPhone',
          title: 'Catalog máy tách màu ${model.toUpperCase()}',
          sharePositionOrigin: origin,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chưa thể xuất PDF: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = (widget.specs['Model'] ?? 'SC').toUpperCase();
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F5F6),
        appBar: AppBar(
          title: const Text('Chia sẻ thông số'),
          centerTitle: true,
          leading: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'THÔNG TIN NHÂN VIÊN LIÊN HỆ',
                              style: TextStyle(
                                color: Color(0xFF607786),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_isLoadingContact)
                              const LinearProgressIndicator(minHeight: 2)
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final fields = [
                                    _buildNameField(),
                                    _buildPhoneField(),
                                  ];
                                  if (constraints.maxWidth < 560) {
                                    return Column(
                                      children: [
                                        fields[0],
                                        const SizedBox(height: 10),
                                        fields[1],
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: fields[0]),
                                      const SizedBox(width: 12),
                                      Expanded(child: fields[1]),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(height: 6, color: const Color(0xFF168052)),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 58,
                                child: Image.asset(
                                  'assets/images/DTCGroup-Slogan.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'CATALOG MÁY TÁCH MÀU $model',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF0A2740),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (widget.imagePath != null) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 150,
                                  child: Image.asset(
                                    widget.imagePath!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              const _CatalogContents(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final copyButton = _buildCopyButton();
                final pdfButton = _buildPdfButton();
                if (constraints.maxWidth < 440) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: double.infinity, child: copyButton),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: pdfButton),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copyButton),
                    const SizedBox(width: 12),
                    Expanded(child: pdfButton),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      key: const Key('contact_name_field'),
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      maxLength: 50,
      validator: _validateName,
      onChanged: _contactChanged,
      decoration: const InputDecoration(
        labelText: 'Tên người liên hệ',
        prefixIcon: Icon(Icons.person_outline_rounded),
        counterText: '',
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      key: const Key('contact_phone_field'),
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 20,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ .-]')),
      ],
      validator: _validatePhone,
      onChanged: _contactChanged,
      decoration: const InputDecoration(
        labelText: 'Số điện thoại',
        prefixIcon: Icon(Icons.phone_outlined),
        counterText: '',
      ),
    );
  }

  Widget _buildCopyButton() {
    return OutlinedButton.icon(
      key: const Key('copy_spec_text_button'),
      onPressed: _isSharing || _isLoadingContact ? null : _copyText,
      icon: const Icon(Icons.content_copy_rounded),
      label: const Text('Sao chép văn bản'),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    );
  }

  Widget _buildPdfButton() {
    return FilledButton.icon(
      key: const Key('share_spec_pdf_button'),
      onPressed: _isSharing || _isLoadingContact ? null : _sharePdf,
      icon: _isSharing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_isSharing ? 'Đang tạo PDF...' : 'Chia sẻ PDF'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
    );
  }
}

class _CatalogContents extends StatelessWidget {
  const _CatalogContents();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.table_chart_outlined, 'Bảng thông số kỹ thuật đầy đủ'),
      (Icons.memory_outlined, '6 đặc tính công nghệ và diễn giải'),
      (Icons.grid_view_outlined, 'Chi tiết ứng dụng thực tế'),
      (Icons.location_on_outlined, 'Liên hệ tư vấn và hệ thống địa chỉ'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nội dung chia sẽ',
            style: TextStyle(
              color: Color(0xFF168052),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 9),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(item.$1, size: 18, color: const Color(0xFF168052)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        color: Color(0xFF102F46),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
