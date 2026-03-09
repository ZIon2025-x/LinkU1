import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/l10n_extension.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// Formats a [DateTime] as `yyyy-MM-dd` without depending on any package.
String _toDateStr(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Schedule tab — shows a month calendar with closed (unavailable) dates
/// marked in red. Tapping a date opens a dialog to toggle its closed status.
class ExpertDashboardScheduleTab extends StatefulWidget {
  const ExpertDashboardScheduleTab({super.key});

  @override
  State<ExpertDashboardScheduleTab> createState() =>
      _ExpertDashboardScheduleTabState();
}

class _ExpertDashboardScheduleTabState
    extends State<ExpertDashboardScheduleTab> {
  late DateTime _focusedMonth;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Map<String, dynamic>? _findClosedEntry(
      DateTime day, List<Map<String, dynamic>> closedDates) {
    final dateStr = _toDateStr(day);
    try {
      return closedDates.firstWhere((d) => d['closed_date'] == dateStr);
    } catch (_) {
      return null;
    }
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _onDayTapped(
      BuildContext context, DateTime day, List<Map<String, dynamic>> closedDates) async {
    final entry = _findClosedEntry(day, closedDates);
    final isClosed = entry != null;

    if (isClosed) {
      final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
        context: context,
        title: context.l10n.expertScheduleRemoveClosed,
        content: _toDateStr(day),
        isDestructive: true,
        onConfirm: () => true,
      );
      if (confirmed == true && context.mounted) {
        context.read<ExpertDashboardBloc>().add(
              ExpertDashboardDeleteClosedDate(
                entry['id']?.toString() ?? '',
              ),
            );
      }
    } else {
      _showMarkClosedDialog(context, day);
    }
  }

  void _showMarkClosedDialog(BuildContext context, DateTime day) {
    final dateStr = _toDateStr(day);
    _reasonController.clear();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.expertScheduleSetClosed),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertScheduleClosedReason,
                  hintText: context.l10n.expertScheduleClosedReasonHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                final reason = _reasonController.text.trim();
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  context.read<ExpertDashboardBloc>().add(
                        ExpertDashboardCreateClosedDate(
                          dateStr,
                          reason: reason.isEmpty ? null : reason,
                        ),
                      );
                }
                _reasonController.clear();
              },
              child: Text(context.l10n.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _prevMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) => prev.closedDates != curr.closedDates,
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CalendarHeader(
                focusedMonth: _focusedMonth,
                onPrevMonth: _prevMonth,
                onNextMonth: _nextMonth,
              ),
              const SizedBox(height: AppSpacing.sm),
              _CalendarGrid(
                focusedMonth: _focusedMonth,
                closedDates: state.closedDates,
                onDayTapped: (day) =>
                    _onDayTapped(context, day, state.closedDates),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Legend(),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Calendar header: prev/next + month-year label
// =============================================================================

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.focusedMonth,
    required this.onPrevMonth,
    required this.onNextMonth,
  });

  final DateTime focusedMonth;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;

  String _monthLabel(BuildContext context) {
    // Use intl DateFormat so all locales (en, zh, zh_Hant, …) are handled
    // correctly without manual month-name arrays or language-code branches.
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMM(locale).format(focusedMonth);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevMonth,
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
        ),
        Text(
          _monthLabel(context),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onNextMonth,
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
        ),
      ],
    );
  }
}

// =============================================================================
// Calendar grid: weekday header row + day cells
// =============================================================================

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focusedMonth,
    required this.closedDates,
    required this.onDayTapped,
  });

  final DateTime focusedMonth;
  final List<Map<String, dynamic>> closedDates;
  final void Function(DateTime day) onDayTapped;

  // Returns weekday abbreviations; Monday-first.
  List<String> _weekdayLabels(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'zh') {
      return ['一', '二', '三', '四', '五', '六', '日'];
    }
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  }

  bool _isClosed(DateTime day) {
    final dateStr = _toDateStr(day);
    return closedDates.any((e) => e['closed_date'] == dateStr);
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // First day of month and how many days in month.
    final firstDay =
        DateTime(focusedMonth.year, focusedMonth.month);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;

    // weekday: Mon=1 … Sun=7. Offset = (weekday - 1) leading blank cells.
    final leadingBlanks = firstDay.weekday - 1;

    final totalCells = leadingBlanks + daysInMonth;
    // Round up to full weeks.
    final rows = ((totalCells) / 7).ceil();

    final weekdayLabels = _weekdayLabels(context);

    return Column(
      children: [
        // ── Weekday header ────────────────────────────────────────────
        Row(
          children: List.generate(7, (i) {
            final isSunday = i == 6;
            return Expanded(
              child: Center(
                child: Text(
                  weekdayLabels[i],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isSunday
                            ? AppColors.error
                            : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                      ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),

        // ── Day rows ──────────────────────────────────────────────────
        ...List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNumber = cellIndex - leadingBlanks + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const Expanded(child: SizedBox());
              }

              final day = DateTime(
                  focusedMonth.year, focusedMonth.month, dayNumber);
              final closed = _isClosed(day);
              final today = _isToday(day);
              final isSunday = col == 6;

              return Expanded(
                child: _DayCell(
                  day: dayNumber,
                  isClosed: closed,
                  isToday: today,
                  isSunday: isSunday,
                  isDark: isDark,
                  onTap: () => onDayTapped(day),
                ),
              );
            }),
          );
        }),
      ],
    );
  }
}

// =============================================================================
// Single day cell
// =============================================================================

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isClosed,
    required this.isToday,
    required this.isSunday,
    required this.isDark,
    required this.onTap,
  });

  final int day;
  final bool isClosed;
  final bool isToday;
  final bool isSunday;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bgColor;
    Color textColor;

    if (isClosed) {
      bgColor = AppColors.error;
      textColor = Colors.white;
    } else if (isToday) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
    } else {
      bgColor = null;
      textColor = isSunday
          ? AppColors.error.withValues(alpha: 0.8)
          : (isDark ? Colors.white : Colors.black87);
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.allSmall,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: AppRadius.allSmall,
              border: (!isClosed && !isToday)
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.06),
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              day.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    (isClosed || isToday) ? FontWeight.w700 : FontWeight.w400,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Legend
// =============================================================================

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: AppColors.primary,
          label: context.l10n.expertScheduleToday,
          isDark: isDark,
        ),
        const SizedBox(width: AppSpacing.lg),
        _LegendItem(
          color: AppColors.error,
          label: context.l10n.expertScheduleSetClosed,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });

  final Color color;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
        ),
      ],
    );
  }
}
