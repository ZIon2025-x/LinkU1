import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _phoneCodeController = TextEditingController();

  XFile? _selectedImageFile;
  bool _initialized = false;

  String? _originalEmail;
  String? _originalPhone;

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _residenceCityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _emailCodeController.dispose();
    _phoneCodeController.dispose();
    super.dispose();
  }

  void _initControllers(ProfileState state) {
    if (!_initialized && state.user != null) {
      final user = state.user!;
      _nameController.text = user.name;
      _bioController.text = user.bio ?? '';
      _residenceCityController.text = user.residenceCity ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phone ?? '';
      _originalEmail = user.email ?? '';
      _originalPhone = user.phone ?? '';
      _initialized = true;
    }
  }

  bool get _emailChanged =>
      _emailController.text.trim() != _originalEmail &&
      _emailController.text.trim().isNotEmpty;

  bool get _phoneChanged =>
      _normalizePhone(_phoneController.text.trim()) != _originalPhone &&
      _phoneController.text.trim().isNotEmpty;

  String _normalizePhone(String phone) {
    if (phone.isEmpty) return phone;
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+44')) {
      final local = cleaned.substring(3);
      if (local.startsWith('0')) {
        cleaned = '+44${local.substring(1)}';
      }
    } else if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('0')) {
        cleaned = '+44${cleaned.substring(1)}';
      } else {
        cleaned = '+44$cleaned';
      }
    }
    return cleaned;
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
        AppFeedback.showError(
            context, context.l10n.feedbackPickImageFailed(e.toString()));
      }
    }
  }

  void _sendEmailCode() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppFeedback.showError(context, context.l10n.profileEmailRequired);
      return;
    }
    if (email == _originalEmail) {
      AppFeedback.showError(context, context.l10n.profileEmailUnchanged);
      return;
    }
    context.read<ProfileBloc>().add(ProfileSendEmailCode(email));
  }

  void _sendPhoneCode() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      AppFeedback.showError(context, context.l10n.profilePhoneRequired);
      return;
    }
    final normalized = _normalizePhone(phone);
    if (normalized == _originalPhone) {
      AppFeedback.showError(context, context.l10n.profilePhoneUnchanged);
      return;
    }
    context.read<ProfileBloc>().add(ProfileSendPhoneCode(normalized));
  }

  void _saveProfile() {
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<ProfileBloc>().state;
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
    };

    final bio = _bioController.text.trim();
    if (bio.isNotEmpty) data['bio'] = bio;

    final city = _residenceCityController.text.trim();
    if (city.isNotEmpty) data['residence_city'] = city;

    final email = _emailController.text.trim();
    if (email != _originalEmail) {
      data['email'] = email;
      if (email.isNotEmpty && _emailCodeController.text.trim().isNotEmpty) {
        data['email_verification_code'] = _emailCodeController.text.trim();
      }
    }

    final phone = _phoneController.text.trim();
    final normalizedPhone = phone.isNotEmpty ? _normalizePhone(phone) : '';
    if (normalizedPhone != _originalPhone) {
      data['phone'] = normalizedPhone;
      if (normalizedPhone.isNotEmpty &&
          _phoneCodeController.text.trim().isNotEmpty) {
        data['phone_verification_code'] = _phoneCodeController.text.trim();
      }
    }

    // Validate: if email changed & non-empty, must have code
    if (email != _originalEmail &&
        email.isNotEmpty &&
        state.showEmailCodeField &&
        _emailCodeController.text.trim().isEmpty) {
      AppFeedback.showError(context, context.l10n.profileEmailCodeRequired);
      return;
    }
    if (normalizedPhone != _originalPhone &&
        normalizedPhone.isNotEmpty &&
        state.showPhoneCodeField &&
        _phoneCodeController.text.trim().isEmpty) {
      AppFeedback.showError(context, context.l10n.profilePhoneCodeRequired);
      return;
    }

    context.read<ProfileBloc>().add(ProfileUpdateRequested(data));
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
          final isCodeSent = state.actionMessage == 'email_code_sent' ||
              state.actionMessage == 'phone_code_sent';

          if (isCodeSent) {
            final message = state.actionMessage == 'email_code_sent'
                ? l10n.profileEmailCodeSent
                : l10n.profilePhoneCodeSent;
            AppFeedback.showSuccess(context, message);
          } else if (isSuccess) {
            final message = switch (state.actionMessage) {
              'profile_updated' => l10n.profileUpdated,
              'avatar_updated' => l10n.profileAvatarUpdated,
              _ => state.actionMessage!,
            };
            AppFeedback.showSuccess(context, message);
            if (!state.isUpdating) {
              context.pop();
            }
          } else if (!isCodeSent && !isSuccess) {
            final message = switch (state.actionMessage) {
              'update_failed' => l10n.profileUpdateFailed,
              'upload_failed' => l10n.profileUploadFailed,
              _ => state.actionMessage!,
            };
            AppFeedback.showError(context, message);
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
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

                  // Name
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

                  // Bio
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

                  // City
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

                  // ---- Email Section ----
                  _buildEmailSection(context, state),
                  AppSpacing.vLg,

                  // ---- Phone Section ----
                  _buildPhoneSection(context, state),
                  AppSpacing.vLg,

                  // Save button
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

  Widget _buildEmailSection(BuildContext context, ProfileState state) {
    final l10n = context.l10n;
    final hasExistingEmail =
        _originalEmail != null && _originalEmail!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email input
        TextFormField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: l10n.profileEmail,
            hintText: hasExistingEmail
                ? l10n.profileEnterNewEmail
                : l10n.profileEnterEmail,
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: AppRadius.allMedium),
          ),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
        ),

        // "Send Code" link appears when email differs from original
        if (_emailChanged) ...[
          AppSpacing.vSm,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: (state.isSendingEmailCode || state.emailCountdown > 0)
                  ? null
                  : _sendEmailCode,
              child: state.isSendingEmailCode
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      state.emailCountdown > 0
                          ? l10n.profileCountdownSeconds(state.emailCountdown)
                          : (state.showEmailCodeField
                              ? l10n.profileResendCode
                              : l10n.profileSendCode),
                      style: TextStyle(
                        color: state.emailCountdown > 0
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)
                            : AppColors.primary,
                      ),
                    ),
            ),
          ),
        ],

        // Verification code field
        if (state.showEmailCodeField && _emailChanged) ...[
          AppSpacing.vSm,
          _buildCodeInputRow(
            controller: _emailCodeController,
            hintText: l10n.profileEnterVerificationCode,
          ),
        ],
      ],
    );
  }

  Widget _buildPhoneSection(BuildContext context, ProfileState state) {
    final l10n = context.l10n;
    final hasExistingPhone =
        _originalPhone != null && _originalPhone!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Phone input
        TextFormField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: l10n.profilePhone,
            hintText: hasExistingPhone
                ? l10n.profileEnterNewPhone
                : l10n.profileEnterPhone,
            prefixIcon: const Icon(Icons.phone_outlined),
            helperText: l10n.profileNormalizePhoneHint,
            border: OutlineInputBorder(borderRadius: AppRadius.allMedium),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
        ),

        if (_phoneChanged) ...[
          AppSpacing.vSm,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: (state.isSendingPhoneCode || state.phoneCountdown > 0)
                  ? null
                  : _sendPhoneCode,
              child: state.isSendingPhoneCode
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      state.phoneCountdown > 0
                          ? l10n.profileCountdownSeconds(state.phoneCountdown)
                          : (state.showPhoneCodeField
                              ? l10n.profileResendCode
                              : l10n.profileSendCode),
                      style: TextStyle(
                        color: state.phoneCountdown > 0
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)
                            : AppColors.primary,
                      ),
                    ),
            ),
          ),
        ],

        if (state.showPhoneCodeField && _phoneChanged) ...[
          AppSpacing.vSm,
          _buildCodeInputRow(
            controller: _phoneCodeController,
            hintText: l10n.profileEnterVerificationCode,
          ),
        ],
      ],
    );
  }

  Widget _buildCodeInputRow({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: AppRadius.allMedium),
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildEditAvatar(String? avatarUrl) {
    const double radius = 50;

    if (_selectedImageFile != null) {
      return FutureBuilder<Uint8List>(
        future: _selectedImageFile!.readAsBytes(),
        builder: (context, snapshot) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage:
                snapshot.hasData ? MemoryImage(snapshot.data!) : null,
          );
        },
      );
    }

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
            child:
                const Icon(Icons.person, size: 50, color: AppColors.primary),
          ),
        ),
      );
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return AvatarView(
        imageUrl: avatarUrl,
        size: radius * 2,
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.person, size: 50, color: AppColors.primary),
    );
  }
}
