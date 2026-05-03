import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/system_context_menu.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/ai_chat.dart';
import 'linker_avatar.dart';

/// AI 消息气泡
class AIMessageBubble extends StatelessWidget {
  const AIMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onConfirmPublish,
  });

  final AIMessage message;
  final bool isStreaming;
  /// 当本条为「准备任务草稿」消息且当前有草稿时，点击「确认并去发布」时回调（与 TaskDraftCard 行为一致）
  final VoidCallback? onConfirmPublish;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const LinkerAvatar(),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: AppColors.gradientPrimary,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.white,
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.white12
                                : const Color(0xFFE5E5EA),
                            width: 0.5,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppRadius.large),
                      topRight: const Radius.circular(AppRadius.large),
                      bottomLeft: isUser
                          ? const Radius.circular(AppRadius.large)
                          : const Radius.circular(AppRadius.tiny),
                      bottomRight: isUser
                          ? const Radius.circular(AppRadius.tiny)
                          : const Radius.circular(AppRadius.large),
                    ),
                    boxShadow: isUser
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.22),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
                          contextMenuBuilder: systemContextMenuBuilder,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            height: 1.4,
                          ),
                        )
                      : MarkdownBody(
                          data: message.content,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                            code: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              backgroundColor: isDark
                                  ? const Color(0xFF1C1C1E)
                                  : const Color(0xFFE8E8E8),
                            ),
                          ),
                          selectable: true,
                        ),
                ),
                if (!isUser && onConfirmPublish != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onConfirmPublish,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: Text(context.l10n.aiTaskDraftConfirmButton),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!isUser && onConfirmPublish == null)
                  Builder(
                    builder: (context) {
                      final action = _resolveAction(message.toolName);
                      if (action == null) return const SizedBox.shrink();
                      return _ActionButton(
                        label: action.$1,
                        onTap: () => context.push(action.$2),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// 流式回复气泡（打字机效果：一字一字出现 + 闪烁光标）
class StreamingBubble extends StatelessWidget {
  const StreamingBubble({
    super.key,
    required this.content,
  });

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LinkerAvatar(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: content.isEmpty ? AppSpacing.md + 2 : AppSpacing.md,
                vertical: content.isEmpty ? 14 : 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : Colors.white,
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE5E5EA),
                  width: 0.5,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.large),
                  topRight: Radius.circular(AppRadius.large),
                  bottomLeft: Radius.circular(AppRadius.tiny),
                  bottomRight: Radius.circular(AppRadius.large),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 1,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: content.isEmpty
                  ? _ThinkingIndicator(isDark: isDark)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarkdownBody(
                          data: content,
                          styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const Text(
                          ' ▍',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 思考中指示器（三点 + 轮播提示文字）
class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator({required this.isDark});

  final bool isDark;

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

/// Returns (buttonLabel, route) for tool-result messages, or null if no action.
(String, String)? _resolveAction(String? toolName) {
  switch (toolName) {
    case 'query_my_tasks':
    case 'search_tasks':
    case 'recommend_tasks':
      return ('View tasks →', AppRoutes.tasks);
    case 'list_activities':
    case 'get_activity_detail':
      return ('View activities →', AppRoutes.activities);
    case 'get_my_points_and_coupons':
      return ('Go to wallet →', AppRoutes.wallet);
    case 'search_forum_posts':
    case 'list_my_forum_posts':
    case 'get_forum_post_detail':
      return ('View forum →', AppRoutes.forum);
    case 'search_flea_market':
    case 'get_flea_market_item_detail':
    case 'get_my_flea_market_items':
      return ('View market →', AppRoutes.fleaMarket);
    case 'get_leaderboard_summary':
      return ('View leaderboard →', AppRoutes.leaderboard);
    case 'list_task_experts':
    case 'get_expert_detail':
    case 'get_expert_reviews':
    case 'search_services':
      return ('View experts →', AppRoutes.taskExperts);
    default:
      return null;
  }
}

/// Small tappable navigation chip shown below tool-result assistant messages.
class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: AppSpacing.sm),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios,
                size: 10,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int _hintIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // 每 3 秒切换一条提示
    Future.delayed(const Duration(seconds: 3), _cycleHint);
  }

  void _cycleHint() {
    if (!mounted) return;
    setState(() => _hintIndex++);
    Future.delayed(const Duration(seconds: 3), _cycleHint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Bounce envelope: t∈[0,1) → rises and falls in the first 60% of the cycle, idle after.
  double _bounce(double t) {
    if (t < 0.6) return math.sin(t / 0.6 * math.pi);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hints = [
      l10n.aiThinkingHint1,
      l10n.aiThinkingHint2,
      l10n.aiThinkingHint3,
    ];
    final hint = hints[_hintIndex % hints.length];
    final hintColor = widget.isDark ? Colors.white38 : Colors.black26;
    final dotColor = widget.isDark ? Colors.white54 : const Color(0xFFA1A1A6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value + i * 0.16) % 1.0;
                final v = _bounce(t);
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                  child: Transform.translate(
                    offset: Offset(0, -5 * v),
                    child: Opacity(
                      opacity: 0.4 + 0.6 * v,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            hint,
            key: ValueKey<int>(_hintIndex % hints.length),
            style: TextStyle(fontSize: 11, color: hintColor),
          ),
        ),
      ],
    );
  }
}
