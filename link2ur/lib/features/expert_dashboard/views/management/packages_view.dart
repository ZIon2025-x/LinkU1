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
/// 套餐 = `package_type IN ('multi', 'bundle')` 的服务。
/// NULL = 普通单次服务（不在此页显示，走 apply + Task 流程）。
/// 旧值 'single' 已下线（migration 197），读取端仍兼容。
/// 复用 services CRUD endpoints，但 UI 仅显示套餐字段。
class PackagesView extends StatefulWidget {
  const PackagesView({super.key, required this.expertId});
  final String expertId;

  @override
  State<PackagesView> createState() => _PackagesViewState();
}

class _PackagesViewState extends State<PackagesView> {
  List<Map<String, dynamic>> _packages = [];
  List<Map<String, dynamic>> _rawServices = [];
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
        _rawServices = services;
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
      messenger.showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
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
      messenger.showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
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
      messenger.showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showFormSheet({Map<String, dynamic>? existing}) {
    // 用当前加载的 services 做 bundle 子服务候选（只保留 single + active）
    final singleServices = _allSingleServices();
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _PackageFormSheet(
        existing: existing,
        singleServices: singleServices,
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

  /// 当前团队可以被 bundle 引用的单次服务
  /// (package_type == 'single' 或 null，且 status == 'active')
  List<Map<String, dynamic>> _allSingleServices() {
    // _packages 已经被过滤成 package_type != single；这里需要原始列表。
    // 重新从 _rawServices 取。
    return _rawServices.where((s) {
      final pkgType = s['package_type'] as String?;
      final status = s['status'] as String?;
      final isSingle = pkgType == null || pkgType == 'single';
      return isSingle && status == 'active';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertManagementPackages)),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitting ? null : () => _showFormSheet(),
        tooltip: context.l10n.expertPackageCreate,
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.add),
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
    required this.singleServices,
  });

  final Map<String, dynamic>? existing;
  final void Function(Map<String, dynamic>) onSubmit;

  /// 可以被 bundle 套餐引用的单次服务候选列表
  final List<Map<String, dynamic>> singleServices;

  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _packagePriceController;
  late final TextEditingController _basePriceController;
  late final TextEditingController _sessionsController;
  late final TextEditingController _validityDaysController;
  String _packageType = 'multi';
  String _currency = 'GBP';

  /// multi 套餐可选关联服务 id (null = 不关联，即自包含套餐)
  int? _linkedServiceId;

  /// bundle 子服务选择: serviceId -> count
  final Map<int, int> _bundleSelections = {};

  bool get _isEditing => widget.existing != null;

  /// 关联型 multi 套餐：多次套餐 + 选择了具体关联服务
  /// 此时 description/base_price/images/location/time_slots 等字段由后端从关联服务继承，
  /// 前端表单不再显示这些字段，减少卖家填写负担。
  bool get _isLinkedMulti =>
      _packageType == 'multi' && _linkedServiceId != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _nameController =
        TextEditingController(text: s?['service_name'] as String? ?? '');
    _descController =
        TextEditingController(text: s?['description'] as String? ?? '');
    final basePrice = s?['base_price'] as num?;
    _basePriceController = TextEditingController(
      text: basePrice != null ? basePrice.toStringAsFixed(2) : '',
    );
    final pkgPrice = s?['package_price'] as num?;
    _packagePriceController = TextEditingController(
      text: pkgPrice != null ? pkgPrice.toStringAsFixed(2) : '',
    );
    final sessions = s?['total_sessions'] as int?;
    _sessionsController =
        TextEditingController(text: sessions?.toString() ?? '');
    final validity = s?['validity_days'] as int?;
    _validityDaysController =
        TextEditingController(text: validity?.toString() ?? '');
    _packageType = (s?['package_type'] as String?) ?? 'multi';
    _currency = (s?['currency'] as String?) ?? 'GBP';
    final initLinked = s?['linked_service_id'] as int?;
    // 只有当初始值在候选列表里时才保留，否则置 null（避免 DropdownButton value 不在 items 中导致抛错）
    _linkedServiceId = initLinked != null &&
            widget.singleServices.any((svc) => svc['id'] == initLinked)
        ? initLinked
        : null;

