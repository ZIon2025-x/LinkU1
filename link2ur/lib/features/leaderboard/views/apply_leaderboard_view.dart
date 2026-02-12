import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 申请创建排行榜页
/// 参考iOS ApplyLeaderboardView.swift
class ApplyLeaderboardView extends StatefulWidget {
  const ApplyLeaderboardView({super.key});

  @override
  State<ApplyLeaderboardView> createState() => _ApplyLeaderboardViewState();
}

class _ApplyLeaderboardViewState extends State<ApplyLeaderboardView> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rulesController = TextEditingController();
  final _imagePicker = ImagePicker();
  XFile? _coverImage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    AppHaptics.selection();
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _coverImage = picked);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  void _removeCoverImage() {
    AppHaptics.light();
    setState(() => _coverImage = null);
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      AppFeedback.showWarning(context, context.l10n.leaderboardFillRequired);
      return;
    }

    AppHaptics.medium();
    context.read<LeaderboardBloc>().add(
          LeaderboardApplyRequested(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            rules: _rulesController.text.trim().isEmpty
                ? null
                : _rulesController.text.trim(),
            coverImagePath: _coverImage?.path,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      ),
      child: BlocConsumer<LeaderboardBloc, LeaderboardState>(
        listener: (context, state) {
          if (state.actionMessage != null) {
            if (state.actionMessage == 'leaderboard_applied') {
              AppFeedback.showSuccess(context, l10n.leaderboardApplySuccess);
              Navigator.of(context).pop();
            } else if (state.actionMessage == 'application_failed') {
              final msg = state.errorMessage != null
                  ? '${l10n.actionApplicationFailed}: ${state.errorMessage}'
                  : l10n.actionApplicationFailed;
              AppFeedback.showError(context, msg);
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.leaderboardApply)),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 封面图片（可选） ──
                  _buildCoverImagePicker(isDark),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 标题 * ──
                  _buildField(
                    label: l10n.leaderboardTitle,
                    controller: _titleController,
                    hint: l10n.leaderboardTitleHint,
                    icon: Icons.title_rounded,
                    isRequired: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 描述 * ──
                  _buildField(
                    label: l10n.leaderboardDescription,
                    controller: _descriptionController,
                    hint: l10n.leaderboardDescriptionHint,
                    icon: Icons.description_outlined,
                    maxLines: 4,
                    isRequired: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 排行榜规则 ──
                  _buildField(
                    label: l10n.leaderboardRules,
                    controller: _rulesController,
                    hint: l10n.leaderboardRulesHint,
                    icon: Icons.rule_rounded,
                    maxLines: 5,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── 提交 ──
                  PrimaryButton(
                    text: l10n.leaderboardSubmitApply,
                    onPressed: state.isSubmitting ? null : _submit,
                    isLoading: state.isSubmitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== 封面图片选择器 ====================
  Widget _buildCoverImagePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.leaderboardCoverImage,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Text(
              '(${context.l10n.leaderboardOptional})',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_coverImage != null)
          // 已选图片预览
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                child: CrossPlatformImage(
                  xFile: _coverImage!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _removeCoverImage,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              // 重新选择按钮
              Positioned(
                bottom: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _pickCoverImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.leaderboardChangeImage,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          // 空白选择区域
          GestureDetector(
            onTap: _pickCoverImage,
            child: Container(
              width: double.infinity,
              height: 140,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppColors.separatorLight.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.leaderboardAddCoverImage,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ==================== 表单字段 ====================
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    bool isRequired = false,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (isRequired)
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
