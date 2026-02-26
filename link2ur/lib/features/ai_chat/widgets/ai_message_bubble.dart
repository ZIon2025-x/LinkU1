import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/ai_chat.dart';

/// AI 消息气泡
class AIMessageBubble extends StatelessWidget {
  const AIMessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  final AIMessage message;
  final bool isStreaming;

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
            _AIAvatar(isDark: isDark),
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
                    color: isUser
                        ? AppColors.primary
                        : isDark
                            ? const Color(0xFF2C2C2E)
                            : const Color(0xFFF2F2F7),
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
                  ),
                  child: isUser
                      ? SelectableText(
                          message.content,
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
                if (!isUser)
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

/// AI 头像（使用 any 图标）
class _AIAvatar extends StatelessWidget {
  const _AIAvatar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Image.asset(
        AppAssets.any,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
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
          _AIAvatar(isDark: isDark),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.large),
                  topRight: Radius.circular(AppRadius.large),
                  bottomLeft: Radius.circular(AppRadius.tiny),
                  bottomRight: Radius.circular(AppRadius.large),
                ),
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

/// 思考中指示器
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
      return ('View tasks →', AppRoutes.tasks);
    case 'list_activities':
      return ('View activities →', AppRoutes.activities);
    case 'get_my_points_and_coupons':
      return ('Go to wallet →', AppRoutes.wallet);
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
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
    );
  }
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white54 : Colors.black38,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
