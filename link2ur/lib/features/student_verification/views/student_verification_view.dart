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
import '../bloc/student_verification_bloc.dart';

/// 学生认证视图
/// 参考iOS StudentVerificationView.swift
class StudentVerificationView extends StatelessWidget {
  const StudentVerificationView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StudentVerificationBloc(
        verificationRepository:
            context.read<StudentVerificationRepository>(),
      )..add(const StudentVerificationLoadRequested()),
      child: const _StudentVerificationContent(),
    );
  }
}

class _StudentVerificationContent extends StatefulWidget {
  const _StudentVerificationContent();

  @override
  State<_StudentVerificationContent> createState() =>
      _StudentVerificationContentState();
}

class _StudentVerificationContentState
    extends State<_StudentVerificationContent> {
  University? _selectedUniversity;
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StudentVerificationBloc, StudentVerificationState>(
      listenWhen: (prev, curr) => curr.actionMessage != null,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
              backgroundColor: state.actionMessage!.contains('成功')
                  ? AppColors.success
                  : AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.studentVerificationVerification),
        ),
        body: BlocBuilder<StudentVerificationBloc, StudentVerificationState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingView();
            }

            if (state.status == StudentVerificationStatus.error &&
                state.verification == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '',
                onRetry: () => context
                    .read<StudentVerificationBloc>()
                    .add(const StudentVerificationLoadRequested()),
              );
            }

            if (state.verification == null) {
              return ErrorStateView.notFound();
            }

            final verification = state.verification!;

            // Pre-fill email if locked
            if (verification.emailLocked && verification.email != null) {
              _emailController.text = verification.email!;
            }

            return SingleChildScrollView(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusCard(verification),
                  AppSpacing.vLg,
                  if (!verification.isVerified || verification.canRenew)
                    _buildVerificationForm(verification, state),
                ],
              ),
            );
          },
        ),
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
          if (verification.isVerified &&
              verification.daysRemaining != null) ...[
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

  Widget _buildVerificationForm(
      StudentVerification verification, StudentVerificationState state) {
    final canSubmit = !verification.emailLocked && !verification.isPending;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '认证信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              onPressed: state.isSubmitting
                  ? null
                  : () {
                      if (!_formKey.currentState!.validate()) return;

                      if (verification.canRenew) {
                        context
                            .read<StudentVerificationBloc>()
                            .add(const StudentVerificationRenew());
                      } else {
                        context
                            .read<StudentVerificationBloc>()
                            .add(StudentVerificationSubmit(
                              universityId: _selectedUniversity?.id ?? 0,
                              email: _emailController.text.trim(),
                            ));
                      }
                    },
              isLoading: state.isSubmitting,
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
                  Icon(Icons.info_outline, color: AppColors.warning),
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
                  Icon(Icons.pending_outlined, color: AppColors.warning),
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
