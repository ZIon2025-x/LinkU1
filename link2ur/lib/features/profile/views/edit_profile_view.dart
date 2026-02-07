import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../core/utils/logger.dart';

/// 编辑个人资料页面
class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _residenceCityController = TextEditingController();

  User? _currentUser;
  File? _selectedImageFile;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _residenceCityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userRepo = context.read<UserRepository>();
      final user = await userRepo.getProfile();

      setState(() {
        _currentUser = user;
        _nameController.text = user.name;
        _bioController.text = user.bio ?? '';
        _residenceCityController.text = user.residenceCity ?? '';
        _avatarUrl = user.avatar;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load profile', e);
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载资料失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
          _selectedImageFile = File(pickedFile.path);
        });
        await _uploadAvatar();
      }
    } catch (e) {
      AppLogger.error('Failed to pick image', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadAvatar() async {
    if (_selectedImageFile == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final userRepo = context.read<UserRepository>();
      final updatedUser = await userRepo.uploadAvatar(_selectedImageFile!.path);

      setState(() {
        _avatarUrl = updatedUser.avatar;
        _currentUser = updatedUser;
        _selectedImageFile = null;
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('头像已更新'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to upload avatar', e);
      setState(() {
        _isUploadingAvatar = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('上传头像失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userRepo = context.read<UserRepository>();
      final updatedUser = await userRepo.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        residenceCity: _residenceCityController.text.trim().isEmpty
            ? null
            : _residenceCityController.text.trim(),
      );

      setState(() {
        _currentUser = updatedUser;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('资料已保存'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      AppLogger.error('Failed to save profile', e);
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑资料')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      backgroundImage: _selectedImageFile != null
                          ? FileImage(_selectedImageFile!)
                          : (_avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null),
                      child: _selectedImageFile == null && _avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    if (_isUploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
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
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, size: 18),
                          color: Colors.white,
                          onPressed: _isUploadingAvatar ? null : _pickImage,
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
                  labelText: '姓名',
                  hintText: '请输入姓名',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allMedium,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入姓名';
                  }
                  if (value.trim().length < 3) {
                    return '姓名至少需要3个字符';
                  }
                  return null;
                },
              ),
              AppSpacing.vMd,

              // 个人简介
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: '个人简介',
                  hintText: '介绍一下自己...',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allMedium,
                  ),
                ),
                maxLines: 4,
                maxLength: 200,
              ),
              AppSpacing.vMd,

              // 居住城市
              TextFormField(
                controller: _residenceCityController,
                decoration: InputDecoration(
                  labelText: '居住城市',
                  hintText: '例如：伦敦',
                  prefixIcon: const Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allMedium,
                  ),
                ),
              ),
              AppSpacing.vLg,

              // 保存按钮
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: '保存',
                  onPressed: _isLoading ? null : _saveProfile,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
