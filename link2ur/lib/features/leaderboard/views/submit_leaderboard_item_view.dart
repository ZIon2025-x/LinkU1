import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 提交排行榜条目页
/// 参考iOS SubmitLeaderboardItemView.swift
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
  final _scoreController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.isEmpty) {
      setState(() => _localError = context.l10n.leaderboardFillRequired);
      return;
    }

    setState(() => _localError = null);

    context.read<LeaderboardBloc>().add(LeaderboardSubmitItem(
          leaderboardId: widget.leaderboardId,
          name: _nameController.text,
          description: _descriptionController.text,
          score: double.tryParse(_scoreController.text),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                  // 名称
                  _buildField(
                    label: l10n.leaderboardItemName,
                    controller: _nameController,
                    isRequired: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 描述
                  _buildField(
                    label: l10n.leaderboardItemDescription,
                    controller: _descriptionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 分数
                  _buildField(
                    label: l10n.leaderboardItemScore,
                    controller: _scoreController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 错误
                  if (errorMsg != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(errorMsg,
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(l10n.leaderboardSubmit,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
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
    int maxLines = 1,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
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
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
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
