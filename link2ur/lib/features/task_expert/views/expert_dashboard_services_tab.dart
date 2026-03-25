import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/expert_constants.dart';
import '../../../core/utils/service_category_helper.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/widgets/error_state_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// Services tab for the Expert Dashboard — lists services with create/edit/delete.
class ExpertDashboardServicesTab extends StatelessWidget {
  const ExpertDashboardServicesTab({super.key});

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

        return Scaffold(
          body: state.services.isEmpty
              ? _EmptyServicesView(
                  onCreateTap: () => _showServiceFormSheet(context),
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
                        onEdit: () =>
                            _showServiceFormSheet(context, service: service),
                        onDelete: () =>
                            _confirmDelete(context, service),
                      ),
                    );
                  },
                ),
          // Fix 2: Disable FAB during submitting status
          floatingActionButton: context.select<ExpertDashboardBloc, bool>(
            (bloc) =>
                bloc.state.status == ExpertDashboardStatus.submitting,
          )
              ? const FloatingActionButton(
                  onPressed: null,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FloatingActionButton(
                  onPressed: () => _showServiceFormSheet(context),
                  tooltip: context.l10n.expertServiceCreate,
                  child: const Icon(Icons.add),
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
      showDragHandle: true,
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
  const _EmptyServicesView({required this.onCreateTap});

  final VoidCallback onCreateTap;

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
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.expertServiceCreate),
            ),
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
  });

  final Map<String, dynamic> service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (service['service_name'] as String?) ?? '';
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
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _descEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingService != null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'base_price': double.parse(_priceController.text.trim()),
      'currency': _selectedCurrency,
    };

    if (_selectedCategory != null) {
      data['category'] = _selectedCategory;
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
                  _isEditing
                      ? context.l10n.expertServiceEdit
                      : context.l10n.expertServiceCreate,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),

              // Service name (required)
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertServiceName,
                  hintText: context.l10n.expertServiceNameHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.validatorFieldRequired(
                        context.l10n.expertServiceName);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Service name (English, optional)
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertServiceNameEn,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertServiceDescription,
                  hintText: context.l10n.expertServiceDescriptionHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description (English, optional)
              TextFormField(
                controller: _descEnController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertServiceDescriptionEn,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.md),

              // Category
              AppSelectField<String>(
                value: _selectedCategory,
                hint: context.l10n.serviceCategoryHint,
                label: context.l10n.serviceCategory,
                sheetTitle: context.l10n.serviceCategory,
                options: ExpertConstants.serviceCategoryKeys
                    .map((key) => SelectOption(
                          value: key,
                          label: ServiceCategoryHelper.getLocalizedLabel(key, context.l10n),
                          icon: ServiceCategoryHelper.getIcon(key),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Price + currency row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: context.l10n.expertServicePrice,
                        hintText: context.l10n.expertServicePriceHint,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
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
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: AppSelectField<String>(
                      value: _selectedCurrency,
                      hint: context.l10n.expertServiceCurrency,
                      sheetTitle: context.l10n.expertServiceCurrency,
                      searchThreshold: 99,
                      clearable: false,
                      options: ExpertConstants.serviceCurrencies
                          .map((c) => SelectOption(value: c, label: c))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCurrency = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit button
              FilledButton(
                onPressed: _submit,
                child: Text(_isEditing
                    ? context.l10n.commonSave
                    : context.l10n.commonSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
