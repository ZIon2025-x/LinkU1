import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';

/// 增强型输入框状态
enum EnhancedTextFieldStatus {
  normal,
  focused,
  error,
  success,
}

/// 增强型输入框
/// 参考iOS EnhancedTextField.swift
/// 支持状态管理、错误提示、密码显示/隐藏、字符计数、清除按钮
class EnhancedTextField extends StatefulWidget {
  const EnhancedTextField({
    super.key,
    this.controller,
    this.label,
    this.placeholder,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.showCharCount = false,
    this.showClearButton = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofocus = false,
    this.inputFormatters,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? placeholder;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final bool showCharCount;
  final bool showClearButton;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

class _EnhancedTextFieldState extends State<EnhancedTextField>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _obscureText = true;
  String? _validationError;

  late AnimationController _animController;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);

    _animController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _borderAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_isFocused) {
      _animController.forward();
    } else {
      _animController.reverse();
      // 失去焦点时验证
      if (widget.validator != null) {
        setState(() {
          _validationError = widget.validator!(_controller.text);
        });
      }
    }
  }

  EnhancedTextFieldStatus get _status {
    if (widget.errorText != null || _validationError != null) {
      return EnhancedTextFieldStatus.error;
    }
    if (_isFocused) return EnhancedTextFieldStatus.focused;
    return EnhancedTextFieldStatus.normal;
  }

  Color get _borderColor {
    switch (_status) {
      case EnhancedTextFieldStatus.error:
        return AppColors.error;
      case EnhancedTextFieldStatus.success:
        return AppColors.success;
      case EnhancedTextFieldStatus.focused:
        return AppColors.primary;
      case EnhancedTextFieldStatus.normal:
        return AppColors.dividerLight;
    }
  }

  String? get _displayError => widget.errorText ?? _validationError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标签
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // 输入框
        AnimatedBuilder(
          animation: _borderAnimation,
          builder: (context, child) {
            return TextField(
              controller: _controller,
              focusNode: _focusNode,
              obscureText: widget.isPassword && _obscureText,
              maxLength: widget.maxLength,
              maxLines: widget.isPassword ? 1 : widget.maxLines,
              minLines: widget.minLines,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              inputFormatters: widget.inputFormatters,
              onChanged: (value) {
                setState(() {}); // 刷新字符计数和清除按钮
                widget.onChanged?.call(value);
              },
              onSubmitted: widget.onSubmitted,
              buildCounter: widget.showCharCount
                  ? null
                  : (context,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: TextStyle(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        size: 20,
                        color: _isFocused
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      )
                    : null,
                suffixIcon: _buildSuffixIcon(),
                filled: true,
                fillColor: isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: BorderSide(
                    color: _borderColor,
                    width: _borderAnimation.value,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: BorderSide(
                    color: _status == EnhancedTextFieldStatus.error
                        ? AppColors.error
                        : (isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: BorderSide(
                    color: _status == EnhancedTextFieldStatus.error
                        ? AppColors.error
                        : AppColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
              ),
            );
          },
        ),

        // 底部信息行
        _buildBottomRow(isDark),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    final widgets = <Widget>[];

    // 密码显示/隐藏
    if (widget.isPassword) {
      widgets.add(
        GestureDetector(
          onTap: () => setState(() => _obscureText = !_obscureText),
          child: Icon(
            _obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppColors.textSecondaryLight,
          ),
        ),
      );
    }

    // 清除按钮
    if (widget.showClearButton && _controller.text.isNotEmpty && _isFocused) {
      widgets.add(
        GestureDetector(
          onTap: () {
            _controller.clear();
            widget.onChanged?.call('');
            setState(() {});
          },
          child: const Icon(
            Icons.cancel,
            size: 18,
            color: AppColors.textTertiaryLight,
          ),
        ),
      );
    }

    // 自定义后缀
    if (widget.suffixIcon != null) {
      widgets.add(widget.suffixIcon!);
    }

    if (widgets.isEmpty) return null;
    if (widgets.length == 1) return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: widgets.first,
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: widgets.map((w) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: w,
        )).toList(),
      ),
    );
  }

  Widget _buildBottomRow(bool isDark) {
    final hasError = _displayError != null;
    final hasHelper = widget.helperText != null;
    final hasCharCount = widget.showCharCount && widget.maxLength != null;

    if (!hasError && !hasHelper && !hasCharCount) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
      child: Row(
        children: [
          // 错误/帮助文本
          Expanded(
            child: hasError
                ? Text(
                    _displayError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  )
                : hasHelper
                    ? Text(
                        widget.helperText!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      )
                    : const SizedBox.shrink(),
          ),

          // 字符计数
          if (hasCharCount)
            Text(
              '${_controller.text.length}/${widget.maxLength}',
              style: TextStyle(
                fontSize: 12,
                color: _controller.text.length >= (widget.maxLength! * 0.9)
                    ? AppColors.error
                    : (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
              ),
            ),
        ],
      ),
    );
  }
}
