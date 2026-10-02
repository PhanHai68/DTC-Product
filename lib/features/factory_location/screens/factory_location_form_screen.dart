import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../theme/dtc_palette.dart';
import '../models/factory_location.dart';
import '../providers/factory_location_provider.dart';
import '../services/location_service.dart';
import '../services/short_link_resolver.dart'
    if (dart.library.io) '../services/short_link_resolver_io.dart';
import '../utils/maps_link.dart';

const _poorAccuracyMeters = 50.0;

class FactoryLocationFormScreen extends StatefulWidget {
  const FactoryLocationFormScreen({
    super.key,
    this.location,
    this.locationService = const LocationService(),
  });

  final FactoryLocation? location;
  final LocationService locationService;

  @override
  State<FactoryLocationFormScreen> createState() =>
      _FactoryLocationFormScreenState();
}

class _FactoryLocationFormScreenState extends State<FactoryLocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _note;
  final _link = TextEditingController();

  double? _latitude;
  double? _longitude;
  double? _accuracy;
  bool _locating = false;
  bool _resolvingLink = false;
  bool _saving = false;
  LocationFailure? _locationFailure;
  String? _linkError;
  String? _coordinateError;
  String _appliedLink = '';

  bool get _hasCoordinates => _latitude != null && _longitude != null;
  bool get _busy => _locating || _resolvingLink || _saving;

  @override
  void initState() {
    super.initState();
    final item = widget.location;
    _name = TextEditingController(text: item?.name ?? '');
    _note = TextEditingController(text: item?.note ?? '');
    _latitude = item?.latitude;
    _longitude = item?.longitude;
    _accuracy = item?.accuracy;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    _link.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.location == null ? 'Thêm nhà máy' : 'Sửa thông tin nhà máy',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            key: const Key('factory_location_name'),
            controller: _name,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Tên nhà máy *'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Vui lòng nhập tên nhà máy'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('factory_location_note'),
            controller: _note,
            maxLength: 500,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Ghi chú',
              hintText: 'VD: cổng số 2, gửi xe bên trái',
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationCard(context),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('factory_location_save'),
            onPressed: _busy ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu nhà máy'),
          ),
        ],
      ),
    ),
  );

  Widget _buildLocationCard(BuildContext context) {
    final palette = DtcPalette.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vị trí *',
              style: TextStyle(
                color: palette.navy,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            if (_hasCoordinates) ...[
              _CoordinateSummary(
                latitude: _latitude!,
                longitude: _longitude!,
                accuracy: _accuracy,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.tonalIcon(
              key: const Key('factory_location_locate'),
              onPressed: _busy ? null : _locate,
              icon: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _hasCoordinates
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                    ),
              label: Text(
                _locating
                    ? 'Đang định vị...'
                    : _hasCoordinates
                    ? 'Định vị lại'
                    : 'Định vị',
              ),
            ),
            if (_locationFailure != null) ...[
              const SizedBox(height: 10),
              _LocationErrorBox(
                failure: _locationFailure!,
                onRetry: _busy ? null : _locate,
                onOpenSettings: () =>
                    widget.locationService.openSettingsFor(_locationFailure!),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'hoặc dán link Google Maps',
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('factory_location_link'),
              controller: _link,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _applyLink(),
              onChanged: (_) {
                if (_linkError != null) setState(() => _linkError = null);
              },
              decoration: InputDecoration(
                labelText: 'Link Google Maps',
                hintText: 'https://www.google.com/maps/...',
                errorText: _linkError,
                errorMaxLines: 4,
                suffixIcon: IconButton(
                  tooltip: 'Dán từ bộ nhớ tạm',
                  onPressed: _busy ? null : _pasteLink,
                  icon: const Icon(Icons.content_paste_rounded),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _applyLink,
                icon: _resolvingLink
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.link_rounded),
                label: const Text('Lấy tọa độ từ link'),
              ),
            ),
            if (_coordinateError != null) ...[
              const SizedBox(height: 6),
              Text(
                _coordinateError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationFailure = null;
      _coordinateError = null;
    });
    try {
      final position = await widget.locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
      });
    } on LocationFailure catch (failure) {
      if (!mounted) return;
      setState(() => _locationFailure = failure);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bộ nhớ tạm không có nội dung để dán.')),
      );
      return;
    }
    _link.text = text;
    await _applyLink();
  }

  /// Trả về false nếu link không hợp lệ.
  Future<bool> _applyLink() async {
    final input = _link.text.trim();
    if (input.isEmpty) {
      setState(() => _linkError = 'Vui lòng dán link Google Maps');
      return false;
    }
    setState(() {
      _linkError = null;
      _coordinateError = null;
      _resolvingLink = true;
    });
    try {
      var source = input;
      if (isShortMapsLink(input)) {
        source = await resolveShortMapsLink(input);
      }
      final coordinates = parseMapsCoordinates(source);
      if (!mounted) return false;
      if (coordinates == null) {
        setState(
          () => _linkError =
              'Không đọc được tọa độ từ link này. Hãy dùng link có chứa tọa độ '
              '(mở vị trí trong Google Maps rồi sao chép link) hoặc dùng nút Định vị.',
        );
        return false;
      }
      setState(() {
        _latitude = coordinates.latitude;
        _longitude = coordinates.longitude;
        _accuracy = null;
        _locationFailure = null;
        _appliedLink = input;
      });
      return true;
    } on ShortLinkException catch (error) {
      if (mounted) setState(() => _linkError = error.message);
      return false;
    } finally {
      if (mounted) setState(() => _resolvingLink = false);
    }
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    final pendingLink = _link.text.trim();
    if (pendingLink.isNotEmpty && pendingLink != _appliedLink) {
      if (!await _applyLink()) return;
    }
    if (!mounted) return;
    if (!_hasCoordinates) {
      setState(
        () => _coordinateError =
            'Vui lòng nhấn "Định vị" hoặc dán link Google Maps trước khi lưu.',
      );
      return;
    }
    if (!formValid) return;

    final provider = context.read<FactoryLocationProvider>();
    final name = _name.text.trim();
    if (provider.hasDuplicateName(name, excludeId: widget.location?.id)) {
      final proceed = await _confirmDuplicate(name);
      if (proceed != true || !mounted) return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final existing = widget.location;
    final location = FactoryLocation(
      id: existing?.id,
      name: name,
      latitude: _latitude!,
      longitude: _longitude!,
      accuracy: _accuracy,
      note: _note.text.trim(),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await provider.save(location);
      if (!mounted) return;
      context.pop();
    } catch (error) {
      debugPrint('FactoryLocationFormScreen._save: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lưu nhà máy. Vui lòng thử lại.'),
        ),
      );
    }
  }

  Future<bool?> _confirmDuplicate(String name) => showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
      title: const Text('Tên nhà máy bị trùng'),
      content: Text(
        'Đã có nhà máy tên "$name" trong danh sách. Bạn vẫn muốn lưu?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Sửa lại tên'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Vẫn lưu'),
        ),
      ],
    ),
  );
}

