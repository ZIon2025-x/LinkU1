import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/sheet_adaptation.dart';
import '../../../../core/utils/task_type_helper.dart';
import '../../../../core/widgets/location_picker.dart';
import '../../../../data/repositories/expert_team_repository.dart';
import '../../bloc/expert_dashboard_bloc.dart';
import '../../bloc/selected_expert_cubit.dart';

/// Activities tab for the Expert Dashboard — lets owners/admins publish
/// team activities linked to an existing active service.
class ActivitiesTab extends StatelessWidget {
  const ActivitiesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.services != curr.services ||
          prev.activities != curr.activities ||
          prev.status != curr.status,
      builder: (context, state) {
        if ((state.status == ExpertDashboardStatus.initial ||
                state.status == ExpertDashboardStatus.loading) &&
            state.activities.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          body: state.activities.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 64,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.l10n.expertActivitiesEmpty,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          context.l10n.expertActivitiesEmptyMessage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.activities.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final activity = state.activities[index];
                    return _ActivityListTile(
                      activity: activity,
                      expertId: context.read<SelectedExpertCubit>().state.currentExpertId,
                      repository: context.read<ExpertTeamRepository>(),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showActivityFormSheet(context, state.services),
            tooltip: context.l10n.expertActivityCreate,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showActivityFormSheet(
      BuildContext context, List<Map<String, dynamic>> services) {
    final expertId =
        context.read<SelectedExpertCubit>().state.currentExpertId;
    final repo = context.read<ExpertTeamRepository>();

    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActivityFormSheet(
        services: services,
        expertId: expertId,
        repository: repo,
        onSuccess: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.expertActivityPublished),
              ),
            );
          }
        },
      ),
    );
  }
}

// =============================================================================
// Activity form sheet
// =============================================================================

class _ActivityFormSheet extends StatefulWidget {
  const _ActivityFormSheet({
    required this.services,
    required this.expertId,
    required this.repository,
    required this.onSuccess,
  });

  final List<Map<String, dynamic>> services;
  final String expertId;
  final ExpertTeamRepository repository;
  final VoidCallback onSuccess;

  @override
  State<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<_ActivityFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _maxParticipantsController;
  late final TextEditingController _minParticipantsController;

  String? _location;
  double? _latitude;
  double? _longitude;
  int? _serviceRadiusKm;

  Map<String, dynamic>? _selectedService;
  String _taskType = 'other';
  DateTime? _deadline;
  bool _isSubmitting = false;
  String? _errorMessage;

  String _activityType = 'standard'; // 'standard' | 'lottery' | 'first_come'
  String _prizeType = 'physical';    // 'physical' | 'in_person'
  String _drawMode = 'auto';         // 'auto' | 'manual'
  String _drawTrigger = 'by_time';   // 'by_time' | 'by_count' | 'both'
  DateTime? _drawAt;
  late final TextEditingController _prizeDescriptionController;
  late final TextEditingController _prizeCountController;
  late final TextEditingController _drawParticipantCountController;

