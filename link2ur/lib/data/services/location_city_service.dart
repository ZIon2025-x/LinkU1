import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:link2ur/core/utils/logger.dart';
import 'package:link2ur/data/services/storage_service.dart';

/// 全局 GPS 城市检测服务（单例）
///
/// 启动时调用 [resolve] 一次，后续各模块通过 [city] 直接读取缓存值。
/// 优先 GPS 反向编码，fallback 到用户资料 residence_city。
class LocationCityService {
  LocationCityService._();
  static final LocationCityService instance = LocationCityService._();

  String? _city;
  double? _latitude;
  double? _longitude;
  bool _resolved = false;
  Completer<String?>? _resolving;

  /// 当前城市名（可能为 null）
  String? get city => _city;

  /// 当前经纬度（GPS 获取成功时有值）
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  /// 是否已完成过一次解析
  bool get isResolved => _resolved;

  /// 外部模块（如 NearbyTab 的精确定位）已经拿到更准确的城市/坐标时，
  /// 可调用此方法同步更新缓存，避免其他模块重复解析。
  void update({required String city, double? lat, double? lng}) {
    _city = city;
    if (lat != null) _latitude = lat;
    if (lng != null) _longitude = lng;
    _resolved = true;
  }

  /// 解析城市，可在 app 启动或前台恢复时调用。
  /// [forceRefresh] 为 true 时忽略缓存重新获取 GPS。
  /// 并发调用会合并为同一次请求，避免重复 GPS 调用。
  Future<String?> resolve({bool forceRefresh = false}) async {
    if (_resolved && !forceRefresh) return _city;
    // 合并并发调用
    if (_resolving != null) return _resolving!.future;

    _resolving = Completer<String?>();
    try {
      final result = await _doResolve();
      _resolving!.complete(result);
      return result;
    } catch (e) {
      _resolving!.complete(null);
      return null;
    } finally {
      _resolving = null;
    }
  }

  Future<String?> _doResolve() async {
    // 1. 尝试 GPS
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          var position = await Geolocator.getLastKnownPosition();
          position ??= await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 5));

          _latitude = position.latitude;
          _longitude = position.longitude;

          final placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final gpsCity = p.locality ??
                p.subAdministrativeArea ??
                p.administrativeArea;
            if (gpsCity != null && gpsCity.isNotEmpty) {
              _city = gpsCity;
              _resolved = true;
              return _city;
            }
          }
        }
      }
    } catch (e) {
      AppLogger.error('LocationCityService GPS resolve failed', e);
    }

    // 2. Fallback: residence_city
    final userInfo = StorageService.instance.getUserInfo();
    _city = userInfo?['residence_city'] as String?;
    _resolved = true;
    return _city;
  }

  /// 用户登出时清除缓存，下次登录后重新解析
  void clear() {
    _city = null;
    _latitude = null;
    _longitude = null;
    _resolved = false;
    _resolving = null;
  }
}
