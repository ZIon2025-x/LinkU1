import 'package:flutter/services.dart';

import '../../core/utils/logger.dart';

/// 位置选择结果
class LocationPickerResult {
  final String address;
  final double latitude;
  final double longitude;

  const LocationPickerResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory LocationPickerResult.fromMap(Map<dynamic, dynamic> map) {
    return LocationPickerResult(
      address: map['address'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 是否为线上位置
  bool get isOnline => address.toLowerCase() == 'online';

  @override
  String toString() =>
      'LocationPickerResult(address: $address, lat: $latitude, lng: $longitude)';
}

/// 原生地图选点服务
/// iOS 使用 MapKit (Apple Maps)，Android 使用 Google Maps
/// 通过 MethodChannel 与原生端通信
class LocationPickerService {
  LocationPickerService._();
  static final LocationPickerService instance = LocationPickerService._();

  /// MethodChannel 用于调用原生地图选点
  static const _channel = MethodChannel('com.link2ur/location_picker');

  /// 打开原生地图选点页面
  ///
  /// [initialLatitude] 初始纬度（编辑时传入）
  /// [initialLongitude] 初始经度
  /// [initialAddress] 初始地址文本
  ///
  /// 返回 [LocationPickerResult] 或 null（用户取消）
  Future<LocationPickerResult?> openLocationPicker({
    double? initialLatitude,
    double? initialLongitude,
    String? initialAddress,
  }) async {
    try {
      final arguments = <String, dynamic>{};
      if (initialLatitude != null) {
        arguments['initialLatitude'] = initialLatitude;
      }
      if (initialLongitude != null) {
        arguments['initialLongitude'] = initialLongitude;
      }
      if (initialAddress != null && initialAddress.isNotEmpty) {
        arguments['initialAddress'] = initialAddress;
      }

      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'openLocationPicker',
        arguments.isNotEmpty ? arguments : null,
      );

      if (result != null) {
        final pickerResult = LocationPickerResult.fromMap(result);
        AppLogger.info(
          'LocationPicker result: ${pickerResult.address} '
          '(${pickerResult.latitude}, ${pickerResult.longitude})',
        );
        return pickerResult;
      }

      AppLogger.info('LocationPicker cancelled by user');
      return null;
    } on PlatformException catch (e) {
      AppLogger.error('LocationPicker failed: ${e.message}', e);
      return null;
    } catch (e) {
      AppLogger.error('LocationPicker unexpected error', e);
      return null;
    }
  }
}
