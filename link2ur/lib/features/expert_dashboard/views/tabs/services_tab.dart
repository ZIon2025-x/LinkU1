import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/expert_constants.dart';
import '../../../../core/utils/service_category_helper.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/currency_selector.dart';
import '../../../../core/widgets/location_picker.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/adaptive_dialogs.dart';
import '../../../../core/widgets/app_select_sheet.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/localized_string.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/sheet_adaptation.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../bloc/expert_dashboard_bloc.dart';
import '../../bloc/selected_expert_cubit.dart';

/// Services tab for the Expert Dashboard — lists services with create/edit/delete.
class ServicesTab extends StatelessWidget {
  const ServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.services != curr.services || prev.status != curr.status,
      builder: (context, state) {
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

        final canManage =
            context.read<SelectedExpertCubit>().state.canManage;

        return Scaffold(
          body: state.services.isEmpty
              ? _EmptyServicesView(
                  onCreateTap: canManage
                      ? () => _showServiceFormSheet(context)
                      : null,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
                  itemCount: state.services.length,
                  itemBuilder: (context, index) {
                    final service = state.services[index];
                    return Padding(
                      key: ValueKey(service['id']),
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _ServiceCard(
                        service: service,
                        canManage: canManage,
                        onEdit: () =>
                            _showServiceFormSheet(context, service: service),
                        onToggleStatus: () =>
                            context.read<ExpertDashboardBloc>().add(
                                  ExpertDashboardToggleServiceStatus(
                                      service['id']?.toString() ?? ''),
                                ),
                        onDelete: () =>
                            _confirmDelete(context, service),
                      ),
                    );
                  },
                ),
          floatingActionButton: !canManage
              ? null
              : Builder(
                  builder: (ctx) {
                    final submitting = ctx.select<ExpertDashboardBloc, bool>(
                      (bloc) => bloc.state.status == ExpertDashboardStatus.submitting,
                    );
                    return FloatingActionButton(
                      onPressed: submitting ? null : () => _showServiceFormSheet(context),
                      tooltip: context.l10n.expertServiceCreate,
                      child: submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showServiceFormSheet(BuildContext context,
      {Map<String, dynamic>? service}) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ServiceFormSheet(
        existingService: service,
        onSubmit: (data) {
          if (service == null) {
            context
                .read<ExpertDashboardBloc>()
                .add(ExpertDashboardCreateService(data));
          } else {
            context.read<ExpertDashboardBloc>().add(
                  ExpertDashboardUpdateService(
                      service['id']?.toString() ?? '', data),
                );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> service) async {
    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: context.l10n.expertServiceConfirmDelete,
      content: context.l10n.expertServiceConfirmDeleteMessage,
      isDestructive: true,
      onConfirm: () => true,
    );
    if (confirmed == true && context.mounted) {
      context.read<ExpertDashboardBloc>().add(
            ExpertDashboardDeleteService(service['id']?.toString() ?? ''),
          );
    }
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyServicesView extends StatelessWidget {
  const _EmptyServicesView({this.onCreateTap});

  final VoidCallback? onCreateTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.design_services_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.expertServicesEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.expertServicesEmptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
            if (onCreateTap != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onCreateTap,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.expertServiceCreate),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Service card
// =============================================================================

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
    required this.canManage,
  });

  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final name = localizedString(
      service['service_name_zh'] as String?,
      service['service_name_en'] as String?,
      (service['service_name'] as String?) ?? '',
      locale,
    );
    final price = (service['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (service['currency'] as String?) ?? 'GBP';
    final status = (service['status'] as String?) ?? 'pending';
    final images = service['images'] as List<dynamic>?;
    final firstImage =
        (images != null && images.isNotEmpty) ? images.first as String? : null;

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
            // Thumbnail placeholder or image
            _ServiceThumbnail(imageUrl: firstImage),
            const SizedBox(width: AppSpacing.md),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$currency ${price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _StatusBadge(status: status),
                ],
              ),
            ),
            // Actions menu
            if (canManage)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'toggle') onToggleStatus();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(context.l10n.expertServiceEdit),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: ListTile(
                      leading: Icon(
                        status == 'active'
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      title: Text(
                        status == 'active'
                            ? context.l10n.expertServiceDelist
                            : context.l10n.expertServiceActivate,
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error),
                      title: Text(
                        context.l10n.expertServiceDelete,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceThumbnail extends StatelessWidget {
  const _ServiceThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: AppRadius.allSmall,
      child: Container(
        width: 60,
        height: 60,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.design_services_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              )
            : const Icon(
                Icons.design_services_outlined,
                size: 28,
                color: AppColors.primary,
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'active' => (context.l10n.expertServiceStatusActive, AppColors.success),
      'pending' => (
          context.l10n.expertServiceStatusPending,
          AppColors.warning
        ),
      'rejected' => (
          context.l10n.expertServiceStatusRejected,
          AppColors.error
        ),
      'inactive' => (
          context.l10n.expertServiceStatusInactive,
          AppColors.textSecondaryLight
        ),
      _ => (status, AppColors.textSecondaryLight),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.allSmall,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// Service form sheet
// =============================================================================

class _ServiceFormSheet extends StatefulWidget {
  const _ServiceFormSheet({
    this.existingService,
    required this.onSubmit,
  });

  final Map<String, dynamic>? existingService;
  final void Function(Map<String, dynamic> data) onSubmit;

  @override
  State<_ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends State<_ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _nameEnController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _descEnController;
  late final TextEditingController _priceController;
  late String _selectedCurrency;
  String? _selectedCategory;
  String _pricingType = 'fixed';
  String _locationType = 'online';
  String? _location;
  double? _latitude;
  double? _longitude;
  int? _serviceRadiusKm;
  bool _showEnglish = false;

  static const _nameMaxLength = 100;
  static const _descMaxLength = 2000;

  @override
  void initState() {
    super.initState();
    final s = widget.existingService;
    _nameController =
        TextEditingController(text: s?['service_name'] as String? ?? '');
    _nameEnController =
        TextEditingController(text: s?['service_name_en'] as String? ?? '');
    _descriptionController =
        TextEditingController(text: s?['description'] as String? ?? '');
    _descEnController =
        TextEditingController(text: s?['description_en'] as String? ?? '');
    final existingPrice = s?['base_price'] as num?;
    _priceController = TextEditingController(
      text: existingPrice != null ? existingPrice.toStringAsFixed(2) : '',
    );
    _selectedCurrency =
        (s?['currency'] as String?) ?? ExpertConstants.serviceCurrencies.first;
    _selectedCategory = s?['category'] as String?;
    _pricingType = (s?['pricing_type'] as String?) ?? 'fixed';
    _locationType = (s?['location_type'] as String?) ?? 'online';
    _location = s?['location'] as String?;
    _latitude = (s?['latitude'] as num?)?.toDouble();
    _longitude = (s?['longitude'] as num?)?.toDouble();
    _serviceRadiusKm = s?['service_radius_km'] as int?;

    // Auto-expand English section if editing and has English content
    if (_nameEnController.text.isNotEmpty ||
        _descEnController.text.isNotEmpty) {
      _showEnglish = true;
    }

    _nameController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _descEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingService != null;

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'pricing_type': _pricingType,
      'currency': _selectedCurrency,
      'location_type': _locationType,
    };

    if (_pricingType != 'negotiable') {
      data['base_price'] = double.parse(_priceController.text.trim());
    }

    if (_selectedCategory != null) {
      data['category'] = _selectedCategory;
    }

    if (_locationType != 'online') {
      if (_location != null && _location!.isNotEmpty) {
        data['location'] = _location;
      }
      if (_latitude != null) data['latitude'] = _latitude;
      if (_longitude != null) data['longitude'] = _longitude;
      // Always send service_radius_km on edit (null = inherit team default)
      if (_isEditing || _serviceRadiusKm != null) {
        data['service_radius_km'] = _serviceRadiusKm;
      }
    }

    final nameEn = _nameEnController.text.trim();
    if (nameEn.isNotEmpty) data['service_name_en'] = nameEn;
    final descEn = _descEnController.text.trim();
    if (descEn.isNotEmpty) data['description_en'] = descEn;

    widget.onSubmit(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.4,
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
              // Sheet header with close button
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 4),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      _isEditing
                          ? context.l10n.expertServiceEdit
                          : context.l10n.expertServiceCreate,
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

              // ── Service name ──
              _SectionLabel(
                label: context.l10n.expertServiceName,
                isRequired: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hintText: context.l10n.expertServiceNameHint,
                ),
                maxLength: _nameMaxLength,
                buildCounter: _buildCharCounter,
                style: const TextStyle(fontSize: 15),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertServiceName);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Description ──
              _SectionLabel(
                label: context.l10n.expertServiceDescription,
                isRequired: true,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration(
                  hintText: context.l10n.expertServiceDescriptionHint,
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                maxLength: _descMaxLength,
                buildCounter: _buildCharCounter,
                style: const TextStyle(fontSize: 15, height: 1.5),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 20),

              // ── Bilingual toggle ──
              GestureDetector(
                onTap: () => setState(() => _showEnglish = !_showEnglish),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36,
                        height: 20,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: _showEnglish
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF3A3A3C)
                                  : const Color(0xFFE0E0E0)),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _showEnglish
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.expertServiceAddEnglish,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── English fields (collapsible) ──
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                crossFadeState: _showEnglish
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _SectionLabel(
                      label: context.l10n.expertServiceNameEnShort,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameEnController,
                      decoration: _inputDecoration(
                        hintText: 'e.g. Professional PPT Design',
                      ),
                      style: const TextStyle(fontSize: 15),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(
                      label: context.l10n.expertServiceDescEnShort,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descEnController,
                      decoration: _inputDecoration(
                        hintText: 'Describe your service in English...',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Category ──
              _SectionLabel(
                label: context.l10n.serviceCategory,
                isRequired: true,
              ),
              const SizedBox(height: 8),
              AppSelectField<String>(
                value: _selectedCategory,
                hint: context.l10n.serviceCategoryHint,
                sheetTitle: context.l10n.serviceCategory,
                options: ExpertConstants.serviceCategoryKeys
                    .map((key) => SelectOption(
                          value: key,
                          label: ServiceCategoryHelper.getLocalizedLabel(
                              key, context.l10n),
                          icon: ServiceCategoryHelper.getIcon(key),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: 20),

              // ── Pricing type ──
              _SectionLabel(
                label: context.l10n.expertServicePrice,
                isRequired: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'fixed',
                      label: Text(context.l10n.personalServicePricingFixed),
                      icon: const Icon(Icons.attach_money, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'negotiable',
                      label: Text(context.l10n.personalServicePricingNegotiable),
                      icon: const Icon(Icons.handshake_outlined, size: 18),
                    ),
                  ],
                  selected: {_pricingType},
                  onSelectionChanged: (selected) {
                    setState(() => _pricingType = selected.first);
                  },
                  showSelectedIcon: false,
                ),
              ),
              if (_pricingType != 'negotiable') ...[
                const SizedBox(height: 12),
                CurrencySelector(
                  selected: _selectedCurrency,
                  onChanged: (v) => setState(() => _selectedCurrency = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  decoration: _inputDecoration(
                    hintText: '0.00',
                  ).copyWith(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      child: Text(
                        Helpers.currencySymbolFor(_selectedCurrency),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: const TextStyle(fontSize: 15),
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.validatorFieldRequired(
                          context.l10n.expertServicePrice);
                    }
                    final parsed = double.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return context.l10n.validatorFieldRequired(
                          context.l10n.expertServicePrice);
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),

              // ── Location type ──
              _SectionLabel(
                label: context.l10n.personalServiceLocation,
                isRequired: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment<String>(
                      value: 'online',
                      label: Text(context.l10n.personalServiceLocationOnline),
                      icon: const Icon(Icons.language, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'in_person',
                      label: Text(context.l10n.personalServiceLocationInPerson),
                      icon: const Icon(Icons.location_on_outlined, size: 18),
                    ),
                    ButtonSegment<String>(
                      value: 'both',
                      label: Text(context.l10n.personalServiceLocationBoth),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                    ),
                  ],
                  selected: {_locationType},
                  onSelectionChanged: (selected) {
                    setState(() {
                      _locationType = selected.first;
                      if (_locationType == 'online') {
                        _location = null;
                        _latitude = null;
                        _longitude = null;
                        _serviceRadiusKm = null;
                      }
                    });
                  },
                  showSelectedIcon: false,
                ),
              ),
              if (_locationType == 'in_person' || _locationType == 'both') ...[
                const SizedBox(height: 12),
                LocationInputField(
                  initialValue: _location,
                  initialLatitude: _latitude,
                  initialLongitude: _longitude,
                  showOnlineOption: false,
                  onChanged: (value) {
                    _location = value;
                  },
                  onLocationPicked: (address, lat, lng) {
                    _location = address;
                    _latitude = lat;
                    _longitude = lng;
                  },
                ),
                const SizedBox(height: 16),
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
                          setState(() => _serviceRadiusKm = selected ? r : null);
                        },
                      );
                    }),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // ── Submit button ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF409CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submit,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _isEditing
                            ? context.l10n.commonSave
                            : context.l10n.commonSubmit,
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

              // ── Tips box ──
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          context.l10n.expertServiceTipsTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _TipItem(text: context.l10n.expertServiceTip1),
                    _TipItem(text: context.l10n.expertServiceTip2),
                    _TipItem(text: context.l10n.expertServiceTip3),
                  ],
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
// Shared form widgets
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.isRequired = false});

  final String label;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isRequired)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              '*',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb, size: 12, color: AppColors.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
