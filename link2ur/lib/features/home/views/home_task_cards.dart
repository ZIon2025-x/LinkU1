part of 'home_view.dart';

/// 对标iOS: NearbyTasksView (附近Tab)
/// 使用 Geolocator 获取设备位置，加载附近任务 + 附近服务
class _NearbyTab extends StatefulWidget {
  const _NearbyTab();

  @override
  State<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<_NearbyTab> {
  bool _locationLoading = false;
  String? _city; // 反向地理编码得到的城市名

  // 缓存当前坐标，供切换半径时复用
  double _currentLat = _defaultLat;
  double _currentLng = _defaultLng;

  // 默认坐标（伦敦）
  static const _defaultLat = 51.5074;
  static const _defaultLng = -0.1278;

  static const _radiusOptions = [5, 10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    // 如果已有附近任务数据，跳过重新定位
    final homeState = context.read<HomeBloc>().state;
    if (homeState.nearbyTasks.isNotEmpty) return;
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() => _locationLoading = true);

    try {
      // 检查位置服务是否启用
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _loadWithCoordinates(_defaultLat, _defaultLng);
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _loadWithCoordinates(_defaultLat, _defaultLng);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _loadWithCoordinates(_defaultLat, _defaultLng);
        return;
      }

      // 优先使用上次已知位置（几乎瞬间返回），快速展示数据
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await _resolveCity(lastKnown.latitude, lastKnown.longitude);
        _loadWithCoordinates(lastKnown.latitude, lastKnown.longitude);
        // 后台获取精确位置，如果差异较大则刷新
        _refreshWithCurrentPosition(lastKnown.latitude, lastKnown.longitude);
        return;
      }

      // 没有缓存位置，必须等待 getCurrentPosition
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // low 精度更快
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Location timeout'),
      );

      await _resolveCity(position.latitude, position.longitude);
      _loadWithCoordinates(position.latitude, position.longitude);
    } catch (e) {
      _loadWithCoordinates(_defaultLat, _defaultLng);
    }
  }

  /// 反向地理编码获取城市名，用于同城过滤 + 左上角定位显示
  Future<void> _resolveCity(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        // locality 通常是城市名（如 "Birmingham"、"London"）
        _city = placemarks.first.locality;
        // 同步到 HomeBloc 供左上角定位显示
        if (_city != null && mounted) {
          context.read<HomeBloc>().add(HomeLocationCityUpdated(_city!));
        }
      }
    } catch (_) {
      // 反向编码失败不影响加载，只是不做同城过滤
    }
  }

  /// 后台获取精确位置，如果与快速位置差异 > 500m 则刷新列表
  Future<void> _refreshWithCurrentPosition(double quickLat, double quickLng) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 5), onTimeout: () => throw Exception('timeout'));

      if (!mounted) return;

      // 计算距离差异，超过 500m 才刷新
      final distance = Geolocator.distanceBetween(
        quickLat, quickLng, position.latitude, position.longitude,
      );
      if (distance > 500) {
        await _resolveCity(position.latitude, position.longitude);
        if (!mounted) return;
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        final bloc = context.read<HomeBloc>();
        bloc.add(HomeLoadNearby(
              latitude: position.latitude,
              longitude: position.longitude,
              city: _city,
            ));
        bloc.add(HomeLoadNearbyServices(
              latitude: position.latitude,
              longitude: position.longitude,
              radius: bloc.state.nearbyRadius,
            ));
      }
    } catch (_) {
      // 精确定位失败不影响已加载的数据
    }
  }

  void _loadWithCoordinates(double lat, double lng) {
    if (!mounted) return;
    _currentLat = lat;
    _currentLng = lng;
    setState(() => _locationLoading = false);
    final bloc = context.read<HomeBloc>();
    bloc.add(HomeLoadNearby(
          latitude: lat,
          longitude: lng,
          city: _city,
        ));
    bloc.add(HomeLoadNearbyServices(
          latitude: lat,
          longitude: lng,
          radius: bloc.state.nearbyRadius,
        ));
  }

  void _onRadiusChanged(int radius) {
    final bloc = context.read<HomeBloc>();
    bloc.add(HomeChangeNearbyRadius(radius));
    bloc.add(HomeLoadNearbyServices(
      latitude: _currentLat,
      longitude: _currentLng,
      radius: radius,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (_locationLoading) {
      const body = SkeletonTopImageCardList();
      return isDesktop ? const ContentConstraint(child: body) : body;
    }

    return BlocBuilder<HomeBloc, HomeState>(
      // 附近任务 + 附近服务 + 半径变化时重建
      buildWhen: (prev, curr) =>
          prev.nearbyTasks != curr.nearbyTasks ||
          prev.nearbyServices != curr.nearbyServices ||
          prev.nearbyRadius != curr.nearbyRadius ||
          prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading && state.nearbyTasks.isEmpty) {
          const body = SkeletonTopImageCardList();
          return isDesktop ? const ContentConstraint(child: body) : body;
        }

        if (state.nearbyTasks.isEmpty && state.nearbyServices.isEmpty) {
          final center = Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeNoNearbyTasks,
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: _loadLocation,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.homeLoadNearbyTasks),
                ),
              ],
            ),
          );
          return isDesktop ? ContentConstraint(child: center) : center;
        }

        final content = RefreshIndicator(
          onRefresh: () async {
            final homeBloc = context.read<HomeBloc>();
            await _loadLocation();
            await homeBloc.stream.firstWhere(
              (s) => !s.isLoading,
              orElse: () => state,
            );
          },
          child: CustomScrollView(
            slivers: [
              // 半径选择器
              SliverToBoxAdapter(
                child: _NearbyRadiusSelector(
                  selectedRadius: state.nearbyRadius,
                  onChanged: _onRadiusChanged,
                ),
              ),

              // 附近任务列表
              if (state.nearbyTasks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AnimatedListItem(
                            index: index,
                            maxAnimatedIndex: 11,
                            child: _TaskCard(task: state.nearbyTasks[index]),
                          ),
                        );
                      },
                      childCount: state.nearbyTasks.length,
                    ),
                  ),
                ),

              // 附近服务区段标题
              if (state.nearbyServices.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.home_repair_service_outlined,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.nearbyServicesSection,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 附近服务卡片列表
              if (state.nearbyServices.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _NearbyServiceCard(
                            service: state.nearbyServices[index],
                          ),
                        );
                      },
                      childCount: state.nearbyServices.length,
                    ),
                  ),
                ),

              // 底部安全区
              const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
            ],
          ),
        );
        return isDesktop ? ContentConstraint(child: content) : content;
      },
    );
  }
}

