import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/leaderboard_repository.dart';

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
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      setState(() => _errorMessage = context.l10n.leaderboardFillRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<LeaderboardRepository>();
      await repo.applyLeaderboard(
        title: _titleController.text,
        description: _descriptionController.text,
        rules: _rulesController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.leaderboardApplySuccess)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leaderboardApply),
      ),
      body: SingleChildScrollView(
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
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(_errorMessage!,
                    style: TextStyle(
                        color: AppColors.error, fontSize: 13)),
              ),

            // 提交
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: _isSubmitting
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
              Text(' *',
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
