import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

enum LocationFailureType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationFailure implements Exception {
  const LocationFailure(this.type);
  final LocationFailureType type;

  String get message => switch (type) {
    LocationFailureType.serviceDisabled => 'Dịch vụ vị trí (GPS) đang tắt. Vui lòng bật vị trí trên thiết bị rồi thử lại.',
    LocationFailureType.permissionDenied => 'Ứng dụng cần quyền vị trí để lưu tọa độ địa điểm. Vui lòng cho phép khi được hỏi.',
    LocationFailureType.permissionDeniedForever =>
      kIsWeb
          ? 'Trình duyệt đang chặn quyền vị trí. Hãy cho phép vị trí cho trang này trong cài đặt trình duyệt rồi thử lại.'
          : 'Quyền vị trí đã bị từ chối. Hãy mở Cài đặt và cấp quyền vị trí cho ứng dụng để sử dụng chức năng định vị.',
    LocationFailureType.timeout => 'Hết thời gian chờ lấy vị trí. Hãy ra khu vực thoáng (gần cửa hoặc ngoài trời) rồi thử lại.',
    LocationFailureType.unknown =>
      'Không lấy được vị trí hiện tại. Vui lòng thử lại.',
  };

  bool get canOpenSettings =>
      !kIsWeb &&
      (type == LocationFailureType.serviceDisabled ||
          type == LocationFailureType.permissionDeniedForever);

  @override
  String toString() => message;
}

class LocationService {
  const LocationService();

  static const timeout = Duration(seconds: 30);

  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationFailureType.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureType.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationFailure(LocationFailureType.permissionDenied);
    }

    await _requestFullAccuracyOnIos();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeout,
        ),
      );
    } on TimeoutException {
      throw const LocationFailure(LocationFailureType.timeout);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureType.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationFailureType.permissionDenied);
    } catch (error, stackTrace) {
      debugPrint('LocationService.getCurrentPosition: $error\n$stackTrace');
      throw const LocationFailure(LocationFailureType.unknown);
    }
  }

  /// iOS 14+: người dùng tắt "Vị trí chính xác" thì xin bật tạm thời cho lần
  /// định vị này (khóa `FactoryLocation` trong Info.plist).
  Future<void> _requestFullAccuracyOnIos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      if (await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(
          purposeKey: 'FactoryLocation',
        );
      }
    } catch (error) {
      debugPrint('LocationService._requestFullAccuracyOnIos: $error');
    }
  }

  /// Người dùng chỉ cấp "vị trí gần đúng" (Android 12+ hoặc iOS 14+ tắt Vị
  /// trí chính xác): sai số 1–3 km, định vị lại cũng không cải thiện.
  Future<bool> isApproximate() async {
    if (kIsWeb) return false;
    try {
      return await Geolocator.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced;
    } catch (error) {
      debugPrint('LocationService.isApproximate: $error');
      return false;
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openSettingsFor(LocationFailure failure) =>
      failure.type == LocationFailureType.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