/// 半径选择器 — 横向 ChoiceChip 列表
class _NearbyRadiusSelector extends StatelessWidget {
  const _NearbyRadiusSelector({
    required this.selectedRadius,
    required this.onChanged,
  });

  final int selectedRadius;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.nearbyRadius,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _NearbyTabState._radiusOptions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final radius = _NearbyTabState._radiusOptions[index];
                final isSelected = radius == selectedRadius;
                return ChoiceChip(
                  label: Text('${radius}km'),
                  selected: isSelected,
                  onSelected: (_) => onChanged(radius),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF2F2F7),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 附近服务卡片
class _NearbyServiceCard extends StatelessWidget {
  const _NearbyServiceCard({required this.service});

  final Map<String, dynamic> service;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';

    final name = (isEn
            ? (service['name_en'] ?? service['name'])
            : service['name']) as String? ??
        '';
    final price = service['price'];
    final pricingType = service['pricing_type'] as String? ?? '';
    final locationText = service['location_text'] as String? ?? '';
    final distanceKm = service['distance_km'];
    final ownerName = service['owner_name'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          // 左侧信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 服务名称
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 价格 + 计价方式
                if (price != null)
                  Text(
                    '\u00A3${_formatPrice(price)}${pricingType.isNotEmpty ? ' / $pricingType' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEE5A24),
                    ),
                  ),
                const SizedBox(height: 4),
                // 位置 + 拥有者
                Row(
                  children: [
                    if (locationText.isNotEmpty) ...[
                      Icon(Icons.location_on_outlined,
                          size: 13,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          locationText,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (ownerName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline,
                          size: 13,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                      const SizedBox(width: 2),
                      Text(
                        ownerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 右侧距离 badge
          if (distanceKm != null)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDistance(distanceKm)}km',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    context.l10n.nearbyServiceDistance,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price is int) return price.toString();
    if (price is double) {
      return price == price.truncateToDouble()
          ? price.toInt().toString()
          : price.toStringAsFixed(2);
    }
    return price.toString();
  }

  String _formatDistance(dynamic distance) {
    if (distance is int) return distance.toString();
    if (distance is double) {
      if (distance < 1) return distance.toStringAsFixed(1);
      return distance.toStringAsFixed(1);
    }
    return distance.toString();
  }
}
