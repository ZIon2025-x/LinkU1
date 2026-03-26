import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/error_state_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// Time Slots tab for the Expert Dashboard — lets experts manage time slots
/// per service (select service → view/add/delete slots).
class ExpertDashboardTimeSlotsTab extends StatelessWidget {
  const ExpertDashboardTimeSlotsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.services != curr.services ||
          prev.timeSlots != curr.timeSlots ||
          prev.selectedServiceId != curr.selectedServiceId ||
          prev.status != curr.status,
      builder: (context, state) {
        // Show loading spinner while services are being fetched for the first time
        if ((state.status == ExpertDashboardStatus.initial ||
                state.status == ExpertDashboardStatus.loading) &&
            state.services.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ExpertDashboardStatus.error &&
            state.services.isEmpty) {
          return ErrorStateView(
            message: context.localizeError(
                state.errorMessage ?? 'expert_dashboard_load_services_failed'),
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadMyServices()),
          );
        }

        final bool isSubmitting =
            state.status == ExpertDashboardStatus.submitting;
        final bool isLoadingSlots =
            state.status == ExpertDashboardStatus.loading &&
                state.selectedServiceId != null;
        final bool noServiceSelected = state.selectedServiceId == null;

        return Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Service selector ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: _ServiceDropdown(
                  services: state.services,
                  selectedServiceId: state.selectedServiceId,
                  onChanged: (serviceId) {
                    if (serviceId != null) {
                      context
                          .read<ExpertDashboardBloc>()
                          .add(ExpertDashboardLoadTimeSlots(serviceId));
                    }
                  },
                ),
              ),

              // ── Slots list / empty / loading ──────────────────────────────
              Expanded(
                child: noServiceSelected
                    ? _EmptyTimeSlotsView(
                        hasServices: state.services.isNotEmpty,
                      )
                    : isLoadingSlots
                        ? const Center(child: CircularProgressIndicator())
                        : state.timeSlots.isEmpty
                            ? _EmptyTimeSlotsView(
                                hasServices: state.services.isNotEmpty,
                                serviceSelected: true,
                                onCreateTap: () =>
                                    _showTimeSlotFormSheet(context, state),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    AppSpacing.sm,
                                    AppSpacing.md,
                                    100),
                                itemCount: state.timeSlots.length,
                                itemBuilder: (context, index) {
                                  final slot = state.timeSlots[index];
                                  return Padding(
                                    key: ValueKey(slot['id']),
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.sm),
                                    child: _TimeSlotCard(
                                      slot: slot,
                                      onDelete: () =>
                                          _confirmDelete(context, state, slot),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),

          // FAB — disabled when no service selected or during submitting
          floatingActionButton: isSubmitting
              ? const FloatingActionButton(
                  onPressed: null,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FloatingActionButton(
                  onPressed: noServiceSelected
                      ? null
                      : () => _showTimeSlotFormSheet(context, state),
                  tooltip: context.l10n.expertTimeSlotCreate,
                  backgroundColor: noServiceSelected
                      ? Theme.of(context).disabledColor
                      : null,
                  child: const Icon(Icons.add),
                ),
        );
      },
    );
  }

  void _showTimeSlotFormSheet(
      BuildContext context, ExpertDashboardState state) {
    final serviceId = state.selectedServiceId;
    if (serviceId == null) return;

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _TimeSlotFormSheet(
        onSubmit: (data) {
          context.read<ExpertDashboardBloc>().add(
                ExpertDashboardCreateTimeSlot(serviceId, data),
              );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context,
      ExpertDashboardState state, Map<String, dynamic> slot) async {
    final serviceId = state.selectedServiceId;
    if (serviceId == null) return;

    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: context.l10n.expertTimeSlotConfirmDelete,
      isDestructive: true,
      onConfirm: () => true,
    );
    if (confirmed == true && context.mounted) {
      context.read<ExpertDashboardBloc>().add(
            ExpertDashboardDeleteTimeSlot(
              serviceId,
              slot['id']?.toString() ?? '',
            ),
          );
    }
  }
}

// =============================================================================
// Service dropdown
// =============================================================================

