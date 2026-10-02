import '../../../data/acomp_spec_data.dart';
import '../../../data/agro_specs_data.dart';
import '../../../data/mineral_specs_data.dart';
import '../../../data/paddy_specs_data.dart';
import '../../../data/specs_data.dart';
import '../../../data/tea_aux_equip_data.dart';
import '../../../data/tea_specs_data.dart';
import '../../../repositories/packing_machine_repository.dart';
import '../../grinding_machine/providers/grinding_machine_provider.dart';
import '../../grinding_machine/repositories/grinding_machine_repository.dart';
import '../models/site_layout_models.dart';

class MachineLayoutCatalogRepository {
  MachineLayoutCatalogRepository({
    GrindingMachineRepository? grindingRepository,
    PackingMachineRepository? packingRepository,
  }) : _grindingRepository = grindingRepository ?? GrindingMachineRepository(),
       _packingRepository = packingRepository ?? PackingMachineRepository();

  final GrindingMachineRepository _grindingRepository;
  final PackingMachineRepository _packingRepository;

  Future<List<CatalogMachineLayoutData>> getAll() async {
    final result = <CatalogMachineLayoutData>[
      ..._readColorSorters(),
      ..._readCompressors(),
      ..._readAuxiliaryEquipment(),
    ];
    try {
      // Dùng đúng luồng seed/version của module Máy nghiền thay vì tự đọc
      // asset hoặc sao chép catalog sang Site Layout.
      final grindingProvider = GrindingMachineProvider(
        repository: _grindingRepository,
      );
      await grindingProvider.loadHome();
      if (grindingProvider.error != null) {
        throw StateError(grindingProvider.error!);
      }
      final machines = List.of(grindingProvider.machines);
      final seriesByCode = {
        for (final series in grindingProvider.series) series.seriesCode: series,
      };
      grindingProvider.dispose();
      result.addAll(
        machines.map((machine) {
          final series = seriesByCode[machine.seriesCode];
          final vietnameseName = series?.nameVi.trim() ?? '';
          return _validated(
            sourceType: 'grinding',
            sourceId: machine.machineId,
            category: 'Máy nghiền',
            model: machine.model,
            displayName: vietnameseName.isEmpty
                ? '${machine.model} · ${machine.seriesCode}'
                : '${machine.model} · $vietnameseName',
            length: machine.lengthMm,
            width: machine.widthMm,
            height: machine.heightMm,
          );
        }),
      );
    } catch (_) {
      // Catalog riêng có thể chưa khởi tạo; các nguồn còn lại vẫn sử dụng được.
    }
    try {
      final machines = await _packingRepository.getAllMachines();
      result.addAll(
        machines.map(
          (machine) => _validated(
            sourceType: 'packing',
            sourceId: machine.id.toString(),
            category: 'Máy đóng gói',
            model: machine.model,
            displayName: machine.machineLine?.trim().isNotEmpty == true
                ? '${machine.model} · ${machine.machineLine}'
                : machine.model,
            length: machine.lengthMm,
            width: machine.widthMm,
            height: machine.heightMm,
            imagePath: machine.imageMainPath,
          ),
        ),
      );
    } catch (_) {
      // Không làm hỏng màn hình bố trí nếu catalog đóng gói chưa sẵn sàng.
    }
    result.sort((a, b) {
      final byCategory = a.category.compareTo(b.category);
      return byCategory != 0 ? byCategory : a.model.compareTo(b.model);
    });
    return result;
  }

  List<CatalogMachineLayoutData> _readColorSorters() {
    final result = <CatalogMachineLayoutData>[];
    for (final data in colorSorterSpecs) {
      result.add(
        _fromMap(
          data,
          sourceType: 'color_sorter',
          category: 'Máy tách màu',
          dimensionKeys: const [
            'Kích thước (D x R x C mm)',
            'Kích thước (DxRxC) (mm)',
          ],
        ),
      );
    }
    for (final data in paddyColorSorterSpecs) {
      result.add(
        _fromMap(
          data,
          sourceType: 'paddy_color_sorter',
          category: 'Máy tách màu lúa',
          dimensionKeys: const ['Kích thước (D x R x C mm)'],
        ),
      );
    }
    for (final data in [
      ...teaColorSorterSpecs,
      ...mineralColorSorterSpecs,
      ...agroColorSorterSpecs,
    ]) {
      final model = data['model'] ?? data['Model'] ?? 'Không rõ model';
      result.add(
        _validated(
          sourceType: 'color_sorter',
          sourceId: data['id'] ?? 'color_$model',
          category: data['category'] ?? 'Máy tách màu',
          model: model,
          displayName: data['product_name'] ?? model,
          length: double.tryParse(data['dim_1_mm'] ?? ''),
          width: double.tryParse(data['dim_2_mm'] ?? ''),
          height: double.tryParse(data['dim_3_mm'] ?? ''),
          dimensionsText: data['dimensions_display_mm'],
        ),
      );
    }
    return result;
  }

