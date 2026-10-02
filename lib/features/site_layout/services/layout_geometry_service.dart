import 'dart:math' as math;

import '../models/site_layout_models.dart';

enum LayoutResizeHandle {
  leftEnd,
  rightEnd,
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
}

class LayoutSnapMatch {
  const LayoutSnapMatch({
    required this.source,
    required this.target,
    required this.distanceMm,
  });

  final math.Point<double> source;
  final math.Point<double> target;
  final double distanceMm;
}

abstract final class LayoutGeometryService {
  static const double minimumObjectSizeMm = 100;
  static const double defaultPointSnapToleranceMm = 200;

  static double snap(double value, double gridMm) {
    if (gridMm <= 0) return value;
    return (value / gridMm).round() * gridMm;
  }

  static math.Rectangle<double> machineRect(MachinePlacement machine) =>
      math.Rectangle<double>(
        machine.xMm,
        machine.yMm,
        machine.renderedWidthMm,
        machine.renderedLengthMm,
      );

  static math.Rectangle<double> objectRect(SiteLayoutObject object) =>
      math.Rectangle<double>(
        object.xMm,
        object.yMm,
        object.renderedWidthMm,
        object.renderedLengthMm,
      );

  static math.Point<double> objectCenter(SiteLayoutObject object) => math.Point(
    object.xMm + object.renderedWidthMm / 2,
    object.yMm + object.renderedLengthMm / 2,
  );

  static math.Point<double> machineCenter(MachinePlacement machine) =>
      math.Point(
        machine.xMm + machine.renderedWidthMm / 2,
        machine.yMm + machine.renderedLengthMm / 2,
      );

  static List<math.Point<double>> objectSnapPoints(SiteLayoutObject object) {
    final center = objectCenter(object);
    if (object.type.isLinear) {
      return [
        objectHandlePoint(object, LayoutResizeHandle.leftEnd),
        objectHandlePoint(object, LayoutResizeHandle.rightEnd),
        center,
      ];
    }
    return _rectSnapPoints(objectCorners(object), center);
  }

  static List<math.Point<double>> machineSnapPoints(MachinePlacement machine) =>
      _rectSnapPoints(machineCorners(machine), machineCenter(machine));

  static List<math.Point<double>> bundleSnapPoints(
    SiteLayoutBundle bundle, {
    String? excludeId,
  }) => [
    const math.Point(0, 0),
    math.Point(bundle.project.siteWidthMm, 0),
    math.Point(0, bundle.project.siteLengthMm),
    math.Point(bundle.project.siteWidthMm, bundle.project.siteLengthMm),
    for (final object in bundle.objects)
      if (object.id != excludeId) ...objectSnapPoints(object),
    for (final machine in bundle.machines)
      if (machine.id != excludeId) ...machineSnapPoints(machine),
  ];

