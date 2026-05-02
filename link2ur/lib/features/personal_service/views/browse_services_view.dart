import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/localized_string.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
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

  void _onFavoriteTap(Map<String, dynamic> service) {
    final auth = context.read<AuthBloc>().state;
    if (auth.status != AuthStatus.authenticated) {
      _showLoginPrompt();
      return;
    }
    final id = (service['id'] as num?)?.toInt();
    if (id == null) return;
    context
        .read<PersonalServiceBloc>()
        .add(PersonalServiceFavoriteToggled(id));
  }

  void _showLoginPrompt() {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.loginRequired),
        content: Text(l10n.loginRequiredForFavorite),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/login');
            },
            child: Text(l10n.loginLoginNow),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<PersonalServiceBloc, PersonalServiceState>(
      // 收藏失败时弹 SnackBar (status==error 路径已有全屏 retry, 此处只处理 transient)
      listenWhen: (prev, curr) =>
          curr.errorMessage == 'toggle_favorite_failed' &&
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.localizeError(state.errorMessage)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
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
                IconButton(
                  icon: Icon(Icons.sort,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                  onPressed: () async {
                    final options = [
                      SelectOption(value: 'recommended', label: l10n.browseServicesSortRecommended),
                      SelectOption(value: 'newest', label: l10n.browseServicesSortNewest),
                      SelectOption(value: 'price_asc', label: l10n.browseServicesSortPriceAsc),
                      SelectOption(value: 'price_desc', label: l10n.browseServicesSortPriceDesc),
                    ];
                    final result = await showAppSelectSheet<String>(
                      context: context,
                      options: options,
                      value: _selectedSort,
                      title: l10n.expertSearchSortLabel,
                    );
                    if (result != null && result.value != _selectedSort) {
                      setState(() => _selectedSort = result.value);
                      _search();
                    }
                  },
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
                        AppSpacing.md, AppSpacing.xs, AppSpacing.md, 100),
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
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _BrowseServiceCard(
                          service: service,
                          onTap: () {
                            final id = service['id'];
                            final withinArea = service['within_service_area'];
                            final extra = withinArea == false ? '?within_service_area=false' : '';
                            context.push('/service/$id$extra');
                          },
                          onFavoriteTap: () => _onFavoriteTap(service),
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

/// Fiverr 风格服务卡片
/// 结构: 作者条 → 16:10 大封面 → 标题 → 评分行 → 分割线 → 起价 + 收藏图标
class _BrowseServiceCard extends StatelessWidget {
  const _BrowseServiceCard({
    required this.service,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Map<String, dynamic> service;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;

    final name = localizedString(
      service['service_name_zh'] as String?,
      service['service_name_en'] as String?,
      (service['service_name'] as String?) ?? '',
      locale,
    );
    final price = (service['base_price'] as num?)?.toDouble() ?? 0.0;
    final currency = (service['currency'] as String?) ?? 'GBP';
    final pricingType = (service['pricing_type'] as String?) ?? 'fixed';
    final serviceType = (service['service_type'] as String?) ?? 'personal';
    final isExpert = serviceType == 'expert';

    final ownerName = (service['owner_name'] as String?) ?? '';
    final ownerAvatar = service['owner_avatar'] as String?;
    final displayName = service['display_name'] as String?;
    final displayAvatar = service['display_avatar'] as String?;
    final shownName = (displayName?.isNotEmpty ?? false) ? displayName! : ownerName;
    final shownAvatar = displayAvatar ?? ownerAvatar;

    final rating = (service['service_rating'] as num?)?.toDouble();
    final reviewCount = (service['review_count'] as num?)?.toInt() ?? 0;
    final distanceKm = (service['distance_km'] as num?)?.toDouble();
    final isFavorited = (service['is_favorited'] as bool?) ?? false;

    final images = service['images'] as List<dynamic>?;
    final firstImage =
        (images != null && images.isNotEmpty) ? images.first as String? : null;

    final cardBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final divider = isDark ? Colors.white12 : const Color(0xFFEEEEEE);
    final mutedColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    final priceText = pricingType == 'negotiable'
        ? l10n.personalServicePricingNegotiable
        : l10n.servicePriceFrom(
            '${Helpers.currencySymbolFor(currency)}${price.toStringAsFixed(0)}',
          );

    return Material(
      color: cardBg,
      borderRadius: AppRadius.allMedium,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.allMedium,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.allMedium,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ───── 1. 作者条 ─────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  child: Row(
                    children: [
                      AvatarView(
                        imageUrl: shownAvatar,
                        name: shownName,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shownName.isNotEmpty ? shownName : '—',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _TypeBadge(isExpert: isExpert, l10n: l10n),
                    ],
                  ),
                ),
                // ───── 2. 大封面 16:10 ─────
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : const Color(0xFFF1F2F6),
                    child: firstImage != null
                        ? Image.network(
                            firstImage,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            errorBuilder: (_, __, ___) =>
                                const _CoverPlaceholder(),
                          )
                        : const _CoverPlaceholder(),
                  ),
                ),
                // ───── 3. 标题 + 评分行 ─────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _RatingRow(
                        rating: rating,
                        reviewCount: reviewCount,
                        distanceKm: distanceKm,
                        isExpert: isExpert,
                        mutedColor: mutedColor,
                        l10n: l10n,
                      ),
                    ],
                  ),
                ),
                // ───── 4. 分割线 + 起价 + 收藏 ─────
                Container(height: 1, color: divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: onFavoriteTap,
                        icon: Icon(
                          isFavorited
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: isFavorited
                              ? const Color(0xFFE53935)
                              : mutedColor,
                          size: 22,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isExpert, required this.l10n});
  final bool isExpert;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    final fg = isExpert ? const Color(0xFFB45309) : AppColors.primary;
    final bg = isExpert
        ? const Color(0xFFFEF3C7)
        : AppColors.primary.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isExpert
            ? l10n.browseServicesFilterExpert
            : l10n.browseServicesFilterPersonal,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.isExpert,
    required this.mutedColor,
    required this.l10n,
  });
  final double? rating;
  final int reviewCount;
  final double? distanceKm;
  final bool isExpert;
  final Color mutedColor;
  final dynamic l10n;

  @override
  Widget build(BuildContext context) {
    final hasRating = rating != null && rating! > 0;
    final children = <Widget>[];

    if (hasRating) {
      children.addAll([
        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
        const SizedBox(width: 2),
        Text(
          rating!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (reviewCount > 0) ...[
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
        ],
      ]);
    }

    // 右侧 pill: 距离 优先于 认证
    Widget? rightPill;
    if (distanceKm != null) {
      rightPill = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 12, color: mutedColor),
          const SizedBox(width: 2),
          Text(
            '${distanceKm!.toStringAsFixed(1)} km',
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      );
    } else if (isExpert) {
      rightPill = Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '✓',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF10B981),
          ),
        ),
      );
    }

    if (rightPill != null) {
      if (children.isNotEmpty) children.add(const Spacer());
      children.add(rightPill);
    }

    if (children.isEmpty) {
      // 无评分无距离时显示「暂无评价」, 避免行高跳动
      return SizedBox(
        height: 16,
        child: Text(
          l10n.noReviewsYet,
          style: TextStyle(fontSize: 11, color: mutedColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return SizedBox(
      height: 16,
      child: Row(children: children),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.handyman_outlined,
        size: 36,
        color: AppColors.primary,
      ),
    );
  }
}
