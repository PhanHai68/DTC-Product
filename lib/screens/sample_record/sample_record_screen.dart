import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/sample_record.dart';
import '../../repositories/sample_record_repository.dart';
import '../../services/sample_record_pdf_service.dart';
import '../../widgets/stored_image.dart';
import '../../widgets/technology_menu.dart';

class SampleRecordScreen extends StatefulWidget {
  final SampleRecordRepository? repository;

  const SampleRecordScreen({super.key, this.repository});

  @override
  State<SampleRecordScreen> createState() => _SampleRecordScreenState();
}

class _SampleRecordScreenState extends State<SampleRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _factoryController = TextEditingController();
  final _materialController = TextEditingController();
  final _tagController = TextEditingController();
  final _operatorController = TextEditingController();
  final _preparedByController = TextEditingController();
  final _conclusionController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();
  late final SampleRecordRepository _repository;
  late final Map<SampleStreamType, _SampleStreamControllers> _streams;
  DateTime _createdAt = DateTime.now();
  Timer? _saveTimer;
  bool _loading = true;
  bool _saving = false;
  bool _savingToDevice = false;
  bool _sharingPdf = false;

  Iterable<TextEditingController> get _allControllers sync* {
    yield _factoryController;
    yield _materialController;
    yield _tagController;
    yield _operatorController;
    yield _preparedByController;
    yield _conclusionController;
    yield _noteController;
    for (final stream in _streams.values) {
      yield* stream.all;
    }
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalSampleRecordRepository();
    _streams = {
      for (final type in SampleStreamType.values)
        type: _SampleStreamControllers(type),
    };
    for (final stream in _streams.values) {
      stream.setListener(_onChanged);
    }
    for (final controller in _allControllers) {
      controller.addListener(_onChanged);
    }

    // Tự động đồng bộ thông số phút/giây của Nguyên liệu sang Thành phẩm và Phế phẩm
    final rawStream = _streams[SampleStreamType.rawMaterial]!;
    rawStream.minutes.addListener(() {
      final m = rawStream.minutes.text;
      _streams[SampleStreamType.accepted]!.minutes.text = m;
      _streams[SampleStreamType.rejected]!.minutes.text = m;
    });
    rawStream.seconds.addListener(() {
      final s = rawStream.seconds.text;
      _streams[SampleStreamType.accepted]!.seconds.text = s;
      _streams[SampleStreamType.rejected]!.seconds.text = s;
    });

    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final controller in _allControllers) {
      controller.removeListener(_onChanged);
    }
    _factoryController.dispose();
    _materialController.dispose();
    _tagController.dispose();
    _operatorController.dispose();
    _preparedByController.dispose();
    _conclusionController.dispose();
    _noteController.dispose();
    for (final stream in _streams.values) {
      stream.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final draft = await _repository.loadDraft();
      if (draft != null) {
        _factoryController.text = draft.factoryName;
        _materialController.text = draft.materialName;
        _tagController.text = draft.tagName;
        _operatorController.text = draft.machineOperator;
        _preparedByController.text = draft.preparedBy;
        _conclusionController.text = draft.conclusion;
        _noteController.text = draft.note;
        _createdAt = draft.createdAt;
        for (final data in draft.streams) {
          _streams[data.type]?.load(data);
        }
        // Đồng bộ lại phút/giây từ nguyên liệu sang thành phẩm và phế phẩm
        final raw = _streams[SampleStreamType.rawMaterial]!;
        _streams[SampleStreamType.accepted]!.minutes.text = raw.minutes.text;
        _streams[SampleStreamType.rejected]!.minutes.text = raw.minutes.text;
        _streams[SampleStreamType.accepted]!.seconds.text = raw.seconds.text;
        _streams[SampleStreamType.rejected]!.seconds.text = raw.seconds.text;
      }
    } catch (_) {
      _showMessage(
        'Không thể đọc bản nháp cục bộ. Bạn vẫn có thể lập mẫu mới.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onChanged() {
    if (_loading) return;
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveDraft());
    });
  }

  SampleRecordData _record() => SampleRecordData(
    factoryName: _factoryController.text.trim(),
    materialName: _materialController.text.trim(),
    tagName: _tagController.text.trim(),
    machineOperator: _operatorController.text.trim(),
    preparedBy: _preparedByController.text.trim(),
    createdAt: _createdAt,
    streams: SampleStreamType.values
        .map((type) => _streams[type]!.toData())
        .toList(),
    conclusion: _conclusionController.text.trim(),
    note: _noteController.text.trim(),
  );

  Future<void> _saveDraft() async {
    if (_saving || _loading) return;
    _saving = true;
    if (mounted) setState(() {});
    try {
      await _repository.saveDraft(_record());
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _capturePhoto(
    SampleStreamType type, {
    int? parameterIndex,
  }) async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 76,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final path = await _repository.persistPhoto(
        image.path,
        type,
        slot: parameterIndex == null ? 'overview' : 'param_$parameterIndex',
        bytes: await image.readAsBytes(),
      );
      if (!mounted) return;
      setState(() {
        if (parameterIndex == null) {
          _streams[type]!.photoPath = path;
        } else if (parameterIndex < _streams[type]!.parameters.length) {
          _streams[type]!.parameters[parameterIndex].photoPath = path;
        }
      });
      await _saveDraft();
    } catch (error) {
      _showMessage('Chưa thể mở camera hoặc lưu ảnh: $error');
    }
  }

  Future<(Uint8List, String)> _generatePdfBytesAndName({
    bool isDraft = false,
  }) async {
    final record = _record();
    await _repository.saveDraft(record);
    final photos = <SampleStreamType, Uint8List>{};
    final categoryPhotos = <SampleStreamType, List<Uint8List?>>{};
    for (final stream in record.streams) {
      if (stream.photoPath != null && stream.photoPath!.isNotEmpty) {
        final bytes = await _repository.readPhoto(stream.photoPath!);
        if (bytes != null) photos[stream.type] = bytes;
      }
      final streamCategoryPhotos = <Uint8List?>[];
      for (final item in stream.effectiveItems) {
        if (item.photoPath != null && item.photoPath!.isNotEmpty) {
          streamCategoryPhotos.add(
            await _repository.readPhoto(item.photoPath!),
          );
        } else {
          streamCategoryPhotos.add(null);
        }
      }
      categoryPhotos[stream.type] = streamCategoryPhotos;
    }
    final bytes = await SampleRecordPdfService.build(
      record: record,
      photos: photos,
      categoryPhotos: categoryPhotos,
      isDraft: isDraft,
    );
    final date = DateFormat('ddMMyyyy').format(record.createdAt);
    final fileName =
        '${_safeFilePart(record.tagName)} - '
        '${_safeFilePart(record.factoryName)} - $date.pdf';
    return (bytes, fileName);
  }

  /// 1. "Lưu Form về máy": tự động lưu vào thiết bị, không mở trình chia sẻ
  Future<void> _savePdfToDevice() async {
    final form = _formKey.currentState;
    final record = _record();
    final isDraft = form == null || !form.validate() || !record.hasAllPhotos;

    setState(() => _savingToDevice = true);
    try {
      final (bytes, fileName) = await _generatePdfBytesAndName(
        isDraft: isDraft,
      );
      await _repository.savePdf(bytes, fileName);
      if (mounted) {
        _showMessage(
          isDraft
              ? 'Đã lưu bản nháp PDF về máy: $fileName'
              : 'Đã lưu file PDF về máy: $fileName',
        );
      }
    } catch (error) {
      _showMessage('Chưa thể lưu PDF: $error');
    } finally {
      if (mounted) setState(() => _savingToDevice = false);
    }
  }

  /// 2. "Chia sẻ Form PDF": chỉ chia sẻ, không tự động lưu vào thư mục cố định
  Future<void> _sharePdfOnly() async {
    final form = _formKey.currentState;
    final record = _record();
    final isDraft = form == null || !form.validate() || !record.hasAllPhotos;

    setState(() => _sharingPdf = true);
    try {
      final (bytes, fileName) = await _generatePdfBytesAndName(
        isDraft: isDraft,
      );
      if (!mounted) return;
      final renderBox = context.findRenderObject() as RenderBox?;
      final origin = renderBox == null
          ? null
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
          ],
          title: 'Form lưu mẫu - ${record.tagName}',
          text:
              'Form lưu mẫu ${record.tagName} - '
              '${record.factoryName}',
          sharePositionOrigin: origin,
          fileNameOverrides: [fileName],
        ),
      );
    } catch (error) {
      _showMessage('Chưa thể chia sẻ PDF: $error');
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  String _safeFilePart(String value) => value
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _startNewRecord() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo biểu mẫu mới?'),
        content: const Text(
          'Dữ liệu trong bản nháp hiện tại sẽ được xóa. Các file PDF đã xuất vẫn được giữ lại trên thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tạo mới'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _saveTimer?.cancel();
    await _repository.clearDraft();
    for (final controller in _allControllers) {
      controller.clear();
    }
    for (final stream in _streams.values) {
      stream.resetLabelsAndPhotos();
    }
    if (!mounted) return;
    setState(() => _createdAt = DateTime.now());
    await _saveDraft();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DtcPalette.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Lập Form Lưu Mẫu'),
        actions: [
          IconButton(
            key: const Key('sample_record_new'),
            tooltip: 'Tạo biểu mẫu mới',
            onPressed: _startNewRecord,
            icon: const Icon(Icons.note_add_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _StatusChip(saving: _saving)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 118),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _OfflineBanner(),
                        const SizedBox(height: 12),
                        _FormSection(
                          title: 'Thông tin chung',
                          subtitle: 'GENERAL INFORMATION',
                          icon: Icons.assignment_ind_outlined,
                          child: _buildGeneralInformation(),
                        ),
                        const SizedBox(height: 12),
                        ...SampleStreamType.values.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SampleStreamSection(
                              controllers: _streams[type]!,
                              onCaptureOverview: () => _capturePhoto(type),
                              onCaptureParameter: (index) =>
                                  _capturePhoto(type, parameterIndex: index),
                              onAddParameter: () {
                                setState(() {
                                  _streams[type]!.addParameter();
                                });
                                _onChanged();
                              },
                              onRemoveParameter: (index) {
                                setState(() {
                                  _streams[type]!.removeParameter(index);
                                });
                                _onChanged();
                              },
                            ),
                          );
                        }),
                        _FormSection(
                          title: 'Kết luận',
                          subtitle: 'CONCLUSION',
                          icon: Icons.verified_outlined,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _conclusionController,
                                minLines: 3,
                                maxLines: 6,
                                validator: (value) =>
                                    (value ?? '').trim().isEmpty
                                    ? 'Kỹ sư cần nhập nội dung kết luận'
                                    : null,
                                decoration: const InputDecoration(
                                  labelText: 'Kết luận của kỹ sư / Engineer conclusion',
                                  hintText: 'Nhập nội dung kết luận tại đây',
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(Icons.edit_note_rounded),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _noteController,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Ghi chú / Notes',
                                  alignLabelWithHint: true,
                                  prefixIcon: Icon(Icons.notes_rounded),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Material(
          color: Colors.white,
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  child: OutlinedButton.icon(
                    key: const Key('sample_record_save_device'),
                    onPressed: (_savingToDevice || _sharingPdf)
                        ? null
                        : _savePdfToDevice,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: const Color(0xFF148147),
                      side: const BorderSide(
                        color: Color(0xFF148147),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _savingToDevice
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF148147),
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      _savingToDevice ? 'Đang lưu...' : 'Lưu bản PDF',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: FilledButton.icon(
                    key: const Key('sample_record_share_pdf'),
                    onPressed: (_savingToDevice || _sharingPdf)
                        ? null
                        : _sharePdfOnly,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF148147),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _sharingPdf
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      _sharingPdf ? 'Đang chia sẻ...' : 'Chia sẻ PDF',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInformation() {
    final fields = [
      _RequiredTextField(
        controller: _factoryController,
        label: 'Tên nhà máy / Factory',
      ),
      _RequiredTextField(
        controller: _materialController,
        label: 'Tên nguyên liệu / Material',
      ),
      _RequiredTextField(
        controller: _tagController,
        label: 'Tagname máy / Machine tagname',
      ),
      _RequiredTextField(
        controller: _operatorController,
        label: 'Người chạy máy / Operator',
      ),
      _RequiredTextField(
        controller: _preparedByController,
        label: 'Người lập mẫu / Prepared by',
      ),
      TextFormField(
        initialValue: DateFormat('dd/MM/yyyy HH:mm:ss').format(_createdAt),
        readOnly: true,
        decoration: const InputDecoration(
          labelText: 'Thời gian lập / Created at',
          prefixIcon: Icon(Icons.schedule_rounded),
          filled: true,
          fillColor: Color(0xFFF0F5F6),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 650;
        if (!twoColumns) {
          return Column(
            children: fields
                .map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: field,
                  ),
                )
                .toList(),
          );
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: (constraints.maxWidth - 12) / 2,
                  child: field,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ParameterControllerItem {
  final TextEditingController name;
  final TextEditingController weight;
  String? photoPath;

  _ParameterControllerItem({
    required String initialName,
    double initialWeight = 0,
    this.photoPath,
  }) : name = TextEditingController(text: initialName),
       weight = TextEditingController(
         text: initialWeight > 0
             ? (initialWeight == initialWeight.roundToDouble()
                   ? '${initialWeight.toInt()}'
                   : '$initialWeight')
             : '',
       );

  void addListener(VoidCallback listener) {
    name.addListener(listener);
    weight.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    name.removeListener(listener);
    weight.removeListener(listener);
  }

  void dispose() {
    name.dispose();
    weight.dispose();
  }
}

class _SampleStreamControllers {
  final SampleStreamType type;
  final weight = TextEditingController();
  final minutes = TextEditingController();
  final seconds = TextEditingController();
  final sampleWeight = TextEditingController();
  final List<_ParameterControllerItem> parameters = [];
  String? photoPath;
  VoidCallback? _onChangedListener;

  _SampleStreamControllers(this.type) {
    final defaults = defaultSampleParameters(type);
    for (final p in defaults) {
      parameters.add(_ParameterControllerItem(initialName: p.name));
    }
  }

  void setListener(VoidCallback listener) {
    _onChangedListener = listener;
    for (final p in parameters) {
      p.addListener(listener);
    }
  }

  void addParameter({String name = ''}) {
    final item = _ParameterControllerItem(initialName: name);
    if (_onChangedListener != null) {
      item.addListener(_onChangedListener!);
    }
    parameters.add(item);
  }

  void removeParameter(int index) {
    if (index >= 0 && index < parameters.length) {
      final item = parameters.removeAt(index);
      if (_onChangedListener != null) {
        item.removeListener(_onChangedListener!);
      }
      item.dispose();
    }
  }

  Iterable<TextEditingController> get all sync* {
    yield weight;
    yield minutes;
    yield seconds;
    yield sampleWeight;
    for (final p in parameters) {
      yield p.name;
      yield p.weight;
    }
  }

  SampleStreamData toData() {
    final items = parameters
        .map(
          (p) => SampleParameterItem(
            name: p.name.text.trim(),
            weightGram: parseSampleNumber(p.weight.text),
            photoPath: p.photoPath,
          ),
        )
        .toList();

    return SampleStreamData(
      type: type,
      measuredWeightKg: parseSampleNumber(weight.text),
      minutes: int.tryParse(minutes.text.trim()) ?? 0,
      seconds: int.tryParse(seconds.text.trim()) ?? 0,
      sampleWeightGram: parseSampleNumber(sampleWeight.text),
      photoPath: photoPath,
      items: items,
    );
  }

  void load(SampleStreamData data) {
    weight.text = _editableNumber(data.measuredWeightKg);
    minutes.text = data.minutes == 0 ? '' : '${data.minutes}';
    seconds.text = data.seconds == 0 ? '' : '${data.seconds}';
    sampleWeight.text = _editableNumber(data.sampleWeightGram);
    photoPath = data.photoPath;

    for (final p in parameters) {
      if (_onChangedListener != null) p.removeListener(_onChangedListener!);
      p.dispose();
    }
    parameters.clear();

    final effective = data.effectiveItems;
    for (final item in effective) {
      final pItem = _ParameterControllerItem(
        initialName: item.name,
        initialWeight: item.weightGram,
        photoPath: item.photoPath,
      );
      if (_onChangedListener != null) {
        pItem.addListener(_onChangedListener!);
      }
      parameters.add(pItem);
    }
  }

  void resetLabelsAndPhotos() {
    for (final p in parameters) {
      if (_onChangedListener != null) p.removeListener(_onChangedListener!);
      p.dispose();
    }
    parameters.clear();
    final defaults = defaultSampleParameters(type);
    for (final p in defaults) {
      final item = _ParameterControllerItem(initialName: p.name);
      if (_onChangedListener != null) item.addListener(_onChangedListener!);
      parameters.add(item);
    }
    photoPath = null;
  }

  String _editableNumber(double value) => value == 0
      ? ''
      : value == value.roundToDouble()
      ? '${value.toInt()}'
      : '$value';

  void dispose() {
    for (final p in parameters) {
      p.dispose();
    }
    weight.dispose();
    minutes.dispose();
    seconds.dispose();
    sampleWeight.dispose();
  }
}

class _SampleStreamSection extends StatelessWidget {
  final _SampleStreamControllers controllers;
  final VoidCallback onCaptureOverview;
  final ValueChanged<int> onCaptureParameter;
  final VoidCallback onAddParameter;
  final ValueChanged<int> onRemoveParameter;

  const _SampleStreamSection({
    required this.controllers,
    required this.onCaptureOverview,
    required this.onCaptureParameter,
    required this.onAddParameter,
    required this.onRemoveParameter,
  });

  String get sectionTitle => switch (controllers.type) {
    SampleStreamType.rawMaterial => '1. NGUYÊN LIỆU',
    SampleStreamType.accepted => '2. THÀNH PHẨM',
    SampleStreamType.rejected => '3. PHẾ PHẨM',
  };

  Color get primaryColor => switch (controllers.type) {
    SampleStreamType.rawMaterial => const Color(0xFF148147), // Green
    SampleStreamType.accepted => const Color(0xFF0288D1), // Blue
    SampleStreamType.rejected => const Color(0xFFD84315), // Deep Orange
  };

  Color get backgroundColor => switch (controllers.type) {
    SampleStreamType.rawMaterial => const Color(0xFFE8F6EF),
    SampleStreamType.accepted => const Color(0xFFE1F5FE),
    SampleStreamType.rejected => const Color(0xFFFBE9E7),
  };

  @override
  Widget build(BuildContext context) {
    final data = controllers.toData();
    final totalParamWeight = controllers.parameters
        .map((p) => parseSampleNumber(p.weight.text))
        .fold<double>(0, (a, b) => a + b);
    final defectError =
        data.sampleWeightGram > 0 &&
        totalParamWeight > data.sampleWeightGram * 1.001;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: controllers.type == SampleStreamType.rawMaterial,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.grain_rounded, color: primaryColor),
        ),
        title: Text(
          sectionTitle,
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${controllers.type.englishTitle} · ${data.capacityTonPerHour.toStringAsFixed(1)} t/h',
          style: const TextStyle(color: DtcPalette.muted, fontSize: 12.5),
        ),
        children: [
          const _MiniHeading('Tính năng suất / Productivity'),
          const SizedBox(height: 10),
          if (controllers.type == SampleStreamType.rawMaterial) ...[
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: controllers.weight,
                    label: 'Khối lượng (kg)',
                    hintText: 'kg',
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    controller: controllers.minutes,
                    label: 'Phút',
                    integer: true,
                    allowZero: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumberField(
                    controller: controllers.seconds,
                    label: 'Giây',
                    integer: true,
                    validator: (value) {
                      final seconds = int.tryParse((value ?? '').trim());
                      if (seconds == null || seconds < 0 || seconds > 59) {
                        return '0–59';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: controllers.weight,
                    label: 'Khối lượng (kg)',
                    hintText: 'kg',
                    suffixText: 'kg',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6F7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: DtcPalette.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: Color(0xFF148147),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Thời gian: ${data.minutes}p ${data.seconds}g\n(Đồng bộ theo nguyên liệu)',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: DtcPalette.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _ResultStrip(
            items: [
              (
                'Thời gian đo',
                '${data.minutes}p ${data.seconds}g (${data.totalSeconds}g)',
              ),
              (
                'Năng suất',
                '${data.capacityTonPerHour.toStringAsFixed(1)} t/h',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _MiniHeading(switch (controllers.type) {
            SampleStreamType.rawMaterial =>
              'Hình ảnh mẫu nguyên liệu / Raw material photo',
            SampleStreamType.accepted =>
              'Hình ảnh mẫu thành phẩm / Accepted photo',
            SampleStreamType.rejected =>
              'Hình ảnh mẫu phế phẩm / Rejected photo',
          }),
          const SizedBox(height: 10),
          _PhotoCapture(
            path: controllers.photoPath,
            onCapture: onCaptureOverview,
          ),
          const SizedBox(height: 18),
          const _MiniHeading('Phân tích mẫu có hình ảnh / Sample Analysis'),
          const SizedBox(height: 4),
          const Text(
            'Nhập tổng mẫu, tên các thông số và chụp ảnh trực tiếp cho từng loại hạt.',
            style: TextStyle(color: DtcPalette.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _NumberField(
            controller: controllers.sampleWeight,
            label: 'Tổng khối lượng mẫu lấy kiểm tra (g)',
          ),
          const SizedBox(height: 12),
          ...List.generate(controllers.parameters.length, (index) {
            final param = controllers.parameters[index];
            return _ParameterCardRow(
              parameter: param,
              sampleWeightGram: data.sampleWeightGram,
              onCapturePhoto: () => onCaptureParameter(index),
              onRemove: controllers.parameters.length > 1
                  ? () => onRemoveParameter(index)
                  : null,
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onAddParameter,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Thêm thông số / loại hạt'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF148147),
                side: const BorderSide(color: Color(0xFF148147)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (defectError)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tổng khối lượng các thông số (${totalParamWeight.toStringAsFixed(1)}g) không được lớn hơn tổng mẫu (${data.sampleWeightGram.toStringAsFixed(1)}g).',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(height: 12),
          _ResultStrip(
            items: [
              ('Hạt tốt / Đạt', '${data.goodPercentage.toStringAsFixed(1)}%'),
              ('Hạt lỗi / Phế', '${data.defectPercentage.toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParameterCardRow extends StatelessWidget {
  final _ParameterControllerItem parameter;
  final double sampleWeightGram;
  final VoidCallback onCapturePhoto;
  final VoidCallback? onRemove;

  const _ParameterCardRow({
    required this.parameter,
    required this.sampleWeightGram,
    required this.onCapturePhoto,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final weight = parseSampleNumber(parameter.weight.text);
    final percentage = sampleWeightGram <= 0
        ? 0.0
        : (weight / sampleWeightGram * 100);
    final hasPhoto = storedImageCanDisplay(parameter.photoPath);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DtcPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: const Color(0xFFEAF7F1),
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCapturePhoto,
              child: SizedBox(
                width: 58,
                height: 58,
                child: hasPhoto
                    ? StoredImage(path: parameter.photoPath!)
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 22,
                            color: Color(0xFF148147),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ảnh',
                            style: TextStyle(
                              color: Color(0xFF148147),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: parameter.name,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Nhập tên thông số' : null,
                  decoration: const InputDecoration(
                    labelText: 'Nhập tên mẫu',
                    hintText: 'VD: Hạt tốt, Hạt xấu...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _NumberField(
                        controller: parameter.weight,
                        label: 'Khối lượng (g)',
                        allowZero: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Color(0xFF148147),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Xóa thông số này',
              onPressed: onRemove,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequiredTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _RequiredTextField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: (value) =>
          (value ?? '').trim().isEmpty ? 'Không được để trống' : null,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final String? suffixText;
  final bool integer;
  final bool allowZero;
  final String? Function(String?)? validator;

  const _NumberField({
    required this.controller,
    required this.label,
    this.hintText,
    this.suffixText,
    this.integer = false,
    this.allowZero = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      validator:
          validator ??
          (value) {
            final number = parseSampleNumber(value ?? '');
            if ((value ?? '').trim().isEmpty) {
              return allowZero ? null : 'Bắt buộc';
            }
            if (number < 0 || (!allowZero && number <= 0)) {
              return allowZero ? 'Từ 0 trở lên' : 'Phải lớn hơn 0';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        suffixText: suffixText,
        isDense: true,
      ),
    );
  }
}

class _PhotoCapture extends StatelessWidget {
  final String? path;
  final VoidCallback onCapture;

  const _PhotoCapture({required this.path, required this.onCapture});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = storedImageCanDisplay(path);
    return Container(
      height: hasPhoto ? 190 : 112,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F7),
        border: Border.all(color: DtcPalette.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                StoredImage(path: path!),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: FilledButton.tonalIcon(
                    onPressed: onCapture,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Chụp lại'),
                  ),
                ),
              ],
            )
          : InkWell(
              onTap: onCapture,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 34,
                    color: Color(0xFF148147),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Mở camera sau để chụp ảnh tổng quan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Bắt buộc trước khi xuất PDF',
                    style: TextStyle(color: DtcPalette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF148147)),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: DtcPalette.navy,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: DtcPalette.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResultStrip extends StatelessWidget {
  final List<(String, String)> items;

  const _ResultStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: items
            .map(
              (item) => Expanded(
                child: Column(
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: DtcPalette.muted,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$2,
                      style: const TextStyle(
                        color: Color(0xFF148147),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _MiniHeading extends StatelessWidget {
  final String text;

  const _MiniHeading(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: DtcPalette.navy,
      fontSize: 14,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9E9D8)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: Color(0xFF148147)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Chạy hoàn toàn offline · Dữ liệu được tự động lưu trên thiết bị',
              style: TextStyle(
                color: DtcPalette.navy,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool saving;

  const _StatusChip({required this.saving});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            saving ? Icons.sync_rounded : Icons.check_circle_outline,
            size: 15,
            color: const Color(0xFF148147),
          ),
          const SizedBox(width: 4),
          Text(
            saving ? 'Đang lưu' : 'Đã lưu',
            style: const TextStyle(
              color: Color(0xFF148147),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
