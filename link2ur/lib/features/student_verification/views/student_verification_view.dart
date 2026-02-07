import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/student_verification_repository.dart';
import '../../../data/models/student_verification.dart';

/// 学生认证视图
/// 参考iOS StudentVerificationView.swift
class StudentVerificationView extends StatefulWidget {
  const StudentVerificationView({super.key});

  @override
  State<StudentVerificationView> createState() =>
      _StudentVerificationViewState();
}

class _StudentVerificationViewState extends State<StudentVerificationView> {
  StudentVerification? _verification;
  List<University> _universities = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Form fields
  University? _selectedUniversity;
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<StudentVerificationRepository>();

      // Load verification status and universities in parallel
      final results = await Future.wait([
        repository.getVerificationStatus(),
        repository.getUniversities(),
      ]);

      setState(() {
        _verification = results[0] as StudentVerification;
        _universities = results[1] as List<University>;
        _isLoading = false;

        // Pre-fill form if email is locked
        if (_verification!.emailLocked && _verification!.email != null) {
          _emailController.text = _verification!.email!;
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitVerification() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUniversity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择大学'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<StudentVerificationRepository>();
      await repository.submitVerification(
        SubmitStudentVerificationRequest(
          universityId: _selectedUniversity!.id,
          email: _emailController.text.trim(),
        ),
      );

      setState(() {
        _isSubmitting = false;
      });

      // Reload data to get updated status
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('提交成功，请查收邮箱验证'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('提交失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studentVerificationVerification),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingView();
    }

    if (_errorMessage != null && _verification == null) {
      return ErrorStateView.loadFailed(
        message: _errorMessage!,
        onRetry: _loadData,
      );
    }

    if (_verification == null) {
      return ErrorStateView.notFound();
    }

    final verification = _verification!;

    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 认证状态卡片
          _buildStatusCard(verification),
          AppSpacing.vLg,

          // 如果未认证或可以重新提交，显示表单
          if (!verification.isVerified || verification.canRenew)
            _buildVerificationForm(verification),
        ],
      ),
    );
  }

  Widget _buildStatusCard(StudentVerification verification) {
    return Container(
      padding: AppSpacing.allLg,
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
          Row(
            children: [
              Icon(
                verification.isVerified
                    ? Icons.verified
                    : verification.isPending
                        ? Icons.pending
                        : Icons.info_outline,
                color: verification.isVerified
                    ? AppColors.success
                    : verification.isPending
                        ? AppColors.warning
                        : AppColors.textSecondaryLight,
                size: 32,
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verification.statusText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (verification.university != null) ...[
                      AppSpacing.vSm,
                      Text(
                        verification.university!.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                    if (verification.email != null) ...[
                      AppSpacing.vSm,
                      Text(
                        verification.email!,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (verification.isVerified && verification.daysRemaining != null) ...[
            AppSpacing.vMd,
            Divider(color: AppColors.dividerLight),
            AppSpacing.vMd,
            Row(
              children: [
                Icon(
                  Icons.access_time_outlined,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
                AppSpacing.hSm,
                Text(
                  verification.daysRemaining! > 0
                      ? '剩余 ${verification.daysRemaining} 天'
                      : '已过期',
                  style: TextStyle(
                    fontSize: 14,
                    color: verification.isExpiringSoon
                        ? AppColors.warning
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationForm(StudentVerification verification) {
    final canSubmit = !verification.emailLocked && !verification.isPending;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '认证信息',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vMd,

          // 大学选择
          DropdownButtonFormField<University>(
            value: _selectedUniversity,
            decoration: InputDecoration(
              labelText: '选择大学',
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
              ),
              prefixIcon: const Icon(Icons.school_outlined),
            ),
            items: _universities.map((university) {
              return DropdownMenuItem<University>(
                value: university,
                child: Text(university.displayName),
              );
            }).toList(),
            onChanged: canSubmit
                ? (University? value) {
                    setState(() {
                      _selectedUniversity = value;
                    });
                  }
                : null,
            validator: (value) {
              if (value == null) {
                return '请选择大学';
              }
              return null;
            },
          ),
          AppSpacing.vMd,

          // 邮箱输入
          TextFormField(
            controller: _emailController,
            enabled: canSubmit,
            decoration: InputDecoration(
              labelText: '学校邮箱',
              hintText: 'example@university.ac.uk',
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
              ),
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '请输入邮箱';
              }
              if (!value.contains('@')) {
                return '请输入有效的邮箱地址';
              }
              return null;
            },
          ),
          AppSpacing.vLg,

          // 提交按钮
          if (canSubmit)
            PrimaryButton(
              text: verification.canRenew ? '续期认证' : '提交认证',
              onPressed: _isSubmitting ? null : _submitVerification,
              isLoading: _isSubmitting,
            ),

          // 提示信息
          if (verification.emailLocked) ...[
            AppSpacing.vMd,
            Container(
              padding: AppSpacing.allMd,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.allMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: Text(
                      '邮箱已锁定，请等待审核完成',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (verification.isPending) ...[
            AppSpacing.vMd,
            Container(
              padding: AppSpacing.allMd,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: AppRadius.allMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.pending_outlined,
                    color: AppColors.warning,
                  ),
                  AppSpacing.hSm,
                  Expanded(
                    child: Text(
                      '认证审核中，请查收邮箱并完成验证',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
