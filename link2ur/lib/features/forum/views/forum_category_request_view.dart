import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/forum_repository.dart';

/// 申请新建论坛版块页面
/// 参考 iOS ForumCategoryRequestView
class ForumCategoryRequestView extends StatefulWidget {
  const ForumCategoryRequestView({super.key});

  @override
  State<ForumCategoryRequestView> createState() =>
      _ForumCategoryRequestViewState();
}

class _ForumCategoryRequestViewState extends State<ForumCategoryRequestView> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _iconController = TextEditingController();
  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _iconFocus = FocusNode();

  bool _isLoading = false;
  bool _hasSubmitted = false;
  String? _errorMessage;

  // 字符限制 (与 iOS 对齐)
  static const _maxNameLength = 100;
  static const _maxDescriptionLength = 500;
  static const _maxIconLength = 1;

  bool get _isNameValid =>
      _nameController.text.trim().isNotEmpty;

  bool get _canSubmit =>
      _isNameValid &&
      _descriptionController.text.length <= _maxDescriptionLength &&
      _iconController.text.length <= _maxIconLength &&
      !_isLoading &&
      !_hasSubmitted;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    _iconController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _iconController.removeListener(_onTextChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _iconFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      setState(() => _errorMessage = context.l10n.forumRequestNameRequired);
      return;
    }
    if (trimmedName.length > _maxNameLength) {
      setState(() =>
          _errorMessage = context.l10n.forumRequestNameTooLong(_maxNameLength));
      return;
    }
    if (_descriptionController.text.length > _maxDescriptionLength) {
      setState(() => _errorMessage =
          context.l10n.forumRequestDescriptionTooLong(_maxDescriptionLength));
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSubmitted = true;
      _errorMessage = null;
    });

    try {
      await context.read<ForumRepository>().requestCategory(
            name: trimmedName,
            description: _descriptionController.text.trim(),
          );

      if (!mounted) return;

      // 显示成功对话框
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.forumRequestSubmitted),
          content: Text(context.l10n.forumRequestSubmittedMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasSubmitted = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.forumRequestNewCategory),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 说明卡片
              _buildInstructionCard(isDark, l10n),
              const SizedBox(height: AppSpacing.lg),

              // 版块名称
              _buildNameField(isDark, l10n),
              const SizedBox(height: AppSpacing.lg),

              // 版块描述
              _buildDescriptionField(isDark, l10n),
              const SizedBox(height: AppSpacing.lg),

              // 版块图标
              _buildIconField(isDark, l10n),
              const SizedBox(height: AppSpacing.xl),

              // 错误提示
              if (_errorMessage != null) ...[
                _buildErrorBanner(isDark),
                const SizedBox(height: AppSpacing.md),
              ],

              // 提交按钮
              _buildSubmitButton(l10n),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionCard(bool isDark, dynamic l10n) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.forumRequestInstructions,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.forumRequestInstructionsText,
            style: AppTypography.subheadline.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(bool isDark, dynamic l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.forumCategoryName,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          focusNode: _nameFocus,
          maxLength: _maxNameLength,
          decoration: InputDecoration(
            hintText: l10n.forumCategoryNamePlaceholder,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
          onSubmitted: (_) => _descriptionFocus.requestFocus(),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_nameController.text.length}/$_maxNameLength',
            style: AppTypography.caption.copyWith(
              color: _nameController.text.length > _maxNameLength
                  ? AppColors.error
                  : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionField(bool isDark, dynamic l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forumCategoryDescription,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          focusNode: _descriptionFocus,
          maxLines: 4,
          maxLength: _maxDescriptionLength,
          decoration: InputDecoration(
            hintText: l10n.forumCategoryDescriptionPlaceholder,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_descriptionController.text.length}/$_maxDescriptionLength',
            style: AppTypography.caption.copyWith(
              color: _descriptionController.text.length > _maxDescriptionLength
                  ? AppColors.error
                  : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconField(bool isDark, dynamic l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.forumCategoryIcon,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.forumCategoryIconHint,
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _iconController,
          focusNode: _iconFocus,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24),
          inputFormatters: [
            LengthLimitingTextInputFormatter(_maxIconLength),
          ],
          decoration: InputDecoration(
            hintText: l10n.forumCategoryIconExample,
            hintStyle: const TextStyle(fontSize: 24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
        if (_iconController.text.isNotEmpty) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.forumCategoryIconEntered,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTypography.caption.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(dynamic l10n) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.large),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Text(
                l10n.forumSubmitRequest,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
