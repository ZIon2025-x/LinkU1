import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/utils/sheet_adaptation.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../data/repositories/task_expert_repository.dart';

/// 达人套餐管理页
///
/// 套餐 = `package_type != 'single'` 的服务（multi 多课时 / bundle 服务包）。
/// 复用 services CRUD endpoints，但 UI 仅显示套餐字段。
class PackagesView extends StatefulWidget {
  const PackagesView({super.key, required this.expertId});
  final String expertId;

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = await context
          .read<TaskExpertRepository>()
          .getExpertManagedServices(widget.expertId);
      if (!mounted) return;
      setState(() {
        _packages = services
            .where((s) {
              final pkgType = s['package_type'] as String?;
              return pkgType != null && pkgType != 'single';
            })
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _createPackage(Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await context
          .read<TaskExpertRepository>()
          .createService(widget.expertId, data);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.expertPackageCreated)),
      );
      await _loadPackages();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _updatePackage(int serviceId, Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _submitting = true);
    try {
      await context
          .read<TaskExpertRepository>()
          .updateService(widget.expertId, serviceId, data);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.expertPackageUpdated)),
      );
      await _loadPackages();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deletePackage(int serviceId) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final repo = context.read<TaskExpertRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.expertPackageConfirmDelete),
        content: Text(l10n.expertPackageConfirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.commonDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    try {
      await repo.deleteService(widget.expertId, serviceId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.expertPackageDeleted)),
      );
      await _loadPackages();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFormSheet({Map<String, dynamic>? existing}) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PackageFormSheet(
        existing: existing,
        onSubmit: (data) {
          if (existing == null) {
            _createPackage(data);
          } else {
            _updatePackage(existing['id'] as int, data);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertManagementPackages)),
      floatingActionButton: _submitting
          ? const FloatingActionButton(
              onPressed: null,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FloatingActionButton(
              onPressed: () => _showFormSheet(),
              tooltip: context.l10n.expertPackageCreate,
              child: const Icon(Icons.add),
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.localizeError(_error!)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadPackages,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_packages.isEmpty) {
      return EmptyStateView(
        icon: Icons.inventory_2_outlined,
        title: context.l10n.expertPackageEmpty,
        message: context.l10n.expertPackageEmptyMessage,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadPackages,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          100,
        ),
        itemCount: _packages.length,
        itemBuilder: (context, index) {
          final pkg = _packages[index];
          return Padding(
            key: ValueKey(pkg['id']),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _PackageCard(
              package: pkg,
              onEdit: () => _showFormSheet(existing: pkg),
              onDelete: () => _deletePackage(pkg['id'] as int),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Package Card
// =============================================================================

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> package;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = package['service_name'] as String? ?? '';
    final pkgType = package['package_type'] as String? ?? 'multi';
    final totalSessions = (package['total_sessions'] as num?)?.toInt() ?? 0;
    final price = (package['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (package['currency'] as String?) ?? 'GBP';
    final status = (package['status'] as String?) ?? 'active';

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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
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
                  Row(
                    children: [
                      _PackageTypeBadge(type: pkgType),
                      const SizedBox(width: AppSpacing.xs),
                      if (pkgType == 'multi' && totalSessions > 0)
                        Text(
                          '× $totalSessions ${context.l10n.expertPackageSessions}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: status),
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
                    title: Text(context.l10n.commonEdit),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      context.l10n.commonDelete,
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

class _PackageTypeBadge extends StatelessWidget {
  const _PackageTypeBadge({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (type) {
      'multi' => (l10n.expertPackageTypeMulti, AppColors.primary),
      'bundle' => (l10n.expertPackageTypeBundle, AppColors.accent),
      _ => (type, AppColors.textSecondaryLight),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, color) = switch (status) {
      'active' => (l10n.expertServiceStatusActive, AppColors.success),
      'inactive' => (
          l10n.expertServiceStatusInactive,
          AppColors.textSecondaryLight,
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
// Form Sheet
// =============================================================================

class _PackageFormSheet extends StatefulWidget {
  const _PackageFormSheet({
    this.existing,
    required this.onSubmit,
  });

  final Map<String, dynamic>? existing;
  final void Function(Map<String, dynamic>) onSubmit;

  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _priceController;
  late final TextEditingController _sessionsController;
  String _packageType = 'multi';
  String _currency = 'GBP';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameController =
        TextEditingController(text: s?['service_name'] as String? ?? '');
    _descController =
        TextEditingController(text: s?['description'] as String? ?? '');
    final price = s?['base_price'] as num?;
    _priceController = TextEditingController(
      text: price != null ? price.toStringAsFixed(2) : '',
    );
    final sessions = s?['total_sessions'] as int?;
    _sessionsController =
        TextEditingController(text: sessions?.toString() ?? '');
    _packageType = (s?['package_type'] as String?) ?? 'multi';
    _currency = (s?['currency'] as String?) ?? 'GBP';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _sessionsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'base_price': double.parse(_priceController.text.trim()),
      'currency': _currency,
      'package_type': _packageType,
    };
    if (_packageType == 'multi') {
      data['total_sessions'] = int.parse(_sessionsController.text.trim());
    }

    widget.onSubmit(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _isEditing
                      ? l10n.expertPackageEdit
                      : l10n.expertPackageCreate,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),

              // Package type
              Text(
                l10n.expertPackageType,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'multi',
                    label: Text(l10n.expertPackageTypeMulti),
                    icon: const Icon(Icons.event_repeat, size: 18),
                  ),
                  ButtonSegment(
                    value: 'bundle',
                    label: Text(l10n.expertPackageTypeBundle),
                    icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  ),
                ],
                selected: {_packageType},
                onSelectionChanged: (selected) {
                  setState(() => _packageType = selected.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.expertPackageName,
                  border: const OutlineInputBorder(),
                ),
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.validatorFieldRequired(l10n.expertPackageName);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: l10n.expertPackageDescription,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 2000,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.validatorFieldRequired(
                        l10n.expertPackageDescription);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Sessions count (multi only)
              if (_packageType == 'multi') ...[
                TextFormField(
                  controller: _sessionsController,
                  decoration: InputDecoration(
                    labelText: l10n.expertPackageSessionCount,
                    helperText: l10n.expertPackageSessionCountHint,
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.validatorFieldRequired(
                          l10n.expertPackageSessionCount);
                    }
                    final n = int.tryParse(value.trim());
                    if (n == null || n <= 0) {
                      return l10n.validatorFieldRequired(
                          l10n.expertPackageSessionCount);
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Price
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: l10n.expertPackagePrice,
                  prefixText: '${Helpers.currencySymbolFor(_currency)} ',
                  border: const OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.validatorFieldRequired(l10n.expertPackagePrice);
                  }
                  final p = double.tryParse(value.trim());
                  if (p == null || p <= 0) {
                    return l10n.validatorFieldRequired(l10n.expertPackagePrice);
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? l10n.commonSave : l10n.commonSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
