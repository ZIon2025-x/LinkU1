import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 提交排行榜条目页 — 对齐 iOS SubmitLeaderboardItemView.swift
class SubmitLeaderboardItemView extends StatelessWidget {
  const SubmitLeaderboardItemView({
    super.key,
    required this.leaderboardId,
  });

  final int leaderboardId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      ),
      child: _SubmitLeaderboardItemContent(leaderboardId: leaderboardId),
    );
  }
}

class _SubmitLeaderboardItemContent extends StatefulWidget {
  const _SubmitLeaderboardItemContent({required this.leaderboardId});

  final int leaderboardId;

  @override
  State<_SubmitLeaderboardItemContent> createState() =>
      _SubmitLeaderboardItemContentState();
}

class _SubmitLeaderboardItemContentState
    extends State<_SubmitLeaderboardItemContent> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final List<XFile> _selectedImages = [];
  String? _localError;

  static const int _maxImages = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _selectedImages.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (images.isNotEmpty && mounted) {
      setState(() {
        for (final img in images) {
          if (_selectedImages.length < _maxImages) {
            _selectedImages.add(img);
          }
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _localError = context.l10n.leaderboardFillRequired);
      return;
    }

    setState(() => _localError = null);

    final desc = _descriptionController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final website = _websiteController.text.trim();

    context.read<LeaderboardBloc>().add(LeaderboardSubmitItem(
          leaderboardId: widget.leaderboardId,
          name: name,
          description: desc.isNotEmpty ? desc : null,
          address: address.isNotEmpty ? address : null,
          phone: phone.isNotEmpty ? phone : null,
          website: website.isNotEmpty ? website : null,
          imagePaths: _selectedImages.isNotEmpty
              ? _selectedImages.map((e) => e.path).toList()
              : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<LeaderboardBloc, LeaderboardState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage ||
          prev.isSubmitting != curr.isSubmitting,
      listener: (context, state) {
        if (state.actionMessage != null && !state.isSubmitting) {
          if (state.actionMessage == 'leaderboard_submitted') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.leaderboardSubmitSuccess)),
            );
            Navigator.of(context).pop(true);
          } else if (state.actionMessage == 'submit_failed') {
            final msg = state.errorMessage != null
                ? '${l10n.actionSubmitFailed}: ${state.errorMessage}'
                : l10n.actionSubmitFailed;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(msg),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
      child: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          final errorMsg = _localError ?? state.errorMessage;

          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.leaderboardSubmitItem),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 基本信息
                  _SectionCard(
                    isDark: isDark,
                    icon: Icons.store_outlined,
                    title: l10n.leaderboardBasicInfo,
                    children: [
                      _buildField(
                        label: l10n.leaderboardItemName,
                        controller: _nameController,
                        isRequired: true,
                        hintText: l10n.leaderboardNamePlaceholder,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildField(
                        label: l10n.leaderboardItemDescription,
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: 500,
                        hintText: l10n.leaderboardDescriptionPlaceholder,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 2. 联系方式
                  _SectionCard(
                    isDark: isDark,
                    icon: Icons.info_outline,
                    title: l10n.leaderboardContactInfo,
                    children: [
                      _buildField(
                        label: l10n.leaderboardItemAddress,
                        controller: _addressController,
                        hintText: l10n.leaderboardAddressPlaceholder,
                        prefixIcon: Icons.location_on_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildField(
                        label: l10n.leaderboardItemPhone,
                        controller: _phoneController,
                        hintText: l10n.leaderboardPhonePlaceholder,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        isDark: isDark,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildField(
                        label: l10n.leaderboardItemWebsite,
                        controller: _websiteController,
                        hintText: l10n.leaderboardWebsitePlaceholder,
                        prefixIcon: Icons.language,
                        keyboardType: TextInputType.url,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. 图片展示
                  _SectionCard(
                    isDark: isDark,
                    icon: Icons.photo_library_outlined,
                    title: l10n.leaderboardAddImage,
                    trailing: Text(
                      '${_selectedImages.length}/$_maxImages',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      SizedBox(
                        height: 100,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            if (_selectedImages.length < _maxImages)
                              GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : AppColors.backgroundLight,
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.medium),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3),
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined,
                                          size: 28, color: AppColors.primary),
                                      const SizedBox(height: 4),
                                      Text(
                                        l10n.leaderboardAddImage,
                                        style: AppTypography.caption.copyWith(
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ..._selectedImages.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final img = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.medium),
                                      child: Image.file(
                                        File(img.path),
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _removeImage(idx),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.close,
                                              size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 错误提示
                  if (errorMsg != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: AppColors.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(errorMsg,
                                style: AppTypography.caption.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),

                  // 提交按钮
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : _nameController.text.trim().isEmpty
                              ? null
                              : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: state.isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(l10n.leaderboardSubmitting,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.verified_outlined, size: 20),
                                const SizedBox(width: 8),
                                Text(l10n.leaderboardSubmit,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                )),
            if (isRequired)
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: (_) {
            if (_localError != null) setState(() => _localError = null);
          },
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 20)
                : null,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.isDark,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
  });

  final bool isDark;
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