  CatalogMachineLayoutData _fromMap(
    Map<String, String> data, {
    required String sourceType,
    required String category,
    required List<String> dimensionKeys,
  }) {
    final model = data['Model'] ?? data['model'] ?? 'Không rõ model';
    String? dimensions;
    for (final key in dimensionKeys) {
      if ((data[key] ?? '').trim().isNotEmpty) {
        dimensions = data[key];
        break;
      }
    }
    final parsed = _parseDimensions(dimensions);
    return _validated(
      sourceType: sourceType,
      sourceId: '${sourceType}_$model',
      category: category,
      model: model,
      displayName: model,
      length: parsed.$1,
      width: parsed.$2,
      height: parsed.$3,
      dimensionsText: dimensions,
    );
  }

  List<CatalogMachineLayoutData> _readCompressors() =>
      acompSpecData.map((machine) {
        final parsed = _parseDimensions(machine.dimensions);
        return _validated(
          sourceType: 'compressor',
          sourceId: 'compressor_${machine.modelCode}',
          category: 'Máy nén khí',
          model: machine.modelCode,
          displayName: '${machine.modelCode} · ${machine.series}',
          length: parsed.$1,
          width: parsed.$2,
          height: parsed.$3,
          dimensionsText: machine.dimensions,
        );
      }).toList();

  List<CatalogMachineLayoutData> _readAuxiliaryEquipment() =>
      teaAuxEquipData.map((data) {
        final name = (data['name'] ?? '').toString();
        final model = (data['model'] ?? name).toString();
        final dimensions = (data['dimensions'] ?? '').toString();
        final parsed = _parseDimensions(dimensions);
        final normalizedName = name.toLowerCase();
        final category = normalizedName.contains('sấy')
            ? 'Máy sấy'
            : 'Thiết bị phụ trợ';
        return _validated(
          sourceType: 'auxiliary',
          sourceId: 'auxiliary_$model',
          category: category,
          model: model,
          displayName: name.isEmpty ? model : '$model · $name',
          length: parsed.$1,
          width: parsed.$2,
          height: parsed.$3,
          dimensionsText: dimensions,
        );
      }).toList();

  (double?, double?, double?) _parseDimensions(String? source) {
    if (source == null || source.trim().isEmpty) return (null, null, null);
    final values = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(source)
        .map((match) {
          return double.tryParse(match.group(0)!.replaceAll(',', '.'));
        })
        .whereType<double>()
        .toList();
    if (values.length < 3) return (null, null, null);
    return (values[0], values[1], values[2]);
  }

  CatalogMachineLayoutData _validated({
    required String sourceType,
    required String sourceId,
    required String category,
    required String model,
    required String displayName,
    required double? length,
    required double? width,
    required double? height,
    String? imagePath,
    String? dimensionsText,
  }) {
    String? reason;
    if (length == null || width == null || height == null) {
      reason = dimensionsText?.trim().isNotEmpty == true
          ? 'Không đọc được đủ D × R × C từ dữ liệu nguồn.'
          : 'Catalog chưa có đủ kích thước D × R × C.';
    } else if (length <= 0 || width <= 0 || height <= 0) {
      reason = 'Kích thước trong catalog không hợp lệ.';
    } else if (length > 10000 || width > 10000 || height > 10000) {
      reason = 'Kích thước vượt ngưỡng kiểm tra; cần xác nhận lại catalog.';
    }
    return CatalogMachineLayoutData(
      sourceType: sourceType,
      sourceId: sourceId,
      category: category,
      model: model,
      displayName: displayName,
      lengthMm: length,
      widthMm: width,
      heightMm: height,
      imagePath: imagePath,
      invalidReason: reason,
    );
  }
}
