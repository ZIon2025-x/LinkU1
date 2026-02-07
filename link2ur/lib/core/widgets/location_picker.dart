import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';
import '../utils/permission_manager.dart';

/// 位置输入组件
/// 参考iOS LocationInputField.swift
/// 支持手动输入地址、获取当前位置、选择"线上"
class LocationInputField extends StatefulWidget {
  const LocationInputField({
    super.key,
    this.initialValue,
    this.onChanged,
    this.hintText = '输入地址或选择当前位置',
    this.showOnlineOption = true,
  });

  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final String hintText;
  final bool showOnlineOption;

  @override
  State<LocationInputField> createState() => _LocationInputFieldState();
}

class _LocationInputFieldState extends State<LocationInputField> {
  late TextEditingController _controller;
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final result = await PermissionManager.instance.requestLocation();
      if (!result.granted) {
        if (mounted) {
          PermissionManager.showPermissionDeniedDialog(
            context,
            permissionName: '位置',
            isPermanentlyDenied: result.isPermanentlyDenied,
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        final locationText =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        _controller.text = locationText;
        widget.onChanged?.call(locationText);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取位置失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _selectOnline() {
    _controller.text = 'Online';
    widget.onChanged?.call('Online');
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
              borderSide: BorderSide(color: AppColors.dividerLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(color: AppColors.dividerLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
          onChanged: widget.onChanged,
        ),

        // 快捷选项
        AppSpacing.vSm,
        Row(
          children: [
            if (widget.showOnlineOption)
              _LocationChip(
                icon: Icons.wifi,
                label: '线上',
                onTap: _selectOnline,
              ),
            AppSpacing.hSm,
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
/// 参考iOS TaskLocationDetailView.swift
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
      appBar: AppBar(title: const Text('任务地点')),
      body: Padding(
        padding: AppSpacing.allLg,
        child: Column(
          children: [
            // 地图占位（可后续集成 google_maps_flutter）
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.skeletonBase,
                borderRadius: AppRadius.allMedium,
              ),
              child: const Center(
                child: Icon(Icons.map, size: 64, color: AppColors.textTertiaryLight),
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
                          style: TextStyle(
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
                      '坐标: $latitude, $longitude',
                      style: TextStyle(
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
                    onPressed: () {
                      // 打开 Google Maps
                      _openMaps(context, 'google');
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                  ),
                ),
                AppSpacing.hMd,
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _openMaps(context, 'apple');
                    },
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

  Future<void> _openMaps(BuildContext context, String provider) async {
    // 获取当前位置作为地图中心
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {}

    final lat = position?.latitude ?? 51.5074; // 默认伦敦
    final lng = position?.longitude ?? -0.1278;

    Uri url;
    if (provider == 'google') {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    } else {
      // Apple Maps
      url = Uri.parse(
        'https://maps.apple.com/?ll=$lat,$lng&q=当前位置',
      );
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开${provider == 'google' ? 'Google' : 'Apple'} Maps')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开地图失败: $e')),
        );
      }
    }
  }
}
