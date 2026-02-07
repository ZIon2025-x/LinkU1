import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
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
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      setState(() => _errorMessage = context.l10n.leaderboardFillRequired);
      return;
    }

    setState(() => _errorMessage = null);

    context.read<LeaderboardBloc>().add(
          LeaderboardApplyRequested(
            title: _titleController.text,
            description: _descriptionController.text,
            rules: _rulesController.text.isEmpty ? null : _rulesController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      ),
      child: BlocListener<LeaderboardBloc, LeaderboardState>(
        listener: (context, state) {
          if (state.actionMessage != null) {
            if (state.actionMessage!.contains('成功') ||
                state.actionMessage!.contains('已提交')) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.l10n.leaderboardApplySuccess)),
              );
              Navigator.of(context).pop();
            } else {
              setState(() {
                _errorMessage = state.actionMessage;
              });
            }
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.leaderboardApply),
          ),
          body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 标题
                    _buildField(
                      label: l10n.leaderboardTitle,
                      controller: _titleController,
                      hint: l10n.leaderboardTitleHint,
                      isRequired: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 描述
                    _buildField(
                      label: l10n.leaderboardDescription,
                      controller: _descriptionController,
                      hint: l10n.leaderboardDescriptionHint,
                      maxLines: 4,
                      isRequired: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 规则
                    _buildField(
                      label: l10n.leaderboardRules,
                      controller: _rulesController,
                      hint: l10n.leaderboardRulesHint,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // 错误
                    if (_errorMessage != null || state.actionMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                            _errorMessage ?? state.actionMessage ?? '',
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),

                    // 提交
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(l10n.leaderboardSubmitApply,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            if (isRequired)
              const Text(' *',
                  style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
