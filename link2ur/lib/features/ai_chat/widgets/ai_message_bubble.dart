import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
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
            child: Container(
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
              child: SelectableText(
                message.content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isUser
                      ? Colors.white
                      : isDark
                          ? Colors.white
                          : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// AI 头像
class _AIAvatar extends StatelessWidget {
  const _AIAvatar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 18,
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
                  : _TypewriterText(
                      content: content,
                      isDark: isDark,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 打字机效果：将已有内容逐字显示（每 40ms 多显示 1 个字符）
class _TypewriterText extends StatefulWidget {
  const _TypewriterText({
    required this.content,
    required this.isDark,
    this.style,
  });

  final String content;
  final bool isDark;
  final TextStyle? style;

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  int _visibleLength = 0;
  Timer? _timer;

  static const _interval = Duration(milliseconds: 40);

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      if (widget.content.length < _visibleLength) {
        _visibleLength = widget.content.length;
      }
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.content.isEmpty) return;
    if (_visibleLength >= widget.content.length) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      if (_visibleLength < widget.content.length) {
        setState(() => _visibleLength += 1);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.content.substring(0, _visibleLength.clamp(0, widget.content.length));
    return SelectableText.rich(
      TextSpan(
        children: [
          TextSpan(text: visible, style: widget.style),
          const TextSpan(
            text: ' ▍',
            style: TextStyle(color: AppColors.primary),
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
