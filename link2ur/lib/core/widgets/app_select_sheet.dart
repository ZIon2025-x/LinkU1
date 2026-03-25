import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_spacing.dart';

/// 选项数据模型
class SelectOption<T> {
  const SelectOption({
    required this.value,
    required this.label,
    this.icon,
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? description;
  final bool enabled;
}

/// Bottom sheet 选择器的触发输入框
///
/// 替代 [DropdownButtonFormField]，点击后弹出底部面板。
/// 选项 > [searchThreshold] 个时自动显示搜索框。
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.options,
    required this.onChanged,
    this.value,
    this.hint,
    this.label,
    this.prefixIcon,
    this.sheetTitle,
    this.searchThreshold = 6,
    this.searchHint,
    this.clearable = true,
    this.validator,
  });

  final List<SelectOption<T>> options;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? hint;
  final String? label;
  final IconData? prefixIcon;
  final String? sheetTitle;
  final int searchThreshold;
  final String? searchHint;
  final bool clearable;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) {
    if (validator != null) {
      return FormField<T>(
        initialValue: value,
        validator: validator,
        builder: (state) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(context, state),
              if (state.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    state.errorText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }
    return _buildField(context, null);
  }

  Widget _buildField(BuildContext context, FormFieldState<T>? formState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = options.where((o) => o.value == value).firstOrNull;
    final hasValue = selected != null;

    return GestureDetector(
      onTap: () async {
        final result = await showAppSelectSheet<T>(
          context: context,
          options: options,
          value: value,
          title: sheetTitle ?? label ?? hint ?? '',
          searchThreshold: searchThreshold,
          searchHint: searchHint,
        );
        if (result != null) {
          onChanged(result.value);
          formState?.didChange(result.value);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: hasValue ? AppColors.primary : null)
              : null,
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasValue && clearable)
                GestureDetector(
                  onTap: () {
                    onChanged(null);
                    formState?.didChange(null);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              const SizedBox(width: 4),
            ],
          ),
          filled: true,
          fillColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFF5F5F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
            borderSide: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : const Color(0xFFDDDDDD),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
            borderSide: BorderSide(
              color: hasValue
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFDDDDDD)),
            ),
          ),
        ),
        child: Row(
          children: [
            if (selected?.icon != null) ...[
              Icon(selected!.icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                selected?.label ?? hint ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 弹出底部选择面板，返回选中的选项（null 表示未选择）
Future<SelectOption<T>?> showAppSelectSheet<T>({
  required BuildContext context,
  required List<SelectOption<T>> options,
  T? value,
  String title = '',
  int searchThreshold = 6,
  String? searchHint,
}) {
  return showModalBottomSheet<SelectOption<T>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SelectSheet<T>(
      options: options,
      value: value,
      title: title,
      showSearch: options.length > searchThreshold,
      searchHint: searchHint,
    ),
  );
}

class _SelectSheet<T> extends StatefulWidget {
  const _SelectSheet({
    required this.options,
    required this.title,
    required this.showSearch,
    this.value,
    this.searchHint,
  });

  final List<SelectOption<T>> options;
  final T? value;
  final String title;
  final bool showSearch;
  final String? searchHint;

  @override
  State<_SelectSheet<T>> createState() => _SelectSheetState<T>();
}

class _SelectSheetState<T> extends State<_SelectSheet<T>> {
  final _searchController = TextEditingController();
  List<SelectOption<T>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.options;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = widget.options;
      } else {
        _filtered = widget.options.where((o) {
          return o.label.toLowerCase().contains(q) ||
              (o.description?.toLowerCase().contains(q) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // 动态高度：少选项时紧凑，多选项最高 70%
    final itemHeight = 56.0;
    final headerHeight = 56.0;
    final searchHeight = widget.showSearch ? 52.0 : 0.0;
    final contentHeight = headerHeight + searchHeight + (_filtered.length * itemHeight) + bottomPadding + 16;
    final maxHeight = MediaQuery.of(context).size.height * 0.7;
    final sheetHeight = contentHeight.clamp(0.0, maxHeight);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF555555) : const Color(0xFFDDDDDD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search
          if (widget.showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                autofocus: false,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? '搜索…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 40),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE8E8E8),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF333333) : const Color(0xFFE8E8E8),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        '没有匹配的选项',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, bottomPadding + 16),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final option = _filtered[index];
                      final isSelected = option.value == widget.value;
                      return _OptionItem<T>(
                        option: option,
                        isSelected: isSelected,
                        isDark: isDark,
                        onTap: option.enabled
                            ? () => Navigator.pop(context, option)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _OptionItem<T> extends StatelessWidget {
  const _OptionItem({
    required this.option,
    required this.isSelected,
    required this.isDark,
    this.onTap,
  });

  final SelectOption<T> option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm + 5,
        ),
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Row(
          children: [
            // Icon
            if (option.icon != null)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.1)
                      : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  option.icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            if (option.icon != null) const SizedBox(width: AppSpacing.sm + 4),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: !option.enabled
                          ? (isDark ? Colors.white24 : Colors.black26)
                          : isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (option.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        option.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

            // Check
            if (isSelected)
              const Icon(Icons.check, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
