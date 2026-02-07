import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'logger.dart';

/// 权限管理器
/// 参考iOS PermissionManager.swift
/// 统一管理应用所需的各项权限
class PermissionManager {
  PermissionManager._();

  static final PermissionManager instance = PermissionManager._();

  /// 请求相机权限
  Future<PermissionResult> requestCamera() async {
    return _requestPermission(Permission.camera, '相机');
  }

  /// 请求相册权限
  Future<PermissionResult> requestPhotos() async {
    return _requestPermission(Permission.photos, '相册');
  }

  /// 请求位置权限
  Future<PermissionResult> requestLocation() async {
    return _requestPermission(Permission.locationWhenInUse, '位置');
  }

  /// 请求通知权限
  Future<PermissionResult> requestNotification() async {
    return _requestPermission(Permission.notification, '通知');
  }

  /// 请求麦克风权限
  Future<PermissionResult> requestMicrophone() async {
    return _requestPermission(Permission.microphone, '麦克风');
  }

  /// 请求存储权限
  Future<PermissionResult> requestStorage() async {
    return _requestPermission(Permission.storage, '存储');
  }

  /// 检查权限状态
  Future<bool> isGranted(Permission permission) async {
    final status = await permission.status;
    return status.isGranted;
  }

  /// 检查相机权限
  Future<bool> get isCameraGranted => isGranted(Permission.camera);

  /// 检查相册权限
  Future<bool> get isPhotosGranted => isGranted(Permission.photos);

  /// 检查位置权限
  Future<bool> get isLocationGranted =>
      isGranted(Permission.locationWhenInUse);

  /// 检查通知权限
  Future<bool> get isNotificationGranted => isGranted(Permission.notification);

  /// 通用权限请求
  Future<PermissionResult> _requestPermission(
    Permission permission,
    String permissionName,
  ) async {
    try {
      final status = await permission.status;

      if (status.isGranted) {
        return PermissionResult(
          granted: true,
          permissionName: permissionName,
        );
      }

      if (status.isPermanentlyDenied) {
        return PermissionResult(
          granted: false,
          permissionName: permissionName,
          isPermanentlyDenied: true,
          message: '请在系统设置中开启$permissionName权限',
        );
      }

      final result = await permission.request();

      return PermissionResult(
        granted: result.isGranted,
        permissionName: permissionName,
        isPermanentlyDenied: result.isPermanentlyDenied,
        message: result.isGranted ? null : '$permissionName权限被拒绝',
      );
    } catch (e) {
      AppLogger.error('Permission - Request $permissionName failed', e);
      return PermissionResult(
        granted: false,
        permissionName: permissionName,
        message: '请求$permissionName权限出错',
      );
    }
  }

  /// 显示权限被拒绝的提示弹窗
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required String permissionName,
    bool isPermanentlyDenied = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('需要$permissionName权限'),
        content: Text(
          isPermanentlyDenied
              ? '请在系统设置中开启$permissionName权限后重试'
              : '此功能需要$permissionName权限才能正常使用',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (isPermanentlyDenied)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('去设置'),
            ),
        ],
      ),
    );
  }

  /// 请求多个权限
  Future<Map<Permission, PermissionStatus>> requestMultiple(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }
}

/// 权限请求结果
class PermissionResult {
  const PermissionResult({
    required this.granted,
    required this.permissionName,
    this.isPermanentlyDenied = false,
    this.message,
  });

  final bool granted;
  final String permissionName;
  final bool isPermanentlyDenied;
  final String? message;
}