class _CoordinateSummary extends StatelessWidget {
  const _CoordinateSummary({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final palette = DtcPalette.of(context);
    final accuracy = this.accuracy;
    final poor = accuracy != null && accuracy > _poorAccuracyMeters;
    final accuracyColor = poor ? Colors.orange.shade800 : Colors.green.shade700;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.cyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, color: palette.cyan, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  style: TextStyle(
                    color: palette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (accuracy == null ? palette.muted : accuracyColor)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  accuracy == null ? 'Từ link' : '±${accuracy.round()} m',
                  key: const Key('factory_location_accuracy'),
                  style: TextStyle(
                    color: accuracy == null ? palette.muted : accuracyColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            buildMapsUrl(latitude, longitude),
            style: TextStyle(color: palette.cyan, fontSize: 12.5),
          ),
          if (poor) ...[
            const SizedBox(height: 8),
            Text(
              'Độ chính xác thấp. Hãy ra khu vực thoáng rồi nhấn "Định vị lại".',
              style: TextStyle(color: accuracyColor, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationErrorBox extends StatelessWidget {
  const _LocationErrorBox({
    required this.failure,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationFailure failure;
  final VoidCallback? onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settingsLabel = failure.type == LocationFailureType.serviceDisabled
        ? 'Bật vị trí'
        : 'Mở Cài đặt';
    return Container(
      key: const Key('factory_location_error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_off_outlined, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(failure.message)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (failure.canOpenSettings)
                FilledButton.tonal(
                  onPressed: onOpenSettings,
                  child: Text(settingsLabel),
                ),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ],
      ),
    );
  }
}
