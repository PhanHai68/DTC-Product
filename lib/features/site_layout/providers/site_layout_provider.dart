import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/site_layout_models.dart';
import '../repositories/machine_layout_catalog_repository.dart';
import '../repositories/site_layout_repository.dart';
import '../services/layout_geometry_service.dart';
import '../services/site_layout_file_storage.dart';

class SiteLayoutProvider extends ChangeNotifier {
  SiteLayoutProvider({
    SiteLayoutRepository? repository,
    MachineLayoutCatalogRepository? catalogRepository,
  }) : _repository = repository ?? SiteLayoutRepository(),
       _catalogRepository =
           catalogRepository ?? MachineLayoutCatalogRepository();

  final SiteLayoutRepository _repository;
  final MachineLayoutCatalogRepository _catalogRepository;

  List<SiteLayoutProject> _projects = const [];
  List<SiteLayoutVariant> _layouts = const [];
  List<CatalogMachineLayoutData> _catalog = const [];
  SiteLayoutBundle? _bundle;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  DateTime? _lastSavedAt;
  EditorTool _tool = EditorTool.select;
  double _gridMm = 250;
  bool _snapToGrid = true;
  bool _showClearance = true;
  String? _selectedId;
  final List<SiteLayoutBundle> _undo = [];
  final List<SiteLayoutBundle> _redo = [];
  Timer? _saveTimer;
  int _revision = 0;
  int _savedRevision = 0;
  Future<void>? _savingFuture;
  SiteLayoutBundle? _transformStartBundle;
  String? _transformId;
  bool _transformChanged = false;
  math.Point<double>? _activeSnapPoint;

  List<SiteLayoutProject> get projects => _projects;
  List<SiteLayoutVariant> get layouts => _layouts;
  List<CatalogMachineLayoutData> get catalog => _catalog;
  SiteLayoutBundle? get bundle => _bundle;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  DateTime? get lastSavedAt => _lastSavedAt;
  EditorTool get tool => _tool;
  double get gridMm => _gridMm;
  bool get snapToGrid => _snapToGrid;
  bool get showClearance => _showClearance;
  String? get selectedId => _selectedId;
  math.Point<double>? get activeSnapPoint => _activeSnapPoint;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isDirty => _revision != _savedRevision;
  bool get selectedIsLocked =>
      selectedObject?.isLocked == true || selectedMachine?.isLocked == true;
  List<LayoutWarning> get warnings =>
      _bundle == null ? const [] : LayoutGeometryService.validate(_bundle!);

  MachinePlacement? get selectedMachine {
    final id = _selectedId;
    if (id == null || _bundle == null) return null;
    for (final machine in _bundle!.machines) {
      if (machine.id == id) return machine;
    }
    return null;
  }

