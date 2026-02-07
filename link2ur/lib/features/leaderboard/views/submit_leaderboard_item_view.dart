import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/leaderboard_repository.dart';

/// 提交排行榜条目页
/// 参考iOS SubmitLeaderboardItemView.swift
class SubmitLeaderboardItemView extends StatefulWidget {
  const SubmitLeaderboardItemView({
    super.key,
    required this.leaderboardId,
  });

  final int leaderboardId;

  @override
  State<SubmitLeaderboardItemView> createState() =>
      _SubmitLeaderboardItemViewState();
}

class _SubmitLeaderboardItemViewState
    extends State<SubmitLeaderboardItemView> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scoreController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty) {
      setState(() => _errorMessage = context.l10n.leaderboardFillRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<LeaderboardRepository>();
      await repo.submitItem(
        leaderboardId: widget.leaderboardId,
        name: _nameController.text,
        description: _descriptionController.text,
        score: double.tryParse(_scoreController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.leaderboardSubmitSuccess)),
        );
        Navigator.of(context).pop(true);
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
              Text(' *',
                  style: TextStyle(color: AppColors.error)),
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
