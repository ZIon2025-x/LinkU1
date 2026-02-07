import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/user_repository.dart';

/// 头像选择页
/// 参考iOS AvatarPickerView.swift
class AvatarPickerView extends StatefulWidget {
  const AvatarPickerView({
    super.key,
    required this.currentAvatar,
    required this.onSelected,
  });

  final String? currentAvatar;
  final ValueChanged<String> onSelected;

  @override
  State<AvatarPickerView> createState() => _AvatarPickerViewState();
}

class _AvatarPickerViewState extends State<AvatarPickerView> {
  String? _selectedAvatar;
  bool _isLoading = false;

  static const _avatarOptions = [
    '/static/avatar1.png',
    '/static/avatar2.png',
    '/static/avatar3.png',
    '/static/avatar4.png',
  ];

  static const _localAssets = [
    AppAssets.avatar1,
    AppAssets.avatar2,
    AppAssets.avatar3,
    AppAssets.avatar4,
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
  }

  Future<void> _selectAvatar(int index) async {
    final avatarPath = _avatarOptions[index];

    setState(() {
      _selectedAvatar = avatarPath;
      _isLoading = true;
    });

    try {
      final repo = context.read<UserRepository>();
      await repo.updateAvatar(avatarPath);
      widget.onSelected(avatarPath);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSelectAvatar),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.profileSelectAvatar,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.lg,
                mainAxisSpacing: AppSpacing.lg,
              ),
              itemCount: _avatarOptions.length,
              itemBuilder: (context, index) {
                final isSelected =
                    _selectedAvatar == _avatarOptions[index] ||
                        widget.currentAvatar == _avatarOptions[index];

                return GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => _selectAvatar(index),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 外圈
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: isSelected
                              ? Border.all(
                                  color: AppColors.primary,
                                  width: 4)
                              : null,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            _localAssets[index],
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person, size: 44),
                          ),
                        ),
                      ),

                      // 选中标记
                      if (isSelected)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