  static math.Point<double>? nearestSnapPoint(
    math.Point<double> point,
    Iterable<math.Point<double>> candidates, {
    double toleranceMm = defaultPointSnapToleranceMm,
  }) {
    math.Point<double>? nearest;
    var nearestDistance = toleranceMm;
    for (final candidate in candidates) {
      final distance = point.distanceTo(candidate);
      if (distance <= nearestDistance) {
        nearest = candidate;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  static LayoutSnapMatch? closestSnapMatch(
    Iterable<math.Point<double>> sources,
    Iterable<math.Point<double>> targets, {
    double toleranceMm = defaultPointSnapToleranceMm,
  }) {
    LayoutSnapMatch? nearest;
    for (final source in sources) {
      for (final target in targets) {
        final distance = source.distanceTo(target);
        if (distance <= toleranceMm &&
            (nearest == null || distance < nearest.distanceMm)) {
          nearest = LayoutSnapMatch(
            source: source,
            target: target,
            distanceMm: distance,
          );
        }
      }
    }
    return nearest;
  }

  static List<(math.Point<double>, math.Point<double>)> boundarySegments(
    SiteLayoutBundle bundle, {
    String? excludeId,
  }) {
    final segments = <(math.Point<double>, math.Point<double>)>[
      (const math.Point(0, 0), math.Point(bundle.project.siteWidthMm, 0)),
      (
        math.Point(bundle.project.siteWidthMm, 0),
        math.Point(bundle.project.siteWidthMm, bundle.project.siteLengthMm),
      ),
      (
        math.Point(bundle.project.siteWidthMm, bundle.project.siteLengthMm),
        math.Point(0, bundle.project.siteLengthMm),
      ),
      (math.Point(0, bundle.project.siteLengthMm), const math.Point(0, 0)),
    ];
    for (final object in bundle.objects) {
      if (object.id == excludeId) continue;
      if (object.type.isLinear) {
        segments.add((
          objectHandlePoint(object, LayoutResizeHandle.leftEnd),
          objectHandlePoint(object, LayoutResizeHandle.rightEnd),
        ));
      } else {
        _addRectSegments(segments, objectCorners(object));
      }
    }
    for (final machine in bundle.machines) {
      if (machine.id != excludeId) {
        _addRectSegments(segments, machineCorners(machine));
      }
    }
    return segments;
  }

  static List<SiteLayoutObject> trimLinearObject(
    SiteLayoutObject object,
    math.Point<double> tap,
    Iterable<(math.Point<double>, math.Point<double>)> boundaries,
  ) {
    if (!object.type.isLinear) {
      return [object];
    }
    final start = objectHandlePoint(object, LayoutResizeHandle.leftEnd);
    final end = objectHandlePoint(object, LayoutResizeHandle.rightEnd);
    final intersections = <double>[];
    for (final boundary in boundaries) {
      final parameter = _segmentIntersectionParameter(
        start,
        end,
        boundary.$1,
        boundary.$2,
      );
      if (parameter != null &&
          parameter > 0.0001 &&
          parameter < 0.9999 &&
          intersections.every((value) => (value - parameter).abs() > 0.0001)) {
        intersections.add(parameter);
      }
    }
    if (intersections.isEmpty) return [object];
    intersections.sort();
    final tapParameter = _projectionParameter(start, end, tap);
    double? lower;
    double? upper;
    for (final parameter in intersections) {
      if (parameter <= tapParameter) {
        lower = parameter;
      } else {
        upper ??= parameter;
      }
    }
    math.Point<double> at(double value) => math.Point(
      start.x + (end.x - start.x) * value,
      start.y + (end.y - start.y) * value,
    );

    final result = <SiteLayoutObject>[];
    void addSegment(
      math.Point<double> segmentStart,
      math.Point<double> segmentEnd, {
      required String id,
    }) {
      if (segmentStart.distanceTo(segmentEnd) < minimumObjectSizeMm) return;
      result.add(
        objectFromSegment(
          object.copyWith(id: id),
          start: segmentStart,
          end: segmentEnd,
          thicknessMm: object.lengthMm,
        ),
      );
    }

    if (lower == null && upper != null) {
      addSegment(at(upper), end, id: object.id);
    } else if (lower != null && upper == null) {
      addSegment(start, at(lower), id: object.id);
    } else if (lower != null && upper != null) {
      addSegment(start, at(lower), id: object.id);
      addSegment(at(upper), end, id: newSiteLayoutId('object'));
    }
    return result;
  }

  static double _projectionParameter(
    math.Point<double> start,
    math.Point<double> end,
    math.Point<double> point,
  ) {
    final dx = end.x - start.x;
    final dy = end.y - start.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return 0;
    return (((point.x - start.x) * dx + (point.y - start.y) * dy) /
            lengthSquared)
        .clamp(0.0, 1.0);
  }

  static double? _segmentIntersectionParameter(
    math.Point<double> p,
    math.Point<double> p2,
    math.Point<double> q,
    math.Point<double> q2,
  ) {
    final rx = p2.x - p.x;
    final ry = p2.y - p.y;
    final sx = q2.x - q.x;
    final sy = q2.y - q.y;
    final cross = rx * sy - ry * sx;
    if (cross.abs() < 1e-9) return null;
    final qpx = q.x - p.x;
    final qpy = q.y - p.y;
    final t = (qpx * sy - qpy * sx) / cross;
    final u = (qpx * ry - qpy * rx) / cross;
    if (t < 0 || t > 1 || u < 0 || u > 1) return null;
    return t;
  }

  static void _addRectSegments(
    List<(math.Point<double>, math.Point<double>)> target,
    List<math.Point<double>> corners,
  ) {
    for (var index = 0; index < corners.length; index++) {
      target.add((corners[index], corners[(index + 1) % corners.length]));
    }
  }

  static List<math.Point<double>> _rectSnapPoints(
    List<math.Point<double>> corners,
    math.Point<double> center,
  ) {
    final points = <math.Point<double>>[center, ...corners];
    for (var index = 0; index < corners.length; index++) {
      final first = corners[index];
      final second = corners[(index + 1) % corners.length];
      points.add(
        math.Point((first.x + second.x) / 2, (first.y + second.y) / 2),
      );
    }
    return points;
  }

  static List<math.Point<double>> objectCorners(SiteLayoutObject object) =>
      rotatedCorners(
        center: objectCenter(object),
        width: object.widthMm,
        height: object.lengthMm,
        rotationDeg: object.rotationDeg,
      );

  static List<math.Point<double>> machineCorners(MachinePlacement machine) =>
      rotatedCorners(
        center: machineCenter(machine),
        width: machine.widthMm,
        height: machine.lengthMm,
        rotationDeg: machine.rotationDeg,
      );

  static List<math.Point<double>> rotatedCorners({
    required math.Point<double> center,
    required double width,
    required double height,
    required double rotationDeg,
  }) => [
    localToWorld(center, -width / 2, -height / 2, rotationDeg),
    localToWorld(center, width / 2, -height / 2, rotationDeg),
    localToWorld(center, width / 2, height / 2, rotationDeg),
    localToWorld(center, -width / 2, height / 2, rotationDeg),
  ];

  static math.Point<double> localToWorld(
    math.Point<double> center,
    double localX,
    double localY,
    double rotationDeg,
  ) {
    final radians = rotationDeg * math.pi / 180;
    final cosAngle = math.cos(radians);
    final sinAngle = math.sin(radians);
    return math.Point(
      center.x + localX * cosAngle - localY * sinAngle,
      center.y + localX * sinAngle + localY * cosAngle,
    );
  }

  static math.Point<double> worldToLocal(
    math.Point<double> center,
    math.Point<double> world,
    double rotationDeg,
  ) {
    final radians = -rotationDeg * math.pi / 180;
    final dx = world.x - center.x;
    final dy = world.y - center.y;
    return math.Point(
      dx * math.cos(radians) - dy * math.sin(radians),
      dx * math.sin(radians) + dy * math.cos(radians),
    );
  }

  static bool containsObject(
    SiteLayoutObject object,
    math.Point<double> point,
  ) {
    final local = worldToLocal(objectCenter(object), point, object.rotationDeg);
    return local.x.abs() <= object.widthMm / 2 &&
        local.y.abs() <= object.lengthMm / 2;
  }

  static bool containsMachine(
    MachinePlacement machine,
    math.Point<double> point,
  ) {
    final local = worldToLocal(
      machineCenter(machine),
      point,
      machine.rotationDeg,
    );
    return local.x.abs() <= machine.widthMm / 2 &&
        local.y.abs() <= machine.lengthMm / 2;
  }

  static math.Point<double> objectHandlePoint(
    SiteLayoutObject object,
    LayoutResizeHandle handle,
  ) {
    final center = objectCenter(object);
    final (x, y) = switch (handle) {
      LayoutResizeHandle.leftEnd => (-object.widthMm / 2, 0.0),
      LayoutResizeHandle.rightEnd => (object.widthMm / 2, 0.0),
      LayoutResizeHandle.topLeft => (-object.widthMm / 2, -object.lengthMm / 2),
      LayoutResizeHandle.topRight => (object.widthMm / 2, -object.lengthMm / 2),
      LayoutResizeHandle.bottomRight => (
        object.widthMm / 2,
        object.lengthMm / 2,
      ),
      LayoutResizeHandle.bottomLeft => (
        -object.widthMm / 2,
        object.lengthMm / 2,
      ),
    };
    return localToWorld(center, x, y, object.rotationDeg);
  }

  static SiteLayoutObject resizeObject(
    SiteLayoutObject object,
    LayoutResizeHandle handle,
    math.Point<double> pointer, {
    required bool snapToGrid,
    required double gridMm,
  }) {
    final isLinear = object.type.isLinear;
    if (isLinear) {
      return _resizeLinearObject(
        object,
        handle,
        pointer,
        snapToGrid: snapToGrid,
        gridMm: gridMm,
      );
    }
    final angle = object.rotationDeg * math.pi / 180;
    final axisX = math.Point(math.cos(angle), math.sin(angle));
    final axisY = math.Point(-math.sin(angle), math.cos(angle));
    final center = objectCenter(object);
    final (signX, signY) = switch (handle) {
      LayoutResizeHandle.leftEnd => (-1.0, 0.0),
      LayoutResizeHandle.rightEnd => (1.0, 0.0),
      LayoutResizeHandle.topLeft => (-1.0, -1.0),
      LayoutResizeHandle.topRight => (1.0, -1.0),
      LayoutResizeHandle.bottomRight => (1.0, 1.0),
      LayoutResizeHandle.bottomLeft => (-1.0, 1.0),
    };
    final opposite = localToWorld(
      center,
      -signX * object.widthMm / 2,
      -signY * object.lengthMm / 2,
      object.rotationDeg,
    );
    final deltaX = pointer.x - opposite.x;
    final deltaY = pointer.y - opposite.y;
    final projectedWidth = signX * (deltaX * axisX.x + deltaY * axisX.y);
    final newWidth = _resizeDimension(
      projectedWidth,
      snapToGrid: snapToGrid,
      gridMm: gridMm,
    );
    final newLength = _resizeDimension(
      signY * (deltaX * axisY.x + deltaY * axisY.y),
      snapToGrid: snapToGrid,
      gridMm: gridMm,
    );
    final newCenter = math.Point(
      opposite.x +
          axisX.x * signX * newWidth / 2 +
          axisY.x * signY * newLength / 2,
      opposite.y +
          axisX.y * signX * newWidth / 2 +
          axisY.y * signY * newLength / 2,
    );
    final bounds = rotatedBounds(
      center: newCenter,
      width: newWidth,
      height: newLength,
      rotationDeg: object.rotationDeg,
    );
    return object.copyWith(
      xMm: bounds.left,
      yMm: bounds.top,
      widthMm: newWidth,
      lengthMm: newLength,
    );
  }

  static SiteLayoutObject _resizeLinearObject(
    SiteLayoutObject object,
    LayoutResizeHandle handle,
    math.Point<double> pointer, {
    required bool snapToGrid,
    required double gridMm,
  }) {
    if (handle != LayoutResizeHandle.leftEnd &&
        handle != LayoutResizeHandle.rightEnd) {
      return object;
    }
    var dragged = snapToGrid
        ? math.Point(snap(pointer.x, gridMm), snap(pointer.y, gridMm))
        : pointer;
    final fixedHandle = handle == LayoutResizeHandle.leftEnd
        ? LayoutResizeHandle.rightEnd
        : LayoutResizeHandle.leftEnd;
    final fixed = objectHandlePoint(object, fixedHandle);
    var dx = dragged.x - fixed.x;
    var dy = dragged.y - fixed.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < minimumObjectSizeMm) {
      if (distance < 1e-9) {
        final radians = object.rotationDeg * math.pi / 180;
        final direction = handle == LayoutResizeHandle.rightEnd ? 1 : -1;
        dx = math.cos(radians) * direction;
        dy = math.sin(radians) * direction;
      } else {
        dx /= distance;
        dy /= distance;
      }
      dragged = math.Point(
        fixed.x + dx * minimumObjectSizeMm,
        fixed.y + dy * minimumObjectSizeMm,
      );
    }
    return objectFromSegment(
      object,
      start: handle == LayoutResizeHandle.leftEnd ? dragged : fixed,
      end: handle == LayoutResizeHandle.leftEnd ? fixed : dragged,
      thicknessMm: object.lengthMm,
    );
  }

  static SiteLayoutObject objectFromSegment(
    SiteLayoutObject object, {
    required math.Point<double> start,
    required math.Point<double> end,
    required double thicknessMm,
  }) {
    var dx = end.x - start.x;
    var dy = end.y - start.y;
    var length = math.sqrt(dx * dx + dy * dy);
    if (length < minimumObjectSizeMm) {
      if (length < 1e-9) {
        final radians = object.rotationDeg * math.pi / 180;
        dx = math.cos(radians);
        dy = math.sin(radians);
        length = 1;
      }
      final scale = minimumObjectSizeMm / length;
      dx *= scale;
      dy *= scale;
      length = minimumObjectSizeMm;
    }
    final angle = normalizedAngle(math.atan2(dy, dx) * 180 / math.pi);
    final center = math.Point(start.x + dx / 2, start.y + dy / 2);
    final minimumThickness = object.type == SiteObjectType.line
        ? 1.0
        : minimumObjectSizeMm;
    final safeThickness = math.max(minimumThickness, thicknessMm);
    final bounds = rotatedBounds(
      center: center,
      width: length,
      height: safeThickness,
      rotationDeg: angle,
    );
    return object.copyWith(
      xMm: bounds.left,
      yMm: bounds.top,
      widthMm: length,
      lengthMm: safeThickness,
      rotationDeg: angle,
    );
  }

  static SiteLayoutObject updateObjectDimensions(
    SiteLayoutObject object, {
    required double widthMm,
    required double lengthMm,
    required double rotationDeg,
  }) {
    final angle = normalizedAngle(rotationDeg);
    final isLinear = object.type.isLinear;
    if (isLinear) {
      final start = objectHandlePoint(object, LayoutResizeHandle.leftEnd);
      final radians = angle * math.pi / 180;
      return objectFromSegment(
        object,
        start: start,
        end: math.Point(
          start.x + widthMm * math.cos(radians),
          start.y + widthMm * math.sin(radians),
        ),
        thicknessMm: lengthMm,
      );
    }
    final center = objectCenter(object);
    final bounds = rotatedBounds(
      center: center,
      width: widthMm,
      height: lengthMm,
      rotationDeg: angle,
    );
    return object.copyWith(
      xMm: bounds.left,
      yMm: bounds.top,
      widthMm: widthMm,
      lengthMm: lengthMm,
      rotationDeg: angle,
    );
  }

  static double normalizedAngle(double value) {
    final normalized = value % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  static double _resizeDimension(
    double value, {
    required bool snapToGrid,
    required double gridMm,
  }) {
    final snappedValue = snapToGrid ? snap(value, gridMm) : value;
    return math.max(minimumObjectSizeMm, snappedValue);
  }

  static math.Rectangle<double> rotatedBounds({
    required math.Point<double> center,
    required double width,
    required double height,
    required double rotationDeg,
  }) {
    final corners = rotatedCorners(
      center: center,
      width: width,
      height: height,
      rotationDeg: rotationDeg,
    );
    final left = corners.map((point) => point.x).reduce(math.min);
    final top = corners.map((point) => point.y).reduce(math.min);
    final right = corners.map((point) => point.x).reduce(math.max);
    final bottom = corners.map((point) => point.y).reduce(math.max);
    return math.Rectangle(left, top, right - left, bottom - top);
  }

  static WorldClearance worldClearance(MachinePlacement machine) {
    final local = localClearance(machine);
    final quadrant = ((machine.rotationDeg % 360) / 90).round() * 90 % 360;
    return switch (quadrant) {
      90 => WorldClearance(
        top: local.left,
        right: local.top,
        bottom: local.right,
        left: local.bottom,
      ),
      180 => WorldClearance(
        top: local.bottom,
        right: local.left,
        bottom: local.top,
        left: local.right,
      ),
      270 => WorldClearance(
        top: local.right,
        right: local.bottom,
        bottom: local.left,
        left: local.top,
      ),
      _ => WorldClearance(
        top: local.top,
        right: local.right,
        bottom: local.bottom,
        left: local.left,
      ),
    };
  }

  /// Maps semantic clearances to the four local edges. The front face is the
  /// longest edge of the machine footprint. For a portrait footprint this
  /// puts the front on the local right edge; for a landscape/square footprint
  /// it remains on the local top edge.
  static ({double top, double right, double bottom, double left})
  localClearance(MachinePlacement machine) {
    if (machine.lengthMm > machine.widthMm) {
      return (
        top: machine.clearanceLeftMm,
        right: machine.clearanceFrontMm,
        bottom: machine.clearanceRightMm,
        left: machine.clearanceRearMm,
      );
    }
    return (
      top: machine.clearanceFrontMm,
      right: machine.clearanceRightMm,
      bottom: machine.clearanceRearMm,
      left: machine.clearanceLeftMm,
    );
  }

  static math.Rectangle<double> clearanceRect(MachinePlacement machine) {
    final center = machineCenter(machine);
    final local = localClearance(machine);
    final left = -machine.widthMm / 2 - local.left;
    final right = machine.widthMm / 2 + local.right;
    final top = -machine.lengthMm / 2 - local.top;
    final bottom = machine.lengthMm / 2 + local.bottom;
    final localCenterX = (left + right) / 2;
    final localCenterY = (top + bottom) / 2;
    final clearanceCenter = localToWorld(
      center,
      localCenterX,
      localCenterY,
      machine.rotationDeg,
    );
    return rotatedBounds(
      center: clearanceCenter,
      width: right - left,
      height: bottom - top,
      rotationDeg: machine.rotationDeg,
    );
  }

  static List<LayoutWarning> validate(SiteLayoutBundle bundle) {
    final warnings = <LayoutWarning>[];
    final project = bundle.project;
    final blockers = <({String id, String name, math.Rectangle<double> rect})>[
      for (final object in bundle.objects)
        if (object.type != SiteObjectType.line)
          (
            id: object.id,
            name: object.label.isEmpty ? object.type.label : object.label,
            rect: objectRect(object),
          ),
    ];

    for (final machine in bundle.machines) {
      final footprint = machineRect(machine);
      if (!machine.clearanceVerified) {
        warnings.add(
          LayoutWarning(
            type: LayoutWarningType.missingData,
            title: 'Chưa xác nhận khoảng hở ${machine.model}',
            message: 'Cần nhập khoảng hở theo hồ sơ kỹ thuật hoặc khảo sát.',
            subjectId: machine.id,
          ),
        );
      }
      if (footprint.left < 0 ||
          footprint.top < 0 ||
          footprint.right > project.siteWidthMm ||
          footprint.bottom > project.siteLengthMm) {
        warnings.add(
          LayoutWarning(
            type: LayoutWarningType.outOfBounds,
            title: '${machine.model} nằm ngoài mặt bằng',
            message: 'Một phần thân máy vượt khỏi ranh giới nhà xưởng.',
            subjectId: machine.id,
          ),
        );
      }
      final clearance = worldClearance(machine);
      if (machine.clearanceVerified) {
        _checkBoundaryClearance(
          machine,
          footprint,
          clearance,
          project,
          warnings,
        );
      }

      for (final blocker in blockers) {
        if (footprint.intersects(blocker.rect)) {
          warnings.add(
            LayoutWarning(
              type: LayoutWarningType.physicalOverlap,
              title: '${machine.model} chồng lấn ${blocker.name}',
              message: 'Thân máy đang giao với ${blocker.name}.',
              subjectId: machine.id,
              blockerId: blocker.id,
            ),
          );
        } else if (machine.clearanceVerified) {
          _checkClearanceAgainstRect(
            machine,
            footprint,
            clearance,
            blocker.rect,
            blocker.id,
            blocker.name,
            project.dimensionUnit,
            warnings,
          );
        }
      }

      for (final other in bundle.machines) {
        if (other.id == machine.id) continue;
        final otherRect = machineRect(other);
        if (footprint.intersects(otherRect)) {
          if (machine.id.compareTo(other.id) < 0) {
            warnings.add(
              LayoutWarning(
                type: LayoutWarningType.physicalOverlap,
                title: '${machine.model} chồng lấn ${other.model}',
                message: 'Hai thân máy đang giao nhau.',
                subjectId: machine.id,
                blockerId: other.id,
              ),
            );
          }
        } else if (machine.clearanceVerified) {
          _checkClearanceAgainstRect(
            machine,
            footprint,
            clearance,
            otherRect,
            other.id,
            other.model,
            project.dimensionUnit,
            warnings,
          );
        }
      }

      final limits = [
        project.ceilingHeightMm,
        project.lowestBeamHeightMm,
      ].whereType<double>().toList();
      if (limits.isEmpty) {
        warnings.add(
          LayoutWarning(
            type: LayoutWarningType.missingData,
            title: 'Chưa xác minh chiều cao ${machine.model}',
            message: 'Chưa nhập chiều cao trần hoặc dầm thấp nhất.',
            subjectId: machine.id,
          ),
        );
      } else {
        final limit = limits.reduce(math.min);
        if (machine.requiredHeightMm > limit) {
          warnings.add(
            LayoutWarning(
              type: LayoutWarningType.height,
              title: '${machine.model} không đủ chiều cao',
              message:
                  'Cần ${_dimension(machine.requiredHeightMm, project.dimensionUnit)}, giới hạn ${_dimension(limit, project.dimensionUnit)}.',
              subjectId: machine.id,
              requiredMm: machine.requiredHeightMm,
              actualMm: limit,
            ),
          );
        }
      }
    }
    return warnings;
  }

  static void _checkBoundaryClearance(
    MachinePlacement machine,
    math.Rectangle<double> rect,
    WorldClearance clearance,
    SiteLayoutProject project,
    List<LayoutWarning> warnings,
  ) {
    final checks = <({String side, double required, double actual})>[
      (side: 'trái', required: clearance.left, actual: rect.left),
      (side: 'trên', required: clearance.top, actual: rect.top),
      (
        side: 'phải',
        required: clearance.right,
        actual: project.siteWidthMm - rect.right,
      ),
      (
        side: 'dưới',
        required: clearance.bottom,
        actual: project.siteLengthMm - rect.bottom,
      ),
    ];
    for (final check in checks) {
      if (check.required > 0 && check.actual < check.required) {
        warnings.add(
          LayoutWarning(
            type: LayoutWarningType.clearance,
            title: 'Thiếu khoảng hở ${machine.model}',
            message:
                'Phía ${check.side}: cần ${_dimension(check.required, project.dimensionUnit)}, thực tế ${_dimension(math.max(0, check.actual), project.dimensionUnit)}.',
            subjectId: machine.id,
            blockerId: 'site_boundary',
            requiredMm: check.required,
            actualMm: math.max(0, check.actual),
          ),
        );
      }
    }
  }

  static void _checkClearanceAgainstRect(
    MachinePlacement machine,
    math.Rectangle<double> rect,
    WorldClearance clearance,
    math.Rectangle<double> blocker,
    String blockerId,
    String blockerName,
    SiteDimensionUnit unit,
    List<LayoutWarning> warnings,
  ) {
    final horizontalOverlap =
        rect.left < blocker.right && rect.right > blocker.left;
    final verticalOverlap =
        rect.top < blocker.bottom && rect.bottom > blocker.top;
    final checks =
        <({String side, double required, double actual, bool aligned})>[];
    if (blocker.bottom <= rect.top) {
      checks.add((
        side: 'trước/trên',
        required: clearance.top,
        actual: rect.top - blocker.bottom,
        aligned: horizontalOverlap,
      ));
    }
    if (blocker.top >= rect.bottom) {
      checks.add((
        side: 'sau/dưới',
        required: clearance.bottom,
        actual: blocker.top - rect.bottom,
        aligned: horizontalOverlap,
      ));
    }
    if (blocker.right <= rect.left) {
      checks.add((
        side: 'trái',
        required: clearance.left,
        actual: rect.left - blocker.right,
        aligned: verticalOverlap,
      ));
    }
    if (blocker.left >= rect.right) {
      checks.add((
        side: 'phải',
        required: clearance.right,
        actual: blocker.left - rect.right,
        aligned: verticalOverlap,
      ));
    }
    for (final check in checks) {
      if (check.aligned &&
          check.required > 0 &&
          check.actual < check.required) {
        warnings.add(
          LayoutWarning(
            type: LayoutWarningType.clearance,
            title: 'Thiếu khoảng hở ${machine.model}',
            message:
                'Phía ${check.side} với $blockerName: cần ${_dimension(check.required, unit)}, thực tế ${_dimension(check.actual, unit)}.',
            subjectId: machine.id,
            blockerId: blockerId,
            requiredMm: check.required,
            actualMm: check.actual,
          ),
        );
      }
    }
  }

  static String _dimension(double value, SiteDimensionUnit unit) =>
      unit.format(value);
}

class WorldClearance {
  const WorldClearance({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final double top;
  final double right;
  final double bottom;
  final double left;
}
