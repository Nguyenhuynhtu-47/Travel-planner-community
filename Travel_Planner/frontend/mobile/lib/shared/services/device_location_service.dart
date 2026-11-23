import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class DeviceLocationException implements Exception {
  final String message;
  final bool canOpenAppSettings;
  final bool canOpenLocationSettings;

  const DeviceLocationException(
    this.message, {
    this.canOpenAppSettings = false,
    this.canOpenLocationSettings = false,
  });

  @override
  String toString() => message;
}

/// Reads the device's foreground location for one-shot navigation requests.
class DeviceLocationService {
  const DeviceLocationService();

  Future<LatLng> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'Hãy bật dịch vụ vị trí để bắt đầu chỉ đường.',
        canOpenLocationSettings: true,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'Ứng dụng cần quyền vị trí để chỉ đường từ vị trí hiện tại.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy bật quyền trong Cài đặt.',
        canOpenAppSettings: true,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        throw const DeviceLocationException(
          'Không nhận được tọa độ vị trí hợp lệ.',
        );
      }
      return LatLng(position.latitude, position.longitude);
    } on TimeoutException {
      throw const DeviceLocationException(
        'Không thể xác định vị trí hiện tại. Vui lòng thử lại.',
      );
    } catch (error) {
      if (error is DeviceLocationException) rethrow;
      throw const DeviceLocationException(
        'Không thể lấy vị trí hiện tại. Hãy kiểm tra GPS và thử lại.',
      );
    }
  }
}
