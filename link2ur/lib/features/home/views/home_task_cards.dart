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
  bool _locationFailed = false;
  bool _permissionDeniedForever = false;

  // 缓存当前坐标，供切换半径时复用
  double _currentLat = _defaultLat;
  double _currentLng = _defaultLng;

  // 默认坐标（伦敦）
  static const _defaultLat = 51.5074;
  static const _defaultLng = -0.1278;

  static const _radiusOptions = [1, 3, 5, 10, 15];

  @override
  void initState() {
    super.initState();
    final homeState = context.read<HomeBloc>().state;
    if (homeState.nearbyTasks.isNotEmpty) return;

    // 优先使用全局单例的缓存坐标（main_tab_view 启动时已 resolve），
    // 避免 NearbyTab 重复做 GPS 权限检查 + 定位请求。
    final locService = LocationCityService.instance;
    if (locService.isResolved && locService.latitude != null && locService.longitude != null) {
      _city = locService.city;
      _loadWithCoordinates(locService.latitude!, locService.longitude!);
      // 后台获取精确位置（和原逻辑一致，差异 >500m 才刷新）
      _refreshWithCurrentPosition(locService.latitude!, locService.longitude!);
    } else {
      _loadLocation();
    }
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
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (mounted && permission == LocationPermission.deniedForever) {
            setState(() => _permissionDeniedForever = true);
          }
          _loadWithCoordinates(_defaultLat, _defaultLng);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _permissionDeniedForever = true);
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
        final p = placemarks.first;
        // locality 通常是城市名；fallback 到 subAdministrativeArea 或 administrativeArea
        final city = p.locality ??
            p.subAdministrativeArea ??
            p.administrativeArea;
        if (city != null && city.isNotEmpty && mounted) {
          setState(() => _city = city);
          context.read<HomeBloc>().add(HomeLocationCityUpdated(city));
          LocationCityService.instance.update(city: city, lat: lat, lng: lng);
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

      // 始终用精确位置更新城市名（城市可能和缓存位置不同）
      await _resolveCity(position.latitude, position.longitude);
      if (!mounted) return;

      // 计算距离差异，超过 500m 才刷新数据
      final distance = Geolocator.distanceBetween(
        quickLat, quickLng, position.latitude, position.longitude,
      );
      if (distance > 500) {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
        final bloc = context.read<HomeBloc>();
        bloc.add(HomeLoadNearby(
              latitude: position.latitude,
              longitude: position.longitude,
              city: _city,
              radius: bloc.state.nearbyRadius,
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
    final isDefault = lat == _defaultLat && lng == _defaultLng;
    setState(() {
      _locationLoading = false;
      _locationFailed = isDefault;
      if (!isDefault) _permissionDeniedForever = false;
    });
    final bloc = context.read<HomeBloc>();
    bloc.add(HomeLoadNearby(
          latitude: lat,
          longitude: lng,
          city: _city,
          radius: bloc.state.nearbyRadius,
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
    bloc.add(HomeLoadNearby(
      latitude: _currentLat,
      longitude: _currentLng,
      city: _city,
      radius: radius,
    ));
    bloc.add(HomeLoadNearbyServices(
      latitude: _currentLat,
      longitude: _currentLng,
      radius: radius,
    ));
  }

  List<Widget> _buildWaterfallItems(HomeState state) {
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';

    // Collect items with distance for sorting
    final entries = <({Widget widget, double distance})>[];

    // Tasks
    for (final task in state.nearbyTasks) {
      final title = isEn
          ? (task.titleEn ?? task.title)
          : (task.titleZh ?? task.title);
      entries.add((
        widget: _NearbyWaterfallCard(
          title: title,
          imageUrl: task.firstImage,
          distanceText: task.blurredDistanceText,
          distanceMeters: task.distance,
          tags: [task.taskType],
          price: '\u00A3${task.reward == task.reward.truncateToDouble() ? task.reward.toInt().toString() : task.reward.toStringAsFixed(2)}',
          applicantCount: task.currentParticipants,
          itemType: task.taskType,
          onTap: () => context.push('/tasks/${task.id}'),
        ),
        distance: task.distance ?? double.infinity,
      ));
    }

    // Services
    for (final service in state.nearbyServices) {
      final name = localizedString(
              service['service_name_zh'] as String?,
              service['service_name_en'] as String?,
              (service['service_name'] as String?) ?? '',
              locale,
            );
      final price = service['base_price'];
      final priceStr = price != null
          ? '\u00A3${_formatServicePrice(price)}'
          : null;
      final distKm = service['distance_km'] as num?;
      final distMeters = distKm != null ? distKm.toDouble() * 1000 : null;
      final imageUrl = service['cover_image'] as String?
          ?? ((service['images'] is List && (service['images'] as List).isNotEmpty)
              ? (service['images'] as List).first as String?
              : null);
      final isExpert = service['is_expert_verified'] == true;
      final ownerName = service['owner_name'] as String?;
      final ownerAvatar = service['owner_avatar'] as String?;

      entries.add((
        widget: _NearbyWaterfallCard(
          title: name,
          imageUrl: imageUrl,
          distanceText: distMeters != null ? _blurDistance(distMeters) : null,
          distanceMeters: distMeters,
          price: priceStr,
          itemType: 'service',
          isExpertVerified: isExpert,
          ownerName: ownerName,
          ownerAvatar: ownerAvatar,
          onTap: () {
            final id = service['id'];
            if (id != null) context.push('/service/$id');
          },
        ),
        distance: distMeters ?? double.infinity,
      ));
    }

    // Sort by distance (nearest first)
    entries.sort((a, b) => a.distance.compareTo(b.distance));

    return entries.map((e) => e.widget).toList();
  }

  static String _formatServicePrice(dynamic price) {
    if (price is int) return price.toString();
    if (price is double) {
      return price == price.truncateToDouble()
          ? price.toInt().toString()
          : price.toStringAsFixed(2);
    }
    return price.toString();
  }

  /// Blur distance to 500m buckets (same as Task model's blurredDistanceText)
  static String _blurDistance(double meters) {
    final bucket = (meters / 500).ceil() * 500;
    if (bucket <= 500) return '<500m';
    if (bucket < 1000) return '<${bucket}m';
    final km = bucket / 1000;
    return km == km.roundToDouble()
        ? '<${km.toInt()}km'
        : '<${km.toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (_locationLoading) {
      const body = SkeletonTopImageCardList();
      return isDesktop ? const ContentConstraint(child: body) : body;
    }

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.nearbyTasks != curr.nearbyTasks ||
          prev.nearbyServices != curr.nearbyServices ||
          prev.nearbyRadius != curr.nearbyRadius ||
          prev.hasMoreNearby != curr.hasMoreNearby ||
          prev.isLoadingNearby != curr.isLoadingNearby ||
          prev.nearbyServicesPage != curr.nearbyServicesPage ||
          prev.hasMoreNearbyServices != curr.hasMoreNearbyServices ||
          prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading && state.nearbyTasks.isEmpty) {
          const body = SkeletonTopImageCardList();
          return isDesktop ? const ContentConstraint(child: body) : body;
        }

        if (!state.isLoadingNearby && state.nearbyTasks.isEmpty && state.nearbyServices.isEmpty) {
          final isDarkEmpty = Theme.of(context).brightness == Brightness.dark;
          final emptyContent = Column(
            children: [
              // Keep location bar + radius selector visible so user can switch radius
              _NearbyLocationBar(
                city: _city,
                onRefreshTap: _loadLocation,
                locationFailed: _locationFailed,
                permissionDeniedForever: _permissionDeniedForever,
              ),
              _NearbyRadiusSelector(
                selectedRadius: state.nearbyRadius,
                onChanged: _onRadiusChanged,
              ),
              const Spacer(),
              Icon(Icons.location_off_outlined,
                  size: 64, color: isDarkEmpty ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
              AppSpacing.vMd,
              Text(context.l10n.homeNoNearbyTasks,
                  style: TextStyle(color: isDarkEmpty ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              AppSpacing.vMd,
              TextButton.icon(
                onPressed: _loadLocation,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.homeLoadNearbyTasks),
              ),
              const Spacer(),
            ],
          );
          return isDesktop ? ContentConstraint(child: emptyContent) : emptyContent;
        }

        // Build mixed list of tasks + services for waterfall
        final waterfallItems = _buildWaterfallItems(state);

        final content = Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                final homeBloc = context.read<HomeBloc>();
                await _loadLocation();
                await homeBloc.stream
                    .firstWhere((s) => !s.isLoadingNearby, orElse: () => state);
              },
              child: CustomScrollView(
                slivers: [
                  // Location bar
                  SliverToBoxAdapter(
                    child: _NearbyLocationBar(
                      city: _city,
                      onRefreshTap: _loadLocation,
                      locationFailed: _locationFailed,
                      permissionDeniedForever: _permissionDeniedForever,
                    ),
                  ),
                  // Radius selector
                  SliverToBoxAdapter(
                    child: _NearbyRadiusSelector(
                      selectedRadius: state.nearbyRadius,
                      onChanged: _onRadiusChanged,
                    ),
                  ),
                  // Waterfall grid
                  SliverPadding(
                    padding: const EdgeInsets.all(8),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childCount: waterfallItems.length,
                      itemBuilder: (context, index) => waterfallItems[index],
                    ),
                  ),
                  // Load more trigger
                  if (state.hasMoreNearby || state.hasMoreNearbyServices)
                    SliverToBoxAdapter(
                      child: _NearbyLoadMoreTrigger(
                        key: ValueKey('nearby_more_${state.nearbyPage}_${state.nearbyServicesPage}'),
                        onVisible: () {
                          final bloc = context.read<HomeBloc>();
                          if (bloc.state.hasMoreNearby) {
                            bloc.add(HomeLoadNearby(
                              latitude: _currentLat,
                              longitude: _currentLng,
                              loadMore: true,
                              city: _city,
                              radius: bloc.state.nearbyRadius,
                            ));
                          }
                          if (bloc.state.hasMoreNearbyServices) {
                            bloc.add(HomeLoadNearbyServices(
                              latitude: _currentLat,
                              longitude: _currentLng,
                              radius: bloc.state.nearbyRadius,
                              loadMore: true,
                            ));
                          }
                        },
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
                ],
              ),
            ),
            if (state.isLoadingNearby)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
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

/// 附近 tab 顶部定位条
class _NearbyLocationBar extends StatelessWidget {
  const _NearbyLocationBar({
    required this.city,
    required this.onRefreshTap,
    this.locationFailed = false,
    this.permissionDeniedForever = false,
  });

  final String? city;
  final VoidCallback onRefreshTap;
  final bool locationFailed;
  final bool permissionDeniedForever;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final displayCity = city ?? 'London';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0,
      ),
      child: Row(
        children: [
          Icon(
            locationFailed ? Icons.location_off : Icons.location_on,
            size: 14,
            color: locationFailed ? Colors.orange : AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              locationFailed
                  ? l10n.nearbyLocationFailed
                  : l10n.nearbyCurrentLocation(displayCity),
              style: TextStyle(
                fontSize: 13,
                color: locationFailed
                    ? Colors.orange
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (permissionDeniedForever)
            GestureDetector(
              onTap: () => Geolocator.openAppSettings(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.nearbyOpenSettings,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onRefreshTap,
              child: const Icon(
                Icons.my_location,
                size: 14,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// 附近瀑布流卡片 — 小红书风格
class _NearbyWaterfallCard extends StatelessWidget {
  const _NearbyWaterfallCard({
    required this.title,
    this.imageUrl,
    this.distanceText,
    this.distanceMeters,
    this.tags = const [],
    this.price,
    this.applicantCount = 0,
    this.onTap,
    this.itemType = '',
    this.isExpertVerified = false,
    this.ownerName,
    this.ownerAvatar,
  });

  final String title;
  final String? imageUrl;
  /// Pre-formatted blurred distance text, e.g. "<1.5km"
  final String? distanceText;
  /// Raw distance in meters — used only for sorting in _buildWaterfallItems
  final double? distanceMeters;
  final List<String> tags;
  final String? price;
  final int applicantCount;
  final VoidCallback? onTap;
  final String itemType;
  final bool isExpertVerified;
  final String? ownerName;
  final String? ownerAvatar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isExpertVerified
              ? Border.all(
                  color: const Color(0xFFDAA520).withValues(alpha: 0.4),
                  width: 1.5,
                )
              : null,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area with distance badge + expert badge
            _buildImageArea(isDark),
            // Card body
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty || price != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ...tags.map((tag) => _NearbyTagChip(label: tag)),
                          if (price != null) _NearbyTagChip(label: price!, isPrice: true),
                        ],
                      ),
                    ),
                  if (applicantCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        context.l10n.nearbyApplicants(applicantCount),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                  // Expert service owner info
                  if (ownerName != null && ownerName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundImage: ownerAvatar != null && ownerAvatar!.isNotEmpty
                                ? NetworkImage(Helpers.getImageUrl(ownerAvatar))
                                : null,
                            backgroundColor: isDark ? Colors.grey[700] : const Color(0xFFE8E8E8),
                            child: ownerAvatar == null || ownerAvatar!.isEmpty
                                ? Icon(Icons.person, size: 10,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600])
                                : null,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ownerName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isExpertVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 13, color: Color(0xFFDAA520)),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Staggered height tiers based on title hashCode for visual variety
  double get _imageHeight {
    const tiers = [120.0, 150.0, 180.0];
    return tiers[title.hashCode.abs() % tiers.length];
  }

  // Type-specific gradients — covers new format (lowercase) + old format (display name)
  static const _typeGradients = {
    // New format (AppConstants.taskTypes)
    'delivery': [Color(0xFFFCB69F), Color(0xFFFFECD2)],
    'shopping': [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
    'tutoring': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
    'translation': [Color(0xFFFDDB92), Color(0xFFD1FDFF)],
    'design': [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
    'programming': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
    'writing': [Color(0xFFFDDB92), Color(0xFFD1FDFF)],
    'photography': [Color(0xFFFFECD2), Color(0xFFFCB69F)],
    'moving': [Color(0xFF667EEA), Color(0xFF764BA2)],
    'cleaning': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'repair': [Color(0xFFF5F7FA), Color(0xFFC3CFE2)],
    'pet_care': [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
    'errand': [Color(0xFFFCB69F), Color(0xFFFFECD2)],
    'other': [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
    // Old format (backend display names)
    'Housekeeping': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'Campus Life': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
    'Second-hand & Rental': [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
    'Errand Running': [Color(0xFFFCB69F), Color(0xFFFFECD2)],
    'Skill Service': [Color(0xFFFDDB92), Color(0xFFD1FDFF)],
    'Social Help': [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
    'Transportation': [Color(0xFF667EEA), Color(0xFF764BA2)],
    'Pet Care': [Color(0xFFFBC2EB), Color(0xFFA6C1EE)],
    'Life Convenience': [Color(0xFF11998E), Color(0xFF38EF7D)],
    'Other': [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
    // Nearby services
    'service': [Color(0xFF11998E), Color(0xFF38EF7D)],
  };

  static const _typeEmojis = {
    'delivery': '🏃',
    'shopping': '🛍️',
    'tutoring': '📚',
    'translation': '🌐',
    'design': '🎨',
    'programming': '💻',
    'writing': '📝',
    'photography': '📷',
    'moving': '🚛',
    'cleaning': '🧹',
    'repair': '🔧',
    'pet_care': '🐾',
    'errand': '🏃',
    'other': '📋',
    'Housekeeping': '🏠',
    'Campus Life': '🎓',
    'Second-hand & Rental': '🛍️',
    'Errand Running': '🏃',
    'Skill Service': '🛠️',
    'Social Help': '🤝',
    'Transportation': '🚗',
    'Pet Care': '🐾',
    'Life Convenience': '🛒',
    'Other': '📋',
    'service': '🔧',
  };

  Widget _buildImageArea(bool isDark) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final height = _imageHeight;

    return Stack(
      children: [
        if (hasImage)
          AsyncImageView(
            imageUrl: Helpers.getThumbnailUrl(imageUrl!),
            fallbackUrl: Helpers.getImageUrl(imageUrl!),
            width: double.infinity,
            height: height,
          )
        else
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _typeGradients[itemType] ??
                    const [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
              ),
            ),
            child: Center(
              child: Text(
                _typeEmojis[itemType] ?? '📋',
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
        if (distanceText != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 11, color: Colors.white),
                    const SizedBox(width: 2),
                    Text(
                      distanceText!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Expert verified badge (top-right)
        if (isExpertVerified)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDAA520), Color(0xFFF0C040)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 11, color: Colors.white),
                  SizedBox(width: 2),
                  Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

}

/// Tag chip for waterfall card
class _NearbyTagChip extends StatelessWidget {
  const _NearbyTagChip({required this.label, this.isPrice = false});

  final String label;
  final bool isPrice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPrice
            ? (isDark ? const Color(0xFF2A1515) : const Color(0xFFFFF0F0))
            : (isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0FF)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isPrice ? const Color(0xFFEE5A24) : AppColors.primary,
          fontWeight: isPrice ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// Triggers load-more when scrolled into view
class _NearbyLoadMoreTrigger extends StatefulWidget {
  const _NearbyLoadMoreTrigger({required this.onVisible});

  final VoidCallback onVisible;

  @override
  State<_NearbyLoadMoreTrigger> createState() => _NearbyLoadMoreTriggerState();
}

class _NearbyLoadMoreTriggerState extends State<_NearbyLoadMoreTrigger> {
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    // Trigger on next frame when this widget is built (meaning user scrolled to it)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_triggered && mounted) {
        _triggered = true;
        widget.onVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
