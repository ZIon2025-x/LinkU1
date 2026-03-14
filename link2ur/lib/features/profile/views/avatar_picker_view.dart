import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/profile_bloc.dart';

/// 头像选择页
/// 支持预设头像 + 从相册/相机上传自定义头像
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
  Uint8List? _customAvatarBytes;
  final _imagePicker = ImagePicker();

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

  Future<void> _pickFromGallery(BuildContext blocContext) async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    if (!blocContext.mounted) return;
    await _cropAndUpload(file, blocContext);
  }

  Future<void> _pickFromCamera(BuildContext blocContext) async {
    final file = await _imagePicker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    if (!blocContext.mounted) return;
    await _cropAndUpload(file, blocContext);
  }

  Future<void> _cropAndUpload(XFile file, BuildContext blocContext) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: context.l10n.profileSelectAvatar,
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: context.l10n.profileSelectAvatar,
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (croppedFile == null) return;
    final bytes = await croppedFile.readAsBytes();
    setState(() {
      _customAvatarBytes = bytes;
      _selectedAvatar = null;
    });
    if (!blocContext.mounted) return;
    blocContext.read<ProfileBloc>().add(
      ProfileUploadAvatar(bytes, croppedFile.path.split('/').last),
    );
  }

  void _showImageSourceSheet(BuildContext blocContext) {
    final l10n = context.l10n;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profileAvatarFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery(blocContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.profileAvatarFromCamera),
              onTap: () {
                Navigator.pop(context);
                _pickFromCamera(blocContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(l10n.commonCancel),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      ),
      child: BlocConsumer<ProfileBloc, ProfileState>(
        listener: (context, state) {
          if (state.actionMessage == 'avatar_updated' &&
              state.user != null) {
            widget.onSelected(state.user!.avatar ?? '');
            Navigator.of(context).pop();
          } else if (state.actionMessage == 'update_failed' ||
              state.actionMessage == 'upload_failed') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.errorMessage))),
            );
            // 上传失败时清除预览
            setState(() => _customAvatarBytes = null);
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
                const SizedBox(height: AppSpacing.lg),
                // 自定义上传入口
                GestureDetector(
                  onTap: state.isUpdating
                      ? null
                      : () => _showImageSourceSheet(context),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.secondaryBackgroundDark
                                  : const Color(0xFFF3F4F6),
                              border: _customAvatarBytes != null
                                  ? Border.all(
                                      color: AppColors.primary, width: 4)
                                  : null,
                            ),
                            child: _customAvatarBytes != null
                                ? ClipOval(
                                    child: Image.memory(
                                      _customAvatarBytes!,
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : _selectedAvatar != null &&
                                        !_avatarOptions.contains(_selectedAvatar)
                                    ? AvatarView(
                                        imageUrl: _selectedAvatar,
                                        size: 100,
                                      )
                                    : Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 36,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                      ),
                          ),
                          if (state.isUpdating && _customAvatarBytes != null)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.4),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.profileAvatarUploadCustom,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.secondaryBackgroundDark
                      : const Color(0xFFE5E7EB),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.profileAvatarPresets,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
                // 预设头像网格
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                    ),
                    itemCount: _avatarOptions.length,
                    itemBuilder: (context, index) {
                      final isSelected =
                          _selectedAvatar == _avatarOptions[index] &&
                          _customAvatarBytes == null;

                      return Semantics(
                        button: true,
                        label: 'Select avatar',
                        child: GestureDetector(
                          onTap: state.isUpdating
                              ? null
                              : () {
                                  setState(() {
                                    _selectedAvatar = _avatarOptions[index];
                                    _customAvatarBytes = null;
                                  });
                                  context.read<ProfileBloc>().add(
                                        ProfileUpdateAvatar(
                                            _avatarOptions[index]),
                                      );
                                },
                          child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
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
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.person, size: 36),
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
                                      color: Colors.white, size: 14),
                                ),
                              ),
                          ],
                        ),
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