  SiteLayoutObject? get selectedObject {
    final id = _selectedId;
    if (id == null || _bundle == null) return null;
    for (final object in _bundle!.objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  LayoutMeasurement? get selectedMeasurement {
    final id = _selectedId;
    if (id == null || _bundle == null) return null;
    for (final measurement in _bundle!.measurements) {
      if (measurement.id == id) return measurement;
    }
    return null;
  }

  Future<void> initialize() async {
    _setLoading(true);
    try {
      final values = await Future.wait([
        _repository.getProjects(),
        _catalogRepository.getAll(),
      ]);
      _projects = values[0] as List<SiteLayoutProject>;
      _catalog = values[1] as List<CatalogMachineLayoutData>;
      _error = null;
    } catch (error) {
      _error = 'Không thể tải dữ liệu bố trí mặt bằng: $error';
    } finally {
      _setLoading(false);
    }
  }

  Future<SiteLayoutProject?> createProject({
    required String name,
    required String customer,
    required String location,
    required String surveyor,
    required DateTime surveyDate,
    required double siteWidthMm,
    required double siteLengthMm,
    SiteDimensionUnit dimensionUnit = SiteDimensionUnit.meter,
    double? ceilingHeightMm,
    double? lowestBeamHeightMm,
    String notes = '',
  }) async {
    try {
      final project = await _repository.createProject(
        name: name,
        customer: customer,
        location: location,
        surveyor: surveyor,
        surveyDate: surveyDate,
        siteWidthMm: siteWidthMm,
        siteLengthMm: siteLengthMm,
        dimensionUnit: dimensionUnit,
        ceilingHeightMm: ceilingHeightMm,
        lowestBeamHeightMm: lowestBeamHeightMm,
        notes: notes,
      );
      _projects = await _repository.getProjects();
      _error = null;
      notifyListeners();
      return project;
    } catch (error) {
      _error = 'Không thể tạo dự án: $error';
      notifyListeners();
      return null;
    }
  }

  Future<bool> loadProject(String projectId, {String? layoutId}) async {
    await saveNow();
    _setLoading(true);
    try {
      _layouts = await _repository.getLayouts(projectId);
      if (_layouts.isEmpty) {
        await _repository.createLayout(projectId);
        _layouts = await _repository.getLayouts(projectId);
      }
      final layout = layoutId == null
          ? _layouts.firstWhere(
              (item) => item.isPreferred,
              orElse: () => _layouts.first,
            )
          : _layouts.firstWhere(
              (item) => item.id == layoutId,
              orElse: () => _layouts.first,
            );
      _bundle = await _repository.getBundle(projectId, layout.id);
      _undo.clear();
      _redo.clear();
      _selectedId = null;
      _activeSnapPoint = null;
      _revision = 0;
      _savedRevision = 0;
      _error = _bundle == null ? 'Không tìm thấy phương án.' : null;
      return _bundle != null;
    } catch (error) {
      _error = 'Không thể mở dự án: $error';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> switchLayout(String layoutId) async {
    final projectId = _bundle?.project.id;
    if (projectId == null || _bundle?.layout.id == layoutId) return;
    await loadProject(projectId, layoutId: layoutId);
  }

  Future<void> createLayout({
    String? name,
    bool duplicateCurrent = false,
  }) async {
    final current = _bundle;
    if (current == null) return;
    await saveNow();
    final created = duplicateCurrent
        ? await _repository.duplicateLayout(current.layout, name: name)
        : await _repository.createLayout(current.project.id, name: name);
    await loadProject(current.project.id, layoutId: created.id);
  }

  Future<void> setPreferredLayout() async {
    final current = _bundle;
    if (current == null) return;
    await saveNow();
    await _repository.setPreferredLayout(current.project.id, current.layout.id);
    _layouts = await _repository.getLayouts(current.project.id);
    _bundle = current.copyWith(
      layout: current.layout.copyWith(isPreferred: true),
    );
    notifyListeners();
  }

  Future<void> deleteCurrentLayout() async {
    final current = _bundle;
    if (current == null) return;
    await _repository.deleteLayout(current.layout);
    await loadProject(current.project.id);
  }

  Future<void> deleteProject(String projectId) async {
    if (_bundle?.project.id == projectId) {
      _saveTimer?.cancel();
      _bundle = null;
    }
    await _repository.deleteProject(projectId);
    _projects = await _repository.getProjects();
    notifyListeners();
  }

  void setTool(EditorTool value) {
    _tool = value;
    notifyListeners();
  }

  void setGrid(double value) {
    _gridMm = value;
    notifyListeners();
  }

  void toggleSnap() {
    _snapToGrid = !_snapToGrid;
    _activeSnapPoint = null;
    notifyListeners();
  }

  void toggleClearance() {
    _showClearance = !_showClearance;
    notifyListeners();
  }

  void select(String? id) {
    if (_transformStartBundle != null) endTransform();
    _selectedId = id;
    _activeSnapPoint = null;
    notifyListeners();
  }

  double snapped(double value) =>
      _snapToGrid ? LayoutGeometryService.snap(value, _gridMm) : value;

  LayoutMeasurement _movedMeasurement(
    LayoutMeasurement measurement,
    double deltaXMm,
    double deltaYMm,
  ) {
    final x1Mm = snapped(measurement.x1Mm + deltaXMm);
    final y1Mm = snapped(measurement.y1Mm + deltaYMm);
    return measurement.copyWith(
      x1Mm: x1Mm,
      y1Mm: y1Mm,
      x2Mm: measurement.x2Mm + x1Mm - measurement.x1Mm,
      y2Mm: measurement.y2Mm + y1Mm - measurement.y1Mm,
    );
  }

  void addObject(SiteObjectType type, double xMm, double yMm) {
    final current = _bundle;
    if (current == null) return;
    _beginChange();
    final size = switch (type) {
      SiteObjectType.wall => (2000.0, 150.0),
      SiteObjectType.column => (400.0, 400.0),
      SiteObjectType.door => (1000.0, 150.0),
      SiteObjectType.bucketElevator => (300.0, 300.0),
      SiteObjectType.walkway => (2000.0, 350.0),
      SiteObjectType.line => (2000.0, 50.0),
      SiteObjectType.restrictedArea => (2000.0, 2000.0),
      SiteObjectType.existingMachine => (1500.0, 1000.0),
      SiteObjectType.obstacle => (1000.0, 1000.0),
    };
    final rawAnchor = math.Point(xMm, yMm);
    final pointAnchor = _snapToGrid
        ? LayoutGeometryService.nearestSnapPoint(
            rawAnchor,
            LayoutGeometryService.bundleSnapPoints(current),
          )
        : null;
    final anchorX = pointAnchor?.x ?? snapped(xMm);
    final anchorY = pointAnchor?.y ?? snapped(yMm);
    final isLinear = type.isLinear;
    final object = SiteLayoutObject(
      id: newSiteLayoutId('object'),
      layoutId: current.layout.id,
      type: type,
      xMm: anchorX,
      yMm: isLinear ? anchorY - size.$2 / 2 : anchorY,
      widthMm: size.$1,
      lengthMm: size.$2,
      label: type.label,
      zIndex: _nextZIndex(current),
    );
    _bundle = current.copyWith(objects: [...current.objects, object]);
    _selectedId = object.id;
    _tool = EditorTool.select;
    _commitChange();
  }

  void addLine(double x1Mm, double y1Mm, double x2Mm, double y2Mm) {
    final current = _bundle;
    if (current == null) return;
    final start = math.Point(snapped(x1Mm), snapped(y1Mm));
    final end = math.Point(snapped(x2Mm), snapped(y2Mm));
    if (start.distanceTo(end) < 1) return;
    _beginChange();
    final seed = SiteLayoutObject(
      id: newSiteLayoutId('line'),
      layoutId: current.layout.id,
      type: SiteObjectType.line,
      xMm: start.x,
      yMm: start.y - 25,
      widthMm: start.distanceTo(end),
      lengthMm: 50,
      label: SiteObjectType.line.label,
      zIndex: _nextZIndex(current),
    );
    final line = LayoutGeometryService.objectFromSegment(
      seed,
      start: start,
      end: end,
      thicknessMm: 50,
    );
    _bundle = current.copyWith(objects: [...current.objects, line]);
    _selectedId = line.id;
    _tool = EditorTool.select;
    _commitChange();
  }

  void addMachine(
    CatalogMachineLayoutData catalogMachine, {
    double clearanceFrontMm = 0,
    double clearanceRearMm = 0,
    double clearanceLeftMm = 0,
    double clearanceRightMm = 0,
    bool clearanceVerified = false,
  }) {
    final current = _bundle;
    if (current == null || !catalogMachine.canPlace) return;
    _beginChange();
    final machine = MachinePlacement(
      id: newSiteLayoutId('machine'),
      layoutId: current.layout.id,
      sourceType: catalogMachine.sourceType,
      sourceId: catalogMachine.sourceId,
      category: catalogMachine.category,
      model: catalogMachine.model,
      displayName: catalogMachine.displayName,
      imagePath: catalogMachine.imagePath,
      xMm: snapped((current.project.siteWidthMm - catalogMachine.widthMm!) / 2)
          .clamp(0, current.project.siteWidthMm),
      yMm: snapped(
        (current.project.siteLengthMm - catalogMachine.lengthMm!) / 2,
      ).clamp(0, current.project.siteLengthMm),
      lengthMm: catalogMachine.lengthMm!,
      widthMm: catalogMachine.widthMm!,
      heightMm: catalogMachine.heightMm!,
      clearanceFrontMm: clearanceFrontMm,
      clearanceRearMm: clearanceRearMm,
      clearanceLeftMm: clearanceLeftMm,
      clearanceRightMm: clearanceRightMm,
      clearanceVerified: clearanceVerified,
      zIndex: _nextZIndex(current),
    );
    _bundle = current.copyWith(machines: [...current.machines, machine]);
    _selectedId = machine.id;
    _tool = EditorTool.select;
    _commitChange();
  }

  void moveSelected(double deltaXMm, double deltaYMm) {
    final current = _bundle;
    final id = _selectedId;
    if (current == null || id == null || selectedIsLocked) return;
    _beginChange();
    _bundle = current.copyWith(
      machines: current.machines.map((machine) {
        if (machine.id != id) return machine;
        return machine.copyWith(
          xMm: snapped(machine.xMm + deltaXMm),
          yMm: snapped(machine.yMm + deltaYMm),
        );
      }).toList(),
      objects: current.objects.map((object) {
        if (object.id != id) return object;
        return object.copyWith(
          xMm: snapped(object.xMm + deltaXMm),
          yMm: snapped(object.yMm + deltaYMm),
        );
      }).toList(),
      measurements: current.measurements.map((measurement) {
        if (measurement.id != id) return measurement;
        return _movedMeasurement(measurement, deltaXMm, deltaYMm);
      }).toList(),
    );
    _commitChange();
  }

  void updateSelectedMachine(MachinePlacement updated) {
    final current = _bundle;
    if (current == null) return;
    if (updated.clearanceFrontMm < 0 ||
        updated.clearanceRearMm < 0 ||
        updated.clearanceLeftMm < 0 ||
        updated.clearanceRightMm < 0 ||
        updated.clearanceTopMm < 0 ||
        updated.floorToBaseMm < 0) {
      return;
    }
    _beginChange();
    _bundle = current.copyWith(
      machines: current.machines
          .map((machine) => machine.id == updated.id ? updated : machine)
          .toList(),
    );
    _commitChange();
  }

  void updateSelectedObject(SiteLayoutObject updated) {
    final current = _bundle;
    if (current == null) return;
    final minimumThickness = updated.type == SiteObjectType.line
        ? 1.0
        : LayoutGeometryService.minimumObjectSizeMm;
    if (updated.widthMm < LayoutGeometryService.minimumObjectSizeMm ||
        updated.lengthMm < minimumThickness) {
      return;
    }
    _beginChange();
    _bundle = current.copyWith(
      objects: current.objects
          .map((object) => object.id == updated.id ? updated : object)
          .toList(),
    );
    _commitChange();
  }

  void updateSelectedMeasurement(LayoutMeasurement updated) {
    final current = _bundle;
    if (current == null || updated.distanceMm <= 0) return;
    _beginChange();
    _bundle = current.copyWith(
      measurements: current.measurements
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    _commitChange();
  }

  void rotateSelected() {
    rotateSelectedBy(90);
  }

  void rotateSelectedBy(double deltaDegrees) {
    if (selectedIsLocked) return;
    final machine = selectedMachine;
    if (machine != null) {
      _setMachineRotation(machine, machine.rotationDeg + deltaDegrees);
      return;
    }
    final object = selectedObject;
    if (object != null) {
      _setObjectRotation(object, object.rotationDeg + deltaDegrees);
    }
  }

  void setSelectedRotation(double degrees) {
    if (selectedIsLocked) return;
    final machine = selectedMachine;
    if (machine != null) {
      _setMachineRotation(machine, degrees);
      return;
    }
    final object = selectedObject;
    if (object != null) _setObjectRotation(object, degrees);
  }

  void setDimensionTextScale(double value) {
    final current = _bundle;
    if (current == null) return;
    final scale = value.clamp(0.3, 2.5);
    if (current.project.dimensionTextScale == scale) return;
    _beginChange();
    _bundle = current.copyWith(
      project: current.project.copyWith(dimensionTextScale: scale),
    );
    _commitChange();
  }

  void _setObjectRotation(SiteLayoutObject object, double degrees) {
    final center = LayoutGeometryService.objectCenter(object);
    final angle = _normalizedAngle(degrees);
    final bounds = LayoutGeometryService.rotatedBounds(
      center: center,
      width: object.widthMm,
      height: object.lengthMm,
      rotationDeg: angle,
    );
    updateSelectedObject(
      object.copyWith(rotationDeg: angle, xMm: bounds.left, yMm: bounds.top),
    );
  }

  void _setMachineRotation(MachinePlacement machine, double degrees) {
    final center = LayoutGeometryService.machineCenter(machine);
    final angle = _normalizedAngle(degrees);
    final bounds = LayoutGeometryService.rotatedBounds(
      center: center,
      width: machine.widthMm,
      height: machine.lengthMm,
      rotationDeg: angle,
    );
    updateSelectedMachine(
      machine.copyWith(rotationDeg: angle, xMm: bounds.left, yMm: bounds.top),
    );
  }

  double _normalizedAngle(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  void toggleLockSelected() {
    final machine = selectedMachine;
    if (machine != null) {
      updateSelectedMachine(machine.copyWith(isLocked: !machine.isLocked));
      return;
    }
    final object = selectedObject;
    if (object != null) {
      updateSelectedObject(object.copyWith(isLocked: !object.isLocked));
    }
  }

  void duplicateSelected() {
    final current = _bundle;
    if (current == null) return;
    final machine = selectedMachine;
    final object = selectedObject;
    final measurement = selectedMeasurement;
    if (machine == null && object == null && measurement == null) return;
    _beginChange();
    if (machine != null) {
      final duplicate = machine.copyWith(
        id: newSiteLayoutId('machine'),
        xMm: snapped(machine.xMm + _gridMm),
        yMm: snapped(machine.yMm + _gridMm),
        isLocked: false,
        zIndex: _nextZIndex(current),
      );
      _bundle = current.copyWith(machines: [...current.machines, duplicate]);
      _selectedId = duplicate.id;
    } else if (object != null) {
      final duplicate = object.copyWith(
        id: newSiteLayoutId('object'),
        xMm: snapped(object.xMm + _gridMm),
        yMm: snapped(object.yMm + _gridMm),
        isLocked: false,
        zIndex: _nextZIndex(current),
      );
      _bundle = current.copyWith(objects: [...current.objects, duplicate]);
      _selectedId = duplicate.id;
    } else if (measurement != null) {
      final duplicate = _movedMeasurement(
        measurement,
        _gridMm,
        _gridMm,
      ).copyWith(id: newSiteLayoutId('measurement'));
      _bundle = current.copyWith(
        measurements: [...current.measurements, duplicate],
      );
      _selectedId = duplicate.id;
    }
    _commitChange();
  }

  bool beginTransform(String id) {
    final current = _bundle;
    if (current == null) return false;
    _selectedId = id;
    final object = selectedObject;
    final machine = selectedMachine;
    final measurement = selectedMeasurement;
    if (object?.isLocked == true || machine?.isLocked == true) {
      notifyListeners();
      return false;
    }
    if (object == null && machine == null && measurement == null) return false;
    _transformStartBundle = current;
    _transformId = id;
    _transformChanged = false;
    _activeSnapPoint = null;
    notifyListeners();
    return true;
  }

  void updateTransformMove(double deltaXMm, double deltaYMm) {
    final start = _transformStartBundle;
    final id = _transformId;
    if (start == null || id == null) return;
    _activeSnapPoint = null;
    final targets = LayoutGeometryService.bundleSnapPoints(
      start,
      excludeId: id,
    );
    _bundle = start.copyWith(
      machines: start.machines.map((machine) {
        if (machine.id != id || machine.isLocked) return machine;
        var moved = machine.copyWith(
          xMm: snapped(machine.xMm + deltaXMm),
          yMm: snapped(machine.yMm + deltaYMm),
        );
        if (_snapToGrid) {
          final match = LayoutGeometryService.closestSnapMatch(
            LayoutGeometryService.machineSnapPoints(moved),
            targets,
          );
          if (match != null) {
            moved = moved.copyWith(
              xMm: moved.xMm + match.target.x - match.source.x,
              yMm: moved.yMm + match.target.y - match.source.y,
            );
            _activeSnapPoint = match.target;
          }
        }
        return moved;
      }).toList(),
      objects: start.objects.map((object) {
        if (object.id != id || object.isLocked) return object;
        var moved = object.copyWith(
          xMm: snapped(object.xMm + deltaXMm),
          yMm: snapped(object.yMm + deltaYMm),
        );
        if (_snapToGrid) {
          final match = LayoutGeometryService.closestSnapMatch(
            LayoutGeometryService.objectSnapPoints(moved),
            targets,
          );
          if (match != null) {
            moved = moved.copyWith(
              xMm: moved.xMm + match.target.x - match.source.x,
              yMm: moved.yMm + match.target.y - match.source.y,
            );
            _activeSnapPoint = match.target;
          }
        }
        return moved;
      }).toList(),
      measurements: start.measurements.map((measurement) {
        if (measurement.id != id) return measurement;
        return _movedMeasurement(measurement, deltaXMm, deltaYMm);
      }).toList(),
    );
    final movedMachine = _bundle!.machines.any((machine) {
      final original = start.machines.where((item) => item.id == machine.id);
      return original.isNotEmpty &&
          (machine.xMm != original.first.xMm ||
              machine.yMm != original.first.yMm);
    });
    final movedObject = _bundle!.objects.any((object) {
      final original = start.objects.where((item) => item.id == object.id);
      return original.isNotEmpty &&
          (object.xMm != original.first.xMm ||
              object.yMm != original.first.yMm);
    });
    final movedMeasurement = _bundle!.measurements.any((measurement) {
      final original = start.measurements.where(
        (item) => item.id == measurement.id,
      );
      return original.isNotEmpty &&
          (measurement.x1Mm != original.first.x1Mm ||
              measurement.y1Mm != original.first.y1Mm ||
              measurement.x2Mm != original.first.x2Mm ||
              measurement.y2Mm != original.first.y2Mm);
    });
    _transformChanged = movedMachine || movedObject || movedMeasurement;
    notifyListeners();
  }

  void updateTransformResize(
    LayoutResizeHandle handle,
    double pointerXMm,
    double pointerYMm,
  ) {
    final start = _transformStartBundle;
    final id = _transformId;
    if (start == null || id == null) return;
    LayoutMeasurement? originalMeasurement;
    for (final measurement in start.measurements) {
      if (measurement.id == id) originalMeasurement = measurement;
    }
    if (originalMeasurement != null) {
      final pointer = math.Point(pointerXMm, pointerYMm);
      final pointSnap = _snapToGrid
          ? LayoutGeometryService.nearestSnapPoint(
              pointer,
              LayoutGeometryService.bundleSnapPoints(start, excludeId: id),
            )
          : null;
      final target =
          pointSnap ??
          math.Point(
            _snapToGrid ? snapped(pointer.x) : pointer.x,
            _snapToGrid ? snapped(pointer.y) : pointer.y,
          );
      _activeSnapPoint = pointSnap;
      final resized = handle == LayoutResizeHandle.leftEnd
          ? originalMeasurement.copyWith(x1Mm: target.x, y1Mm: target.y)
          : originalMeasurement.copyWith(x2Mm: target.x, y2Mm: target.y);
      if (resized.distanceMm <= 0) return;
      _bundle = start.copyWith(
        measurements: start.measurements
            .map((item) => item.id == id ? resized : item)
            .toList(),
      );
      _transformChanged =
          resized.x1Mm != originalMeasurement.x1Mm ||
          resized.y1Mm != originalMeasurement.y1Mm ||
          resized.x2Mm != originalMeasurement.x2Mm ||
          resized.y2Mm != originalMeasurement.y2Mm;
      notifyListeners();
      return;
    }
    SiteLayoutObject? original;
    for (final object in start.objects) {
      if (object.id == id) original = object;
    }
    if (original == null || original.isLocked) return;
    final pointer = math.Point(pointerXMm, pointerYMm);
    final pointSnap = _snapToGrid
        ? LayoutGeometryService.nearestSnapPoint(
            pointer,
            LayoutGeometryService.bundleSnapPoints(start, excludeId: id),
          )
        : null;
    _activeSnapPoint = pointSnap;
    final resized = LayoutGeometryService.resizeObject(
      original,
      handle,
      pointSnap ?? pointer,
      snapToGrid: _snapToGrid && pointSnap == null,
      gridMm: _gridMm,
    );
    _bundle = start.copyWith(
      objects: start.objects
          .map((object) => object.id == id ? resized : object)
          .toList(),
    );
    _transformChanged =
        resized.widthMm != original.widthMm ||
        resized.lengthMm != original.lengthMm ||
        resized.rotationDeg != original.rotationDeg ||
        resized.xMm != original.xMm ||
        resized.yMm != original.yMm;
    notifyListeners();
  }

  void updateTransformRotation(double pointerXMm, double pointerYMm) {
    final start = _transformStartBundle;
    final id = _transformId;
    if (start == null || id == null) return;
    _activeSnapPoint = null;
    final originalObject = start.objects.where((item) => item.id == id);
    final originalMachine = start.machines.where((item) => item.id == id);
    if (originalObject.isNotEmpty && !originalObject.first.isLocked) {
      final object = originalObject.first;
      final center = LayoutGeometryService.objectCenter(object);
      final angle = LayoutGeometryService.normalizedAngle(
        math.atan2(pointerYMm - center.y, pointerXMm - center.x) *
                180 /
                math.pi +
            90,
      );
      final bounds = LayoutGeometryService.rotatedBounds(
        center: center,
        width: object.widthMm,
        height: object.lengthMm,
        rotationDeg: angle,
      );
      final rotated = object.copyWith(
        rotationDeg: angle,
        xMm: bounds.left,
        yMm: bounds.top,
      );
      _bundle = start.copyWith(
        objects: start.objects
            .map((item) => item.id == id ? rotated : item)
            .toList(),
      );
      _transformChanged = angle != object.rotationDeg;
      notifyListeners();
      return;
    }
    if (originalMachine.isNotEmpty && !originalMachine.first.isLocked) {
      final machine = originalMachine.first;
      final center = LayoutGeometryService.machineCenter(machine);
      final angle = LayoutGeometryService.normalizedAngle(
        math.atan2(pointerYMm - center.y, pointerXMm - center.x) *
                180 /
                math.pi +
            90,
      );
      final bounds = LayoutGeometryService.rotatedBounds(
        center: center,
        width: machine.widthMm,
        height: machine.lengthMm,
        rotationDeg: angle,
      );
      final rotated = machine.copyWith(
        rotationDeg: angle,
        xMm: bounds.left,
        yMm: bounds.top,
      );
      _bundle = start.copyWith(
        machines: start.machines
            .map((item) => item.id == id ? rotated : item)
            .toList(),
      );
      _transformChanged = angle != machine.rotationDeg;
      notifyListeners();
    }
  }

  void trimLinearObject(String id, double tapXMm, double tapYMm) {
    final current = _bundle;
    if (current == null) return;
    SiteLayoutObject? target;
    for (final object in current.objects) {
      if (object.id == id) target = object;
    }
    if (target == null || target.isLocked) return;
    final trimmed = LayoutGeometryService.trimLinearObject(
      target,
      math.Point(tapXMm, tapYMm),
      LayoutGeometryService.boundarySegments(current, excludeId: id),
    );
    if (trimmed.length == 1 && trimmed.single == target) return;
    _beginChange();
    _bundle = current.copyWith(
      objects: [
        for (final object in current.objects)
          if (object.id != id) object,
        ...trimmed,
      ],
    );
    _selectedId = trimmed.isEmpty ? null : trimmed.first.id;
    _commitChange();
  }

  void endTransform() {
    final start = _transformStartBundle;
    final changed = _transformChanged;
    final hadSnapPoint = _activeSnapPoint != null;
    _transformStartBundle = null;
    _transformId = null;
    _transformChanged = false;
    _activeSnapPoint = null;
    if (start != null && changed) {
      _pushUndo(start);
      _commitChange();
    } else if (hadSnapPoint) {
      notifyListeners();
    }
  }

  int _nextZIndex(SiteLayoutBundle bundle) {
    final values = <int>[
      ...bundle.objects.map((item) => item.zIndex),
      ...bundle.machines.map((item) => item.zIndex),
    ];
    return values.isEmpty ? 0 : values.reduce(math.max) + 1;
  }

  void deleteSelected() {
    final current = _bundle;
    final id = _selectedId;
    if (current == null || id == null) return;
    _beginChange();
    _bundle = current.copyWith(
      machines: current.machines.where((item) => item.id != id).toList(),
      objects: current.objects.where((item) => item.id != id).toList(),
      measurements: current.measurements
          .where((item) => item.id != id)
          .toList(),
      annotations: current.annotations.where((item) => item.id != id).toList(),
      photoMarkers: current.photoMarkers
          .where((item) => item.id != id)
          .toList(),
    );
    _selectedId = null;
    _commitChange();
  }

  void addMeasurement(double x1, double y1, double x2, double y2) {
    final current = _bundle;
    if (current == null) return;
    _beginChange();
    final measurement = LayoutMeasurement(
      id: newSiteLayoutId('measurement'),
      layoutId: current.layout.id,
      x1Mm: snapped(x1),
      y1Mm: snapped(y1),
      x2Mm: snapped(x2),
      y2Mm: snapped(y2),
    );
    _bundle = current.copyWith(
      measurements: [...current.measurements, measurement],
    );
    _selectedId = measurement.id;
    _tool = EditorTool.select;
    _commitChange();
  }

  void addAnnotation(double xMm, double yMm, String text) {
    final current = _bundle;
    if (current == null || text.trim().isEmpty) return;
    _beginChange();
    final annotation = LayoutAnnotation(
      id: newSiteLayoutId('annotation'),
      layoutId: current.layout.id,
      xMm: snapped(xMm),
      yMm: snapped(yMm),
      text: text.trim(),
      markerNumber: current.annotations.length + 1,
    );
    _bundle = current.copyWith(
      annotations: [...current.annotations, annotation],
    );
    _selectedId = annotation.id;
    _commitChange();
  }

  Future<void> addPhoto(SitePhoto photo) async {
    await _repository.addPhoto(photo);
    if (_bundle?.project.id == photo.projectId) {
      _bundle = _bundle!.copyWith(photos: [..._bundle!.photos, photo]);
      notifyListeners();
    }
  }

  void addPhotoMarker(double xMm, double yMm, SitePhoto photo) {
    final current = _bundle;
    if (current == null) return;
    _beginChange();
    final marker = PhotoMarker(
      id: newSiteLayoutId('photo_marker'),
      layoutId: current.layout.id,
      photoId: photo.id,
      markerNumber: current.photoMarkers.isEmpty
          ? 1
          : current.photoMarkers
                    .map((item) => item.markerNumber)
                    .reduce((a, b) => a > b ? a : b) +
                1,
      xMm: snapped(xMm),
      yMm: snapped(yMm),
    );
    _bundle = current.copyWith(photoMarkers: [...current.photoMarkers, marker]);
    _selectedId = marker.id;
    _commitChange();
  }

  Future<void> deletePhoto(SitePhoto photo) async {
    await _repository.deletePhoto(photo.id);
    try {
      await deleteSiteLayoutFile(photo.originalPath);
      if (photo.thumbnailPath != null) {
        await deleteSiteLayoutFile(photo.thumbnailPath!);
      }
    } catch (_) {
      // Bản ghi đã xóa an toàn; tệp lỗi/không còn tồn tại không được phép
      // làm UI giữ lại ảnh và marker mồ côi.
    }
    final current = _bundle;
    if (current != null) {
      _bundle = current.copyWith(
        photos: current.photos.where((item) => item.id != photo.id).toList(),
        photoMarkers: current.photoMarkers
            .where((item) => item.photoId != photo.id)
            .toList(),
      );
      notifyListeners();
    }
  }

  void updateProjectInEditor(SiteLayoutProject project) {
    final current = _bundle;
    if (current == null || project.id != current.project.id) return;
    _beginChange();
    _bundle = current.copyWith(project: project);
    _commitChange();
  }

  void undo() {
    final current = _bundle;
    if (current == null || _undo.isEmpty) return;
    _redo.add(current);
    _bundle = _undo.removeLast();
    _selectedId = null;
    _markDirty();
  }

  void redo() {
    final current = _bundle;
    if (current == null || _redo.isEmpty) return;
    _undo.add(current);
    _bundle = _redo.removeLast();
    _selectedId = null;
    _markDirty();
  }

  void _beginChange() {
    if (_bundle == null) return;
    _pushUndo(_bundle!);
  }

  void _pushUndo(SiteLayoutBundle snapshot) {
    _undo.add(snapshot);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _commitChange() => _markDirty();

  void _markDirty() {
    _revision++;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 650), saveNow);
    notifyListeners();
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (_bundle == null || _savedRevision == _revision) return;
    if (_savingFuture != null) {
      await _savingFuture;
      if (_savedRevision != _revision) await saveNow();
      return;
    }
    final completer = Completer<void>();
    _savingFuture = completer.future;
    _isSaving = true;
    notifyListeners();
    try {
      while (_bundle != null && _savedRevision != _revision) {
        final snapshot = _bundle!;
        final targetRevision = _revision;
        await _repository.saveBundle(snapshot);
        _savedRevision = targetRevision;
        _lastSavedAt = DateTime.now();
        _error = null;
      }
    } catch (error) {
      _error = 'Không thể tự động lưu: $error';
    } finally {
      _isSaving = false;
      _savingFuture = null;
      completer.complete();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
