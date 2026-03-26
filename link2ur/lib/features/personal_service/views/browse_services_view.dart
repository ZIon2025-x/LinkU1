import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// 浏览所有服务（个人服务 + 达人服务）
class BrowseServicesView extends StatelessWidget {
  const BrowseServicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      )..add(const PersonalServiceBrowse()),
      child: const _Content(),
    );
  }
}

class _Content extends StatefulWidget {
  const _Content();

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedType = 'all';
  String _selectedSort = 'recommended';
  int _currentPage = 1;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = context.read<PersonalServiceBloc>().state;
      if (_currentPage < state.browseTotalPages) {
        _isLoadingMore = true;
        _currentPage++;
        context.read<PersonalServiceBloc>().add(
              PersonalServiceBrowse(
                type: _selectedType,
                query: _searchController.text.trim().isEmpty
                    ? null
                    : _searchController.text.trim(),
                sort: _selectedSort,
                page: _currentPage,
              ),
            );
        // Reset loading more flag after state updates
        Future.delayed(const Duration(milliseconds: 500), () {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _search() {
    _currentPage = 1;
    _isLoadingMore = false;
    context.read<PersonalServiceBloc>().add(
          PersonalServiceBrowse(
            type: _selectedType,
            query: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            sort: _selectedSort,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseServicesTitle),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.browseServicesSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _search();
                  },
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),

          // Type filter + Sort row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                // Type filter chips
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TypeChip(
                          label: l10n.browseServicesFilterAll,
                          selected: _selectedType == 'all',
                          onTap: () {
                            setState(() => _selectedType = 'all');
                            _search();
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _TypeChip(
                          label: l10n.browseServicesFilterPersonal,
                          selected: _selectedType == 'personal',
                          onTap: () {
                            setState(() => _selectedType = 'personal');
                            _search();
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _TypeChip(
                          label: l10n.browseServicesFilterExpert,
                          selected: _selectedType == 'expert',
                          onTap: () {
                            setState(() => _selectedType = 'expert');
                            _search();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Sort dropdown
                PopupMenuButton<String>(
                  icon: Icon(Icons.sort,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                  onSelected: (value) {
                    setState(() => _selectedSort = value);
                    _search();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'recommended',
                      child: Text(l10n.browseServicesSortRecommended),
                    ),
                    PopupMenuItem(
                      value: 'newest',
                      child: Text(l10n.browseServicesSortNewest),
                    ),
                    PopupMenuItem(
                      value: 'price_asc',
                      child: Text(l10n.browseServicesSortPriceAsc),
                    ),
                    PopupMenuItem(
                      value: 'price_desc',
                      child: Text(l10n.browseServicesSortPriceDesc),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results list
          Expanded(
            child: BlocBuilder<PersonalServiceBloc, PersonalServiceState>(
              buildWhen: (prev, curr) =>
                  prev.browseResults != curr.browseResults ||
                  prev.status != curr.status,
              builder: (context, state) {
                if (state.status == PersonalServiceStatus.loading &&
                    state.browseResults.isEmpty) {
                  return const SkeletonList();
                }

                if (state.status == PersonalServiceStatus.error &&
                    state.browseResults.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: AppColors.error.withValues(alpha: 0.5)),
                        AppSpacing.vMd,
                        Text(state.errorMessage ?? ''),
                        AppSpacing.vMd,
                        TextButton(
                          onPressed: _search,
                          child: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  );
                }

                if (state.browseResults.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.search_off_outlined,
                    title: l10n.browseServicesEmpty,
                    message: l10n.browseServicesEmptyMessage,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    _currentPage = 1;
                    _isLoadingMore = false;
                    _search();
                    await context
                        .read<PersonalServiceBloc>()
                        .stream
                        .firstWhere(
                          (s) => s.status != PersonalServiceStatus.loading,
                        );
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, 0, AppSpacing.md, 100),
                    itemCount: state.browseResults.length +
                        (_currentPage < state.browseTotalPages ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.browseResults.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final service = state.browseResults[index];
                      return Padding(
                        key: ValueKey(service['id']),
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _BrowseServiceCard(
                          service: service,
                          onTap: () {
                            final id = service['id'];
                            context.push('/service/$id');
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : null,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _BrowseServiceCard extends StatelessWidget {
  const _BrowseServiceCard({
    required this.service,
    required this.onTap,
  });

  final Map<String, dynamic> service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = (service['service_name'] as String?) ?? '';
    final description = (service['description'] as String?) ?? '';
    final price = (service['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (service['currency'] as String?) ?? 'GBP';
    final pricingType = (service['pricing_type'] as String?) ?? 'fixed';
    final serviceType = (service['service_type'] as String?) ?? 'personal';
    final ownerName = (service['owner_name'] as String?) ?? '';
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
      child: InkWell(
        borderRadius: AppRadius.allMedium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: Container(
                  width: 72,
                  height: 72,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  child: firstImage != null
                      ? Image.network(
                          firstImage,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.handyman_outlined,
                            size: 28,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.handyman_outlined,
                          size: 28,
                          color: AppColors.primary,
                        ),
                ),
              ),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          pricingType == 'negotiable'
                              ? context.l10n.personalServicePricingNegotiable
                              : '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (pricingType == 'hourly')
                          Text(
                            '/hr',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        const Spacer(),
                        // Service type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: serviceType == 'expert'
                                ? AppColors.accent.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.allTiny,
                          ),
                          child: Text(
                            serviceType == 'expert'
                                ? context.l10n.browseServicesFilterExpert
                                : context.l10n.browseServicesFilterPersonal,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: serviceType == 'expert'
                                  ? AppColors.accent
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ownerName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 12,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                          const SizedBox(width: 4),
                          Text(
                            ownerName,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
