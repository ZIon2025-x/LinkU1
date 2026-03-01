import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/profile_bloc.dart';

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

  /// 后端存储的预设头像路径（与 AppAssets.avatarPathMap 保持一致）
  static const _avatarOptions = [
    '/static/avatar1.png',
    '/static/avatar2.png',
    '/static/avatar3.png',
    '/static/avatar4.png',
    '/static/avatar5.png',
  ];

  /// 对应的本地 asset（用于离线显示）
  static const _localAssets = [
    AppAssets.avatar1,
    AppAssets.avatar2,
    AppAssets.avatar3,
    AppAssets.avatar4,
    AppAssets.avatar5,
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      ),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state.actionMessage == 'profile_updated' &&
              state.user != null) {
            widget.onSelected(state.user!.avatar ?? '');
            Navigator.of(context).pop();
          } else if (state.actionMessage == 'update_failed' ||
              state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.errorMessage))),
            );
          }
        },
        builder: (context, state) {
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
                        onTap: state.isUpdating
                            ? null
                            : () {
                                setState(() {
                                  _selectedAvatar = _avatarOptions[index];
                                });
                                context.read<ProfileBloc>().add(
                                      ProfileUpdateRequested(
                                          {'avatar': _avatarOptions[index]}),
                                    );
                              },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: isSelected
                                    ? Border.all(
                                        color: AppColors.primary, width: 4)
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
        },
      ),
    );
  }
}
