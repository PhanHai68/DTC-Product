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
    LocationFailureType.permissionDenied => 'Ứng dụng cần quyền vị trí để lưu tọa độ nhà máy. Vui lòng cho phép khi được hỏi.',
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

  Future<bool> openSettingsFor(LocationFailure failure) =>
      failure.type == LocationFailureType.serviceDisabled
      ? Geolocator.openLocationSettings()
      : Geolocator.openAppSettings();
}