class _ServiceDropdown extends StatelessWidget {
  const _ServiceDropdown({
    required this.services,
    required this.selectedServiceId,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> services;
  final String? selectedServiceId;
  final void Function(String? serviceId) onChanged;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppSelectField<String>(
      value: selectedServiceId,
      hint: context.l10n.expertDashboardTabServices,
      sheetTitle: context.l10n.expertDashboardTabServices,
      clearable: false,
      options: services.map((s) {
        final id = s['id']?.toString() ?? '';
        final name = (s['service_name'] as String?) ?? id;
        return SelectOption(value: id, label: name);
      }).toList(),
      onChanged: onChanged,
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyTimeSlotsView extends StatelessWidget {
  const _EmptyTimeSlotsView({
    required this.hasServices,
    this.serviceSelected = false,
    this.onCreateTap,
  });

  final bool hasServices;
  final bool serviceSelected;
  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final message = serviceSelected
        ? context.l10n.expertTimeSlotsEmpty
        : context.l10n.expertTimeSlotsEmptyMessage;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (serviceSelected && onCreateTap != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.expertTimeSlotCreate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Time slot card
// =============================================================================

class _TimeSlotCard extends StatelessWidget {
  const _TimeSlotCard({
    required this.slot,
    required this.onDelete,
  });

  final Map<String, dynamic> slot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slotDate = (slot['slot_date'] as String?) ?? '';
    final startTime = _trimSeconds(slot['start_time'] as String? ?? '');
    final endTime = _trimSeconds(slot['end_time'] as String? ?? '');
    final price = (slot['price_per_participant'] as num?)?.toDouble() ?? 0.0;
    final currency = (slot['currency'] as String?) ?? AppConstants.defaultCurrency;
    final maxParticipants = (slot['max_participants'] as num?)?.toInt() ?? 0;
    final currentParticipants =
        (slot['current_participants'] as num?)?.toInt() ?? 0;
    final isExpired = slot['is_expired'] as bool? ?? false;
    final isAvailable = slot['is_available'] as bool? ?? true;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMedium,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Date + time column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date row
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        slotDate,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (isExpired) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _ExpiredBadge(),
                      ] else if (!isAvailable) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _UnavailableBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Time range
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 14,
                          color: AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Text(
                        '$startTime – $endTime',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Price + participants row
                  Row(
                    children: [
                      Text(
                        '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$currentParticipants / $maxParticipants',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete action
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: context.l10n.expertTimeSlotConfirmDelete,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  /// Trim ":SS" seconds suffix from "HH:MM:SS" → "HH:MM".
  String _trimSeconds(String t) {
    final parts = t.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return t;
  }
}

class _ExpiredBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.textSecondaryLight.withValues(alpha: 0.12),
        borderRadius: AppRadius.allSmall,
      ),
      child: Text(
        context.l10n.expertTimeSlotExpired,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

class _UnavailableBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: AppRadius.allSmall,
      ),
      child: Text(
        context.l10n.expertTimeSlotUnavailable,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.warning,
        ),
      ),
    );
  }
}

// =============================================================================
// Time slot form sheet
// =============================================================================

class _TimeSlotFormSheet extends StatefulWidget {
  const _TimeSlotFormSheet({required this.onSubmit});

  final void Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_TimeSlotFormSheet> createState() => _TimeSlotFormSheetState();
}

class _TimeSlotFormSheetState extends State<_TimeSlotFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _maxParticipantsController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  @override
  void dispose() {
    _priceController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _selectedStartTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ??
          (_selectedStartTime != null
              ? TimeOfDay(
                  hour: _selectedStartTime!.hour + 1,
                  minute: _selectedStartTime!.minute)
              : const TimeOfDay(hour: 10, minute: 0)),
    );
    if (picked != null) setState(() => _selectedEndTime = picked);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n
                .validatorFieldRequired(context.l10n.expertTimeSlotDate))),
      );
      return;
    }
    if (_selectedStartTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.validatorFieldRequired(
                context.l10n.expertTimeSlotStartTime))),
      );
      return;
    }
    if (_selectedEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.validatorFieldRequired(
                context.l10n.expertTimeSlotEndTime))),
      );
      return;
    }

    final start = _selectedStartTime!;
    final end = _selectedEndTime!;
    if (end.hour < start.hour ||
        (end.hour == start.hour && end.minute <= start.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expertTimeSlotEndAfterStart)),
      );
      return;
    }

    final data = <String, dynamic>{
      'slot_date': _formatDate(_selectedDate!),
      'start_time': _formatTime(_selectedStartTime!),
      'end_time': _formatTime(_selectedEndTime!),
      'price_per_participant':
          double.parse(_priceController.text.trim()),
      'max_participants': int.parse(_maxParticipantsController.text.trim()),
    };

    widget.onSubmit(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet title
              Padding(
                padding: const EdgeInsets.only(
                    bottom: AppSpacing.md, top: AppSpacing.sm),
                child: Text(
                  context.l10n.expertTimeSlotCreate,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),

              // Date picker row
              _DateTimePickerTile(
                label: context.l10n.expertTimeSlotDate,
                icon: Icons.calendar_today_outlined,
                displayText: _selectedDate != null
                    ? _formatDate(_selectedDate!)
                    : null,
                placeholder: 'YYYY-MM-DD',
                onTap: _pickDate,
              ),
              const SizedBox(height: AppSpacing.md),

              // Start time picker row
              _DateTimePickerTile(
                label: context.l10n.expertTimeSlotStartTime,
                icon: Icons.access_time_outlined,
                displayText: _selectedStartTime?.format(context),
                placeholder: '--:--',
                onTap: _pickStartTime,
              ),
              const SizedBox(height: AppSpacing.md),

              // End time picker row
              _DateTimePickerTile(
                label: context.l10n.expertTimeSlotEndTime,
                icon: Icons.access_time_outlined,
                displayText: _selectedEndTime?.format(context),
                placeholder: '--:--',
                onTap: _pickEndTime,
              ),
              const SizedBox(height: AppSpacing.md),

              // Price field
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertTimeSlotPrice,
                  border: const OutlineInputBorder(),
                  prefixText: '${Helpers.currencySymbolFor(AppConstants.defaultCurrency)} ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertTimeSlotPrice);
                  }
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertTimeSlotPrice);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Max participants field
              TextFormField(
                controller: _maxParticipantsController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertTimeSlotMaxParticipants,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertTimeSlotMaxParticipants);
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertTimeSlotMaxParticipants);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit
              FilledButton(
                onPressed: _submit,
                child: Text(context.l10n.commonSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Date/time picker tile
// =============================================================================

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
    required this.label,
    required this.icon,
    required this.displayText,
    required this.placeholder,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String? displayText;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasValue = displayText != null;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: Icon(icon),
        ),
        child: Text(
          hasValue ? displayText! : placeholder,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasValue
                    ? null
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
        ),
      ),
    );
  }
}