  static const _titleMaxLength = 100;
  static const _descMaxLength = 2000;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _maxParticipantsController = TextEditingController(text: '10');
    _minParticipantsController = TextEditingController(text: '1');
    _prizeDescriptionController = TextEditingController();
    _prizeCountController = TextEditingController(text: '3');
    _drawParticipantCountController = TextEditingController(text: '30');
    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _maxParticipantsController.dispose();
    _minParticipantsController.dispose();
    _prizeDescriptionController.dispose();
    _prizeCountController.dispose();
    _drawParticipantCountController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hintText,
    bool alignLabelWithHint = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 15,
      ),
      alignLabelWithHint: alignLabelWithHint,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : const Color(0xFFE0E0E0),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _pickDrawAt() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _drawAt ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_drawAt ?? now),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _drawAt = DateTime(
        pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadline == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivityDeadline));
      return;
    }
    if (_activityType == 'standard' && _selectedService == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivitySelectService));
      return;
    }
    if (_location == null || _location!.isEmpty) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.activityLocation));
      return;
    }
    if (_activityType == 'lottery' && _drawMode == 'auto' &&
        (_drawTrigger == 'by_time' || _drawTrigger == 'both') &&
        _drawAt == null) {
      setState(() => _errorMessage = context.l10n.validatorFieldRequired(
          context.l10n.expertActivityDrawAt));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final priceText = _priceController.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _location!,
      'task_type': _taskType,
      'deadline': _deadline!.toIso8601String(),
      'activity_type': _activityType,
      if (_selectedService != null) 'expert_service_id': _selectedService!['id'],
      if (price != null) 'original_price_per_participant': price,
      if (_latitude != null) 'latitude': _latitude,
      if (_longitude != null) 'longitude': _longitude,
      if (_serviceRadiusKm != null) 'service_radius_km': _serviceRadiusKm,
    };

    if (_activityType == 'standard') {
      data['max_participants'] =
          int.tryParse(_maxParticipantsController.text.trim()) ?? 10;
      data['min_participants'] =
          int.tryParse(_minParticipantsController.text.trim()) ?? 1;
    }

    if (_activityType != 'standard') {
      data['prize_type'] = _prizeType;
      data['prize_description'] = _prizeDescriptionController.text.trim();
      data['prize_count'] = int.tryParse(_prizeCountController.text.trim()) ?? 1;
    }

    if (_activityType == 'lottery') {
      data['draw_mode'] = _drawMode;
      if (_drawMode == 'auto') {
        data['draw_trigger'] = _drawTrigger;
        if (_drawTrigger == 'by_time' || _drawTrigger == 'both') {
          data['draw_at'] = _drawAt!.toUtc().toIso8601String();
        }
        if (_drawTrigger == 'by_count' || _drawTrigger == 'both') {
          data['draw_participant_count'] =
              int.tryParse(_drawParticipantCountController.text.trim()) ?? 30;
        }
      }
    }

    try {
      await widget.repository.createTeamActivity(widget.expertId, data);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
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

  Widget _buildActivityTypeSelector() {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final types = [
      ('standard', l10n.expertActivityTypeStandard, l10n.expertActivityTypeStandardDesc, Icons.event_outlined),
      ('lottery', l10n.expertActivityTypeLottery, l10n.expertActivityTypeLotteryDesc, Icons.casino_outlined),
      ('first_come', l10n.expertActivityTypeFirstCome, l10n.expertActivityTypeFirstComeDesc, Icons.bolt_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.expertActivityType, isRequired: true),
        const SizedBox(height: 8),
        ...types.map((t) {
          final (value, label, desc, icon) = t;
          final selected = _activityType == value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() => _activityType = value),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE0E0E0),
                    width: selected ? 2 : 1.5,
                  ),
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: selected ? AppColors.primary : null),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.primary : null,
                          )),
                          Text(desc, style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          )),
                        ],
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPrizeFields() {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.expertActivityPrizeType, isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityPrizePhysical),
                selected: _prizeType == 'physical',
                onSelected: (_) => setState(() => _prizeType = 'physical'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityPrizeInPerson),
                selected: _prizeType == 'in_person',
                onSelected: (_) => setState(() => _prizeType = 'in_person'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: l10n.expertActivityPrizeDescription, isRequired: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _prizeDescriptionController,
          decoration: _inputDecoration(
            hintText: l10n.expertActivityPrizeDescriptionHint,
            alignLabelWithHint: true,
          ),
          maxLines: 2,
          style: const TextStyle(fontSize: 15),
          validator: (value) {
            if (_activityType != 'standard' &&
                (value == null || value.trim().isEmpty)) {
              return l10n.validatorFieldRequired(l10n.expertActivityPrizeDescription);
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: l10n.expertActivityPrizeCount, isRequired: true),
        const SizedBox(height: 8),
        TextFormField(
          controller: _prizeCountController,
          decoration: _inputDecoration(hintText: '3'),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (_activityType != 'standard') {
              final n = int.tryParse(value ?? '');
              if (n == null || n < 1) {
                return l10n.validatorFieldRequired(l10n.expertActivityPrizeCount);
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDrawConfig() {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: l10n.expertActivityDrawMode, isRequired: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityDrawModeAuto),
                selected: _drawMode == 'auto',
                onSelected: (_) => setState(() => _drawMode = 'auto'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.expertActivityDrawModeManual),
                selected: _drawMode == 'manual',
                onSelected: (_) => setState(() => _drawMode = 'manual'),
              ),
            ),
          ],
        ),
        if (_drawMode == 'auto') ...[
          const SizedBox(height: 20),
          _SectionLabel(label: l10n.expertActivityDrawTrigger, isRequired: true),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerByTime),
                selected: _drawTrigger == 'by_time',
                onSelected: (_) => setState(() => _drawTrigger = 'by_time'),
              ),
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerByCount),
                selected: _drawTrigger == 'by_count',
                onSelected: (_) => setState(() => _drawTrigger = 'by_count'),
              ),
              ChoiceChip(
                label: Text(l10n.expertActivityDrawTriggerBoth),
                selected: _drawTrigger == 'both',
                onSelected: (_) => setState(() => _drawTrigger = 'both'),
              ),
            ],
          ),
          if (_drawTrigger == 'by_time' || _drawTrigger == 'both') ...[
            const SizedBox(height: 20),
            _SectionLabel(label: l10n.expertActivityDrawAt, isRequired: true),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDrawAt,
              borderRadius: AppRadius.allSmall,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _drawAt == null
                            ? l10n.expertActivityDrawAt
                            : '${_drawAt!.year}-${_drawAt!.month.toString().padLeft(2, '0')}-${_drawAt!.day.toString().padLeft(2, '0')} ${_drawAt!.hour.toString().padLeft(2, '0')}:${_drawAt!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 15,
                          color: _drawAt == null
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : null,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down,
                        color: isDark ? Colors.white54 : Colors.black45),
                  ],
                ),
              ),
            ),
          ],
          if (_drawTrigger == 'by_count' || _drawTrigger == 'both') ...[
            const SizedBox(height: 20),
            _SectionLabel(
              label: l10n.expertActivityDrawParticipantCount,
              isRequired: true,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _drawParticipantCountController,
              decoration: _inputDecoration(hintText: '30'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (_activityType == 'lottery' &&
                    _drawMode == 'auto' &&
                    (_drawTrigger == 'by_count' || _drawTrigger == 'both')) {
                  final n = int.tryParse(value ?? '');
                  final prizeCount = int.tryParse(_prizeCountController.text) ?? 0;
                  if (n == null || n <= prizeCount) {
                    return '${l10n.expertActivityDrawParticipantCount} > ${l10n.expertActivityPrizeCount}';
                  }
                }
                return null;
              },
            ),
          ],
        ],
      ],
    );
  }

  String _serviceLabel(Map<String, dynamic> service) {
    final name = (service['service_name'] as String?) ?? '';
    final price = (service['base_price'] as num?)?.toDouble();
    final currency = (service['currency'] as String?) ?? 'GBP';
    if (price != null) {
      return '$name ($currency ${Helpers.formatAmountNumber(price)})';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    // Only show active services for activity creation
    final activeServices = widget.services
        .where((s) => (s['status'] as String?) == 'active')
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Sheet header ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 4),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        context.l10n.expertActivityCreate,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 22),
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Error message ──
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.allSmall,
                    ),
                    child: Text(
                      context.localizeError(_errorMessage!),
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Activity type selector ──
                _buildActivityTypeSelector(),
                const SizedBox(height: 20),

                // ── Linked service ──
                if (_activityType == 'standard') ...[
                  _SectionLabel(
                    label: context.l10n.expertActivitySelectService,
                    isRequired: true,
                  ),
                  const SizedBox(height: 8),
                  if (activeServices.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: AppRadius.allSmall,
                      ),
                      child: Text(
                        context.l10n.expertServicesEmpty,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<Map<String, dynamic>>(
                      initialValue: _selectedService,
                      hint: Text(
                        context.l10n.expertActivitySelectServiceHint,
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 15,
                        ),
                      ),
                      decoration: _inputDecoration(
                          hintText: context.l10n.expertActivitySelectServiceHint),
                      items: activeServices
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  _serviceLabel(s),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedService = value),
                      validator: (value) {
                        if (value == null) {
                          return context.l10n.validatorFieldRequired(
                              context.l10n.expertActivitySelectService);
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 20),
                ] else if (activeServices.isNotEmpty) ...[
                  _SectionLabel(
                    label: context.l10n.expertActivityServiceOptional,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedService,
                    hint: Text(
                      context.l10n.expertActivitySelectServiceHint,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 15,
                      ),
                    ),
                    decoration: _inputDecoration(
                        hintText: context.l10n.expertActivitySelectServiceHint),
                    items: [
                      DropdownMenuItem<Map<String, dynamic>>(
                        value: null,
                        child: Text(context.l10n.expertActivityFree),
                      ),
                      ...activeServices
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  _serviceLabel(s),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedService = value),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Title ──
                _SectionLabel(
                  label: context.l10n.expertActivityTitle,
                  isRequired: true,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: _inputDecoration(
                    hintText: context.l10n.expertActivityTitleHint,
                  ),
                  maxLength: _titleMaxLength,
                  buildCounter: _buildCharCounter,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.validatorFieldRequired(
                          context.l10n.expertActivityTitle);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Description ──
                _SectionLabel(
                  label: context.l10n.expertActivityDescription,
                  isRequired: true,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(
                    hintText: context.l10n.expertActivityDescriptionHint,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: _descMaxLength,
                  buildCounter: _buildCharCounter,
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.newline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.validatorFieldRequired(
                          context.l10n.expertActivityDescription);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Prize fields (lottery / first_come only) ──
                if (_activityType != 'standard') ...[
                  _buildPrizeFields(),
                  const SizedBox(height: 20),
                ],

                // ── Draw config (lottery only) ──
                if (_activityType == 'lottery') ...[
                  _buildDrawConfig(),
                  const SizedBox(height: 20),
                ],

                // ── Task type ──
                _SectionLabel(
                  label: context.l10n.createTaskType,
                  isRequired: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _taskType,
                  decoration: _inputDecoration(hintText: ''),
                  items: AppConstants.taskTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              TaskTypeHelper.getLocalizedLabel(t, context.l10n),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _taskType = value);
                  },
                ),
                const SizedBox(height: 20),

                // ── Deadline ──
                _SectionLabel(
                  label: context.l10n.expertActivityDeadline,
                  isRequired: true,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDeadline,
                  borderRadius: AppRadius.allSmall,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : const Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _deadline == null
                                ? context.l10n.expertActivityDeadline
                                : '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 15,
                              color: _deadline == null
                                  ? (isDark
                                      ? Colors.white38
                                      : Colors.black38)
                                  : null,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: isDark
                                ? Colors.white54
                                : Colors.black45),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Participants (only for standard, or lottery by_time/manual) ──
                if (_activityType == 'standard' ||
                    (_activityType == 'lottery' &&
                     (_drawMode == 'manual' || _drawTrigger == 'by_time'))) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                              label: context.l10n.expertActivityMaxParticipants,
                              isRequired: true,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _maxParticipantsController,
                              decoration: _inputDecoration(hintText: '10'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: (value) {
                                final n = int.tryParse(value ?? '');
                                if (n == null || n < 1) {
                                  return context.l10n.validatorFieldRequired(
                                      context.l10n
                                          .expertActivityMaxParticipants);
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(
                              label: context.l10n.expertActivityMinParticipants,
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _minParticipantsController,
                              decoration: _inputDecoration(hintText: '1'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Price per participant ──
                _SectionLabel(
                  label: context.l10n.expertActivityPricePerParticipant,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceController,
                  decoration: _inputDecoration(hintText: '0.00'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),

                // ── Location ──
                _SectionLabel(
                  label: context.l10n.activityLocation,
                  isRequired: true,
                ),
                const SizedBox(height: 8),
                LocationInputField(
                  initialValue: _location,
                  initialLatitude: _latitude,
                  initialLongitude: _longitude,
                  onChanged: (value) => _location = value,
                  onLocationPicked: (address, lat, lng) {
                    setState(() {
                      _location = address;
                      _latitude = lat;
                      _longitude = lng;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // ── Service radius ──
                Text(
                  context.l10n.selectServiceRadius,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(context.l10n.inheritTeamDefault),
                      selected: _serviceRadiusKm == null,
                      onSelected: (selected) {
                        if (selected) setState(() => _serviceRadiusKm = null);
                      },
                    ),
                    ...[5, 10, 25, 50, 0].map((r) {
                      final label = r == 0
                          ? context.l10n.serviceRadiusWholeCity
                          : context.l10n.serviceRadiusKm(r);
                      return ChoiceChip(
                        label: Text(label),
                        selected: _serviceRadiusKm == r,
                        onSelected: (selected) {
                          setState(
                              () => _serviceRadiusKm = selected ? r : null);
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Submit button ──
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _isSubmitting
                        ? null
                        : const LinearGradient(
                            colors: [
                              AppColors.primary,
                              Color(0xFF409CFF)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    color: _isSubmitting ? Colors.grey : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isSubmitting ? null : _submit,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _isSubmitting
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                context.l10n.commonSubmit,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildCharCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$currentLength/$maxLength',
        style: TextStyle(
          fontSize: 11,
          color: currentLength > maxLength * 0.9
              ? AppColors.error
              : Theme.of(context).brightness == Brightness.dark
                  ? Colors.white30
                  : Colors.black26,
        ),
      ),
    );
  }
}

// =============================================================================
// Activity list tile
// =============================================================================

class _ActivityListTile extends StatefulWidget {
  const _ActivityListTile({
    required this.activity,
    required this.expertId,
    required this.repository,
  });

  final Map<String, dynamic> activity;
  final String expertId;
  final ExpertTeamRepository repository;

  @override
  State<_ActivityListTile> createState() => _ActivityListTileState();
}

class _ActivityListTileState extends State<_ActivityListTile> {
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final title = (a['title'] as String?) ?? '';
    final activityType = (a['activity_type'] as String?) ?? 'standard';
    final isDrawn = a['is_drawn'] == true;
    final status = (a['status'] as String?) ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    final isLottery = activityType == 'lottery';
    final isFirstCome = activityType == 'first_come';

    // Badge text
    String badgeText;
    Color badgeColor;
    if (isLottery) {
      badgeText = l10n.expertActivityTypeLottery;
      badgeColor = Colors.orange;
    } else if (isFirstCome) {
      badgeText = l10n.expertActivityTypeFirstCome;
      badgeColor = Colors.green;
    } else {
      badgeText = l10n.expertActivityTypeStandard;
      badgeColor = AppColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8E8E8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'open'
                      ? Colors.green.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: status == 'open' ? Colors.green : Colors.grey,
                  ),
                ),
              ),
              if (isLottery && isDrawn) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    l10n.activityDrawCompleted,
                    style: const TextStyle(fontSize: 11, color: Colors.purple),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Draw button for undone lottery activities
          if (isLottery && !isDrawn && status == 'open') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDrawing ? null : () => _handleDraw(context),
                icon: _isDrawing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.casino_outlined, size: 18),
                label: Text(l10n.expertActivityManualDraw),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleDraw(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final bloc = context.read<ExpertDashboardBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertActivityManualDraw),
        content: Text(l10n.expertActivityManualDrawConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDrawing = true);
    try {
      final activityId = widget.activity['id'] as int;
      final result = await widget.repository.drawTeamActivity(
        widget.expertId,
        activityId,
      );
      if (mounted) {
        final count = result['winner_count'] as int? ?? 0;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.expertActivityDrawSuccess(count))),
        );
        // Refresh the activities list
        bloc.add(const ExpertDashboardLoadActivities());
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isDrawing = false);
    }
  }
}

// =============================================================================
// Helpers
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RichText(
      text: TextSpan(
        text: label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
        children: isRequired
            ? [
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
              ]
            : [],
      ),
    );
  }
}