    // 回填 bundle 选择
    final existingBundle = s?['bundle_service_ids'];
    if (existingBundle is List) {
      for (final item in existingBundle) {
        if (item is int) {
          _bundleSelections[item] = (_bundleSelections[item] ?? 0) + 1;
        } else if (item is Map) {
          final sid = item['service_id'];
          final cnt = item['count'];
          if (sid is int && cnt is int && cnt > 0) {
            _bundleSelections[sid] = cnt;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _packagePriceController.dispose();
    _basePriceController.dispose();
    _sessionsController.dispose();
    _validityDaysController.dispose();
    super.dispose();
  }

  /// 多次套餐关联服务下拉
  /// - 候选 = singleServices（package_type=NULL 的服务）
  /// - 选中后提示可用此服务的 base_price 作为"单次原价"，点一下自动填充到 base 输入框
  Widget _buildLinkedServicePicker(BuildContext context) {
    if (_packageType != 'multi') return const SizedBox.shrink();
    final l10n = context.l10n;
    final services = widget.singleServices;
    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 16, color: AppColors.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.expertPackageLinkedServiceEmpty,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    // 被选中服务的 base_price（展示用）
    final selected = _linkedServiceId == null
        ? null
        : services.firstWhere(
            (s) => s['id'] == _linkedServiceId,
            orElse: () => const {},
          );
    final selectedBase = (selected?['base_price'] as num?)?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int?>(
          initialValue: _linkedServiceId,
          decoration: InputDecoration(
            labelText: l10n.expertPackageLinkedService,
            helperText: l10n.expertPackageLinkedServiceHint,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          isExpanded: true,
          items: [
            DropdownMenuItem<int?>(
              child: Text(l10n.expertPackageLinkedServiceNone),
            ),
            ...services.map((s) {
              final id = s['id'] as int;
              final name = (s['service_name'] as String?) ??
                  (s['name'] as String?) ??
                  '#$id';
              final base = (s['base_price'] as num?)?.toDouble();
              final priceStr = base != null
                  ? ' · ${Helpers.currencySymbolFor(_currency)}${base.toStringAsFixed(2)}'
                  : '';
              return DropdownMenuItem<int?>(
                value: id,
                child: Text(
                  '$name$priceStr',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _linkedServiceId = val);
            // 选中关联服务时，自动把套餐名预填为关联服务名（可改）
            if (val != null) {
              final svc = widget.singleServices.firstWhere(
                (s) => s['id'] == val,
                orElse: () => const {},
              );
              final linkedName = (svc['service_name'] as String?) ??
                  (svc['name'] as String?) ??
                  '';
              if (_nameController.text.trim().isEmpty && linkedName.isNotEmpty) {
                _nameController.text = linkedName;
              }
            }
          },
        ),
        // 快速动作：用选中服务的 base_price 填充"单次原价"
        if (selectedBase != null && selectedBase > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  _basePriceController.text = selectedBase.toStringAsFixed(2);
                  setState(() {});
                },
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text(l10n.expertPackageLinkedServiceUseBase),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 30),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// multi 套餐实时折扣预览块
  /// - 总价、次数、原价（base）均可解析时显示
  /// - 若 base > 每次均价 超过 0.5 分，显示红色立省徽章
  Widget _buildDiscountPreview(BuildContext context) {
    if (_packageType != 'multi') return const SizedBox.shrink();
    final pkgPrice = double.tryParse(_packagePriceController.text.trim());
    final sessions = int.tryParse(_sessionsController.text.trim());
    if (pkgPrice == null || pkgPrice <= 0 || sessions == null || sessions < 2) {
      return const SizedBox.shrink();
    }
    final perSessionAvg = pkgPrice / sessions;
    final basePrice = double.tryParse(_basePriceController.text.trim());
    final hasUserBase = basePrice != null && basePrice > 0;
    final showDiscount =
        hasUserBase && basePrice > perSessionAvg + 0.005;
    final savedTotal = showDiscount
        ? (basePrice - perSessionAvg) * sessions
        : 0.0;
    final percent = showDiscount
        ? ((1 - perSessionAvg / basePrice) * 100).round()
        : 0;

    final l10n = context.l10n;
    final symbol = Helpers.currencySymbolFor(_currency);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  l10n.packagePurchasePerSessionValue(
                      symbol, perSessionAvg.toStringAsFixed(2)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            if (showDiscount) ...[
              const SizedBox(height: 6),
              Text(
                l10n.packagePurchaseOriginalPerSession(
                    symbol, basePrice.toStringAsFixed(2)),
                style: const TextStyle(
                  fontSize: 11,
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.packagePurchaseSaveAmount(
                    symbol,
                    savedTotal.toStringAsFixed(2),
                    percent.toString(),
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // bundle 校验: 至少 2 个不同服务
    if (_packageType == 'bundle' && _bundleSelections.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expertPackageBundleMin)),
      );
      return;
    }

    final packagePrice = double.parse(_packagePriceController.text.trim());
    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'currency': _currency,
      'package_type': _packageType,
      'package_price': packagePrice,
    };
    // 关联型 multi 套餐：description / base_price 等字段由后端从关联服务继承，前端不传
    if (!_isLinkedMulti) {
      data['description'] = _descController.text.trim();
    }

    if (_packageType == 'multi') {
      final sessions = int.parse(_sessionsController.text.trim());
      data['total_sessions'] = sessions;
      // base_price: 未关联时按用户输入 / 自动推导；关联时后端继承，前端不传
      if (!_isLinkedMulti) {
        final baseText = _basePriceController.text.trim();
        double basePrice;
        if (baseText.isNotEmpty) {
          basePrice = double.parse(baseText);
        } else {
          basePrice = packagePrice / sessions;
        }
        basePrice = (basePrice * 100).round() / 100.0;
        if (basePrice <= 0) basePrice = 0.01;
        data['base_price'] = basePrice;
      }
      // 关联服务（选填）
      data['linked_service_id'] = _linkedServiceId;
    } else if (_packageType == 'bundle') {
      data['bundle_service_ids'] = _bundleSelections.entries
          .map((e) => {'service_id': e.key, 'count': e.value})
          .toList();
      // bundle 没有"单价"概念,base_price 不传(后端 nullable + validator 已放宽)
    }

    final validityText = _validityDaysController.text.trim();
    if (validityText.isNotEmpty) {
      data['validity_days'] = int.parse(validityText);
    }

    widget.onSubmit(data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                            ? l10n.expertPackageEdit
                            : l10n.expertPackageCreate,
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
                  setState(() {
                    _packageType = selected.first;
                    // 切到 bundle 时清空 multi 专属的关联服务字段
                    if (_packageType != 'multi') _linkedServiceId = null;
                  });
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 关联服务（multi 套餐专属）：选择后自动继承描述/图片/定价等
              _buildLinkedServicePicker(context),
              if (_packageType == 'multi')
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

              // Description (hidden when linked — inherited from linked service)
              if (!_isLinkedMulti) ...[
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
              ],

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
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.validatorFieldRequired(
                          l10n.expertPackageSessionCount);
                    }
                    final n = int.tryParse(value.trim());
                    if (n == null || n < 2) {
                      return l10n.expertPackageSessionCountMin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Per-session reference price (hidden when linked — inherited from linked service)
                if (!_isLinkedMulti) ...[
                  TextFormField(
                    controller: _basePriceController,
                    decoration: InputDecoration(
                      labelText: l10n.expertPackageBasePrice,
                      helperText: l10n.expertPackageBasePriceHint,
                      prefixText: '${Helpers.currencySymbolFor(_currency)} ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final p = double.tryParse(value.trim());
                      if (p == null || p <= 0) {
                        return l10n.validatorFieldRequired(
                            l10n.expertPackageBasePrice);
                      }
                      return null;
                    },
                  ),
                ],
                // 实时折扣预览 (multi 套餐)
                _buildDiscountPreview(context),
                const SizedBox(height: AppSpacing.md),
              ],

              // Bundle sub-services selector (bundle only)
              if (_packageType == 'bundle') ...[
                Text(
                  l10n.expertPackageBundleServices,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.expertPackageBundleServicesHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _BundleServicePicker(
                  services: widget.singleServices,
                  selections: _bundleSelections,
                  onChanged: (newMap) {
                    setState(() {
                      _bundleSelections
                        ..clear()
                        ..addAll(newMap);
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Package total price
              TextFormField(
                controller: _packagePriceController,
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
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
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
              const SizedBox(height: AppSpacing.md),

              // Validity days (optional)
              TextFormField(
                controller: _validityDaysController,
                decoration: InputDecoration(
                  labelText: l10n.expertPackageValidityDays,
                  helperText: l10n.expertPackageValidityDaysHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final n = int.tryParse(value.trim());
                  if (n == null || n <= 0) {
                    return l10n.validatorFieldRequired(
                        l10n.expertPackageValidityDays);
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
      ),
    );
  }
}

// =============================================================================
// Bundle Sub-service Picker
// =============================================================================

class _BundleServicePicker extends StatelessWidget {
  const _BundleServicePicker({
    required this.services,
    required this.selections,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> services;
  final Map<int, int> selections;
  final void Function(Map<int, int>) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (services.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.allSmall,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Text(
          l10n.expertPackageBundleNoServices,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.allSmall,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < services.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            _BundleServiceRow(
              service: services[i],
              count: selections[services[i]['id'] as int] ?? 0,
              onCountChanged: (newCount) {
                final sid = services[i]['id'] as int;
                final next = Map<int, int>.from(selections);
                if (newCount <= 0) {
                  next.remove(sid);
                } else {
                  next[sid] = newCount;
                }
                onChanged(next);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _BundleServiceRow extends StatelessWidget {
  const _BundleServiceRow({
    required this.service,
    required this.count,
    required this.onCountChanged,
  });

  final Map<String, dynamic> service;
  final int count;
  final ValueChanged<int> onCountChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = service['service_name'] as String? ?? '';
    final price = (service['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (service['currency'] as String?) ?? 'GBP';
    final selected = count > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            onChanged: (v) => onCountChanged(v == true ? 1 : 0),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (selected) ...[
            Text(
              l10n.expertPackageBundleCount,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              onPressed: count > 1 ? () => onCountChanged(count - 1) : null,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              onPressed: count < 99 ? () => onCountChanged(count + 1) : null,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
