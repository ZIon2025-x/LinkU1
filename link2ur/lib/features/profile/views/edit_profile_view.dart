import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../core/utils/logger.dart';
import '../bloc/profile_bloc.dart';

/// 编辑个人资料页面
class EditProfileView extends StatelessWidget {
  const EditProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(const ProfileLoadRequested()),
      child: const _EditProfileContent(),
    );
  }
}

class _EditProfileContent extends StatefulWidget {
  const _EditProfileContent();

  @override
  State<_EditProfileContent> createState() => _EditProfileContentState();
}

class _EditProfileContentState extends State<_EditProfileContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _residenceCityController = TextEditingController();

  XFile? _selectedImageFile;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _residenceCityController.dispose();
    super.dispose();
  }

  void _initControllers(ProfileState state) {
    if (!_initialized && state.user != null) {
      final user = state.user!;
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
      _residenceCityController.text = user.residenceCity ?? '';
      _initialized = true;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = pickedFile;
        });
        if (mounted) {
          context.read<ProfileBloc>().add(
                ProfileUploadAvatar(pickedFile.path),
              );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to pick image', e);
      if (mounted) {
        AppFeedback.showError(context, context.l10n.feedbackPickImageFailed(e.toString()));
      }
    }
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ProfileBloc>().add(ProfileUpdateRequested({
          'name': _nameController.text.trim(),
          if (_bioController.text.trim().isNotEmpty)
            'bio': _bioController.text.trim(),
          if (_residenceCityController.text.trim().isNotEmpty)
            'residence_city': _residenceCityController.text.trim(),
        }));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileBloc, ProfileState>(
      listener: (context, state) {
        _initControllers(state);

        if (state.actionMessage != null) {
          final l10n = context.l10n;
          final isSuccess = state.actionMessage == 'profile_updated' ||
              state.actionMessage == 'avatar_updated';
          final message = switch (state.actionMessage) {
            'profile_updated' => l10n.profileUpdated,
            'update_failed' => l10n.profileUpdateFailed,
            'avatar_updated' => l10n.profileAvatarUpdated,
            'upload_failed' => l10n.profileUploadFailed,
            _ => state.actionMessage!,
          };
          if (isSuccess) {
            AppFeedback.showSuccess(context, message);
          } else {
            AppFeedback.showError(context, message);
          }
          if (isSuccess && !state.isUpdating) {
            context.pop();
          }
        }
      },
      builder: (context, state) {
        if (state.isLoading && state.user == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.profileEditProfile)),
            body: const LoadingView(),
          );
        }

        final avatarUrl = state.user?.avatar;

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.profileEditProfile),
            actions: [
              TextButton(
                onPressed: state.isUpdating ? null : _saveProfile,
                child: state.isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.commonSave),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: AppSpacing.allMd,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // 头像
                  Center(
                    child: Stack(
                      children: [
                        _buildEditAvatar(avatarUrl),
                        if (state.isUpdating && _selectedImageFile != null)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, size: 18),
                              color: Colors.white,
                              onPressed:
                                  state.isUpdating ? null : _pickImage,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vLg,

                  // 姓名
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.profileName,
                      hintText: context.l10n.profileEnterName,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.allMedium),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.profileNameRequired;
                      }
                      if (value.trim().length < 3) {
                        return context.l10n.profileNameMinLength;
                      }
                      return null;
                    },
                  ),
                  AppSpacing.vMd,

                  // 个人简介
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: context.l10n.profileBio,
                      hintText: context.l10n.profileBioHint,
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.allMedium),
                    ),
                    maxLines: 4,
                    maxLength: 200,
                  ),
                  AppSpacing.vMd,

                  // 居住城市
                  TextFormField(
                    controller: _residenceCityController,
                    decoration: InputDecoration(
                      labelText: context.l10n.profileCity,
                      hintText: context.l10n.profileCityHint,
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      border: OutlineInputBorder(
                          borderRadius: AppRadius.allMedium),
                    ),
                  ),
                  AppSpacing.vLg,

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      text: context.l10n.commonSave,
                      onPressed: state.isUpdating ? null : _saveProfile,
                      isLoading: state.isUpdating,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 编辑页头像：支持本地文件、预设头像（本地asset）、网络URL
  Widget _buildEditAvatar(String? avatarUrl) {
    const double radius = 50;

    // 1. 用户刚选了本地图片文件
    if (_selectedImageFile != null) {
      return FutureBuilder<Uint8List>(
        future: _selectedImageFile!.readAsBytes(),
        builder: (context, snapshot) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: snapshot.hasData ? MemoryImage(snapshot.data!) : null,
          );
        },
      );
    }

    // 2. 预设头像 → 本地 asset
    final localAsset = AppAssets.getLocalAvatarAsset(avatarUrl);
    if (localAsset != null) {
      return ClipOval(
        child: Image.asset(
          localAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, size: 50, color: AppColors.primary),
          ),
        ),
      );
    }

    // 3. 网络 URL → 使用 AvatarView（带 memCacheWidth/Height 优化）
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return AvatarView(
        imageUrl: avatarUrl,
        size: radius * 2,
      );
    }

    // 4. 无头像
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.person, size: 50, color: AppColors.primary),
    );
  }
}
