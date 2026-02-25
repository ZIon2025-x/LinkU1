import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/services/location_picker_service.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';
import '../utils/l10n_extension.dart';
import '../utils/permission_manager.dart';

/// 位置输入组件
/// 支持手动输入地址、获取当前位置、选择"线上"、地图选点
class LocationInputField extends StatefulWidget {
  const LocationInputField({
    super.key,
    this.initialValue,
    this.initialLatitude,
    this.initialLongitude,
    this.onChanged,
    this.onLocationPicked,
    this.hintText = '输入地址或选择当前位置',
    this.showOnlineOption = true,
  });

  final String? initialValue;
  final double? initialLatitude;
  final double? initialLongitude;
  final ValueChanged<String>? onChanged;

  /// 地图选点回调，返回完整的位置信息（地址、纬度、经度）
  final void Function(String address, double? latitude, double? longitude)?
      onLocationPicked;
  final String hintText;
  final bool showOnlineOption;

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  late TextEditingController _controller;
  bool _isLoadingLocation = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 将 Placemark 格式化为可读地址（街道/区域、城市、省/州、国家）
  static String _formatPlacemarkAddress(Placemark p) {
    final parts = <String>[];
    if (p.street != null && p.street!.isNotEmpty) {
      parts.add(p.street!);
    } else if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
      parts.add(p.thoroughfare!);
    }
    if (p.locality != null && p.locality!.isNotEmpty) {
      parts.add(p.locality!);
    }
    if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
      parts.add(p.administrativeArea!);
    }
    if (p.country != null && p.country!.isNotEmpty) {
      parts.add(p.country!);
    }
    if (parts.isEmpty && p.name != null && p.name!.isNotEmpty) {
      parts.add(p.name!);
    }
    return parts.isNotEmpty ? parts.join(', ') : '';
  }

  /// 逆地理失败时的后备文案（仍显示坐标，但标注为“已获取坐标”）
  static String _fallbackCoordinateText(double lat, double lng) {
    return '已获取坐标 (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // 使用 Geolocator 检查/请求位置权限，与 getCurrentPosition 一致，在 iOS 上比 permission_handler 更准确
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.locationEnableLocationService)),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          PermissionManager.showPermissionDeniedDialog(
            context,
            permissionName: '位置',
            isPermanentlyDenied: permission == LocationPermission.deniedForever,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (!mounted) return;

      // 逆地理编码：坐标 → 可读地址
      String locationText;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final formatted = _formatPlacemarkAddress(placemarks.first);
          locationText = formatted.isNotEmpty
              ? formatted
              : _fallbackCoordinateText(
                  position.latitude,
                  position.longitude,
                );
        } else {
          locationText = _fallbackCoordinateText(
            position.latitude,
            position.longitude,
          );
        }
      } catch (_) {
        locationText = _fallbackCoordinateText(
          position.latitude,
          position.longitude,
        );
      }

      if (mounted) {
        _controller.text = locationText;
        _latitude = position.latitude;
        _longitude = position.longitude;
        widget.onChanged?.call(locationText);
        widget.onLocationPicked
            ?.call(locationText, position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.locationFetchFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _selectOnline() {
    _controller.text = 'Online';
    _latitude = null;
    _longitude = null;
    widget.onChanged?.call('Online');
    widget.onLocationPicked?.call('Online', null, null);
  }

  /// 打开原生地图选点页面
  Future<void> _openMapPicker() async {
    final result = await LocationPickerService.instance.openLocationPicker(
      initialLatitude: _latitude,
      initialLongitude: _longitude,
      initialAddress: _controller.text,
    );

    if (result != null && mounted) {
      setState(() {
        _controller.text = result.address;
        if (result.isOnline) {
          _latitude = null;
          _longitude = null;
        } else {
          _latitude = result.latitude;
          _longitude = result.longitude;
        }
      });
      widget.onChanged?.call(result.address);
      widget.onLocationPicked?.call(
        result.address,
        result.isOnline ? null : result.latitude,
        result.isOnline ? null : result.longitude,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 地址输入框
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon:
                const Icon(Icons.location_on_outlined, color: AppColors.primary),
            suffixIcon: _isLoadingLocation
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.my_location),
                    onPressed: _getCurrentLocation,
                    color: AppColors.primary,
                    tooltip: '获取当前位置',
                  ),
            border: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.dividerLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.dividerLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: (value) {
            // 手动输入时清除坐标
            _latitude = null;
            _longitude = null;
            widget.onChanged?.call(value);
          },
        ),

        // 快捷选项
        AppSpacing.vSm,
        Row(
          children: [
            // 地图选点按钮
            _LocationChip(
              icon: Icons.map_outlined,
              label: '地图选点',
              onTap: _openMapPicker,
            ),
            AppSpacing.hSm,
            if (widget.showOnlineOption) ...[
              _LocationChip(
                icon: Icons.wifi,
                label: '线上',
                onTap: _selectOnline,
              ),
              AppSpacing.hSm,
            ],
            _LocationChip(
              icon: Icons.my_location,
              label: '当前位置',
              onTap: _getCurrentLocation,
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: AppRadius.allPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务位置详情页
/// 显示任务的详细地址信息，支持跳转到地图应用导航
class TaskLocationDetailView extends StatelessWidget {
  const TaskLocationDetailView({
    super.key,
    required this.address,
    this.latitude,
    this.longitude,
    this.taskTitle,
  });

  final String address;
  final double? latitude;
  final double? longitude;
  final String? taskTitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.locationTaskLocation)),
      body: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          children: [
            // 地图预览 — 点击打开原生地图查看
            GestureDetector(
              onTap: () => _openInNativeMap(context),
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: AppRadius.allMedium,
                  border: Border.all(
                    color: AppColors.dividerLight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 48, color: AppColors.primary.withValues(alpha: 0.6)),
                    AppSpacing.vSm,
                    Text(
                      '点击在地图中查看',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AppSpacing.vLg,

            // 地址信息
            Container(
              width: double.infinity,
              padding: AppSpacing.allMd,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: AppRadius.allMedium,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (taskTitle != null) ...[
                    Text(
                      taskTitle!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    AppSpacing.vSm,
                  ],
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          color: AppColors.primary, size: 20),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (latitude != null && longitude != null) ...[
                    AppSpacing.vSm,
                    Text(
                      '坐标: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.vLg,

            // 导航按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMaps(context, 'google'),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMaps(context, 'apple'),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Apple Maps'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 打开原生地图查看位置
  Future<void> _openInNativeMap(BuildContext context) async {
    if (latitude == null || longitude == null) return;

    // 使用 LocationPickerService 打开只读地图
    final result = await LocationPickerService.instance.openLocationPicker(
      initialLatitude: latitude,
      initialLongitude: longitude,
      initialAddress: address,
    );
    // 结果可忽略（只是查看位置）
    if (result != null) {
      // 如果用户选了新位置，不做任何事（这里只是查看）
    }
  }

  Future<void> _openMaps(BuildContext context, String provider) async {
    final lat = latitude ?? 51.5074;
    final lng = longitude ?? -0.1278;

    Uri url;
    if (provider == 'google') {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      url = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=${Uri.encodeComponent(address)}',
      );
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '无法打开${provider == 'google' ? 'Google' : 'Apple'} Maps')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.locationOpenMapFailed}: $e')),
        );
      }
    }
  }
}
