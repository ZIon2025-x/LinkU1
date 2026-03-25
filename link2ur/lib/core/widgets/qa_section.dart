import 'package:flutter/material.dart';
import '../../data/models/task_question.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_radius.dart';
import '../design/app_typography.dart';
import '../utils/date_formatter.dart';
import '../utils/l10n_extension.dart';
import '../utils/adaptive_dialogs.dart';

/// Shared Q&A section for task and service detail pages.
class QASection extends StatefulWidget {
  const QASection({
    super.key,
    required this.targetType,
    required this.isOwner,
    required this.isDark,
    required this.questions,
    required this.isLoading,
    required this.totalCount,
    required this.onAsk,
    required this.onReply,
    required this.onDelete,
    required this.onLoadMore,
    this.isLoggedIn = true,
    this.allowAsk = true,
  });

  final String targetType; // 'task' / 'service'
  final bool isOwner;
  final bool isDark;
  final List<TaskQuestion> questions;
  final bool isLoading;
  final int totalCount;
  final ValueChanged<String> onAsk;
  final void Function(int questionId, String content) onReply;
  final ValueChanged<int> onDelete;
  final VoidCallback onLoadMore;
  final bool isLoggedIn;
  /// Whether the user can ask (false when task is not open/chatting)
  final bool allowAsk;

  @override
  State<QASection> createState() => _QASectionState();
}

class _QASectionState extends State<QASection> {
  final _askController = TextEditingController();

  @override
  void dispose() {
    _askController.dispose();
    super.dispose();
  }

  void _handleAsk() {
    final content = _askController.text.trim();
    if (content.length < 2) return;
    widget.onAsk(content);
    _askController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: widget.isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.question_answer_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.qaTitle(widget.totalCount),
                style: AppTypography.title3.copyWith(
                  color: widget.isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),

          // Ask input (logged in + not owner + allowAsk)
          if (widget.isLoggedIn && !widget.isOwner && widget.allowAsk) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _askController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: l10n.qaAskPlaceholder,
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide(
                          color: widget.isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        ),
                      ),
                    ),
                    style: AppTypography.body.copyWith(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _handleAsk,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: Text(l10n.qaAskButton),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Questions list
          if (widget.isLoading && widget.questions.isEmpty)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else if (widget.questions.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  l10n.qaNoQuestions,
                  style: AppTypography.body.copyWith(
                    color: widget.isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else ...[
            ...widget.questions.map((q) => _QACard(
              key: ValueKey('qa_${q.id}'),
              question: q,
              isDark: widget.isDark,
              isOwner: widget.isOwner,
              targetType: widget.targetType,
              onReply: widget.onReply,
              onDelete: widget.onDelete,
            )),

            // Load more button
            if (widget.questions.length < widget.totalCount)
              Center(
                child: TextButton(
                  onPressed: widget.isLoading ? null : widget.onLoadMore,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.qaLoadMore),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QACard extends StatefulWidget {
  const _QACard({
    super.key,
    required this.question,
    required this.isDark,
    required this.isOwner,
    required this.targetType,
    required this.onReply,
    required this.onDelete,
  });

  final TaskQuestion question;
  final bool isDark;
  final bool isOwner;
  final String targetType;
  final void Function(int questionId, String content) onReply;
  final ValueChanged<int> onDelete;

  @override
  State<_QACard> createState() => _QACardState();
}

class _QACardState extends State<_QACard> {
  final _replyController = TextEditingController();
  bool _showReplyInput = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _handleReply() {
    final content = _replyController.text.trim();
    if (content.length < 2) return;
    widget.onReply(widget.question.id, content);
    setState(() => _showReplyInput = false);
    _replyController.clear();
  }

  void _handleDelete() {
    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: context.l10n.qaDeleteConfirm,
      content: context.l10n.qaDeleteConfirmBody,
      onConfirm: () => widget.onDelete(widget.question.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = widget.question;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: widget.isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Question header: icon + time + delete button
            Row(
              children: [
                Icon(Icons.help_outline, size: 16,
                    color: AppColors.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                if (q.createdAt != null)
                  Text(
                    DateFormatter.formatRelative(DateTime.parse(q.createdAt!).toLocal()),
                    style: AppTypography.caption.copyWith(
                      color: widget.isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      fontSize: 11,
                    ),
                  ),
                const Spacer(),
                if (q.isOwn)
                  GestureDetector(
                    onTap: _handleDelete,
                    child: Icon(Icons.delete_outline, size: 16,
                        color: widget.isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  ),
              ],
            ),

            // Question content
            const SizedBox(height: 6),
            Text(
              q.content,
              style: AppTypography.body.copyWith(
                color: widget.isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                height: 1.5,
              ),
            ),

            // Reply section
            if (q.hasReply) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(left: AppSpacing.lg),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.allSmall,
                  border: Border(
                    left: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.reply, size: 14,
                            color: AppColors.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          widget.targetType == 'service'
                              ? l10n.qaServiceOwnerReply
                              : l10n.qaOwnerReply,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        if (q.replyAt != null)
                          Text(
                            DateFormatter.formatRelative(DateTime.parse(q.replyAt!).toLocal()),
                            style: AppTypography.caption.copyWith(
                              color: widget.isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      q.reply!,
                      style: AppTypography.body.copyWith(
                        color: widget.isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (widget.isOwner) ...[
              // Reply button / input for owner
              const SizedBox(height: AppSpacing.sm),
              if (_showReplyInput)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _replyController,
                          maxLength: 100,
                          decoration: InputDecoration(
                            hintText: l10n.qaReplyPlaceholder,
                            counterText: '',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allSmall,
                            ),
                          ),
                          style: AppTypography.body.copyWith(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _handleReply,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(l10n.qaReplyButton, style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.lg),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showReplyInput = true),
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text(l10n.qaReplyButton),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
