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

  void _showNearbyLocationPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? pickedAddress;
    double? pickedLat;
    double? pickedLng;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.locationSetLocation,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.locationSetLocationHint,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),
              LocationInputField(
                initialValue: _city,
                showOnlineOption: false,
                onChanged: (value) => pickedAddress = value,
                onLocationPicked: (address, lat, lng) {
                  pickedAddress = address;
                  pickedLat = lat;
                  pickedLng = lng;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final address = pickedAddress;
                    if (address != null && address.isNotEmpty) {
                      setState(() => _city = address);
                      context.read<HomeBloc>().add(HomeLocationCityUpdated(address));
                      // Reload nearby data with new coordinates
                      if (pickedLat != null && pickedLng != null) {
                        _loadWithCoordinates(pickedLat!, pickedLng!);
                      }
                    }
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.l10n.commonConfirm),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
          distance: task.distance,
          tags: [task.taskType],
          price: '\u00A3${task.reward == task.reward.truncateToDouble() ? task.reward.toInt().toString() : task.reward.toStringAsFixed(2)}',
          applicantCount: task.currentParticipants,
          onTap: () => context.push('/tasks/${task.id}'),
        ),
        distance: task.distance ?? double.infinity,
      ));
    }

    // Services
    for (final service in state.nearbyServices) {
      final name = (isEn
              ? (service['service_name_en'] ?? service['service_name'])
              : service['service_name']) as String? ?? '';
      final price = service['base_price'];
      final pricingType = service['pricing_type'] as String? ?? '';
      final priceStr = price != null
          ? '\u00A3${_formatServicePrice(price)}${pricingType.isNotEmpty ? '/$pricingType' : ''}'
          : null;
      final distKm = service['distance_km'] as num?;
      final distMeters = distKm != null ? distKm.toDouble() * 1000 : null;
      final imageUrl = service['cover_image'] as String?;

      entries.add((
        widget: _NearbyWaterfallCard(
          title: name,
          imageUrl: imageUrl,
          distance: distMeters,
          price: priceStr,
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
                const Icon(Icons.location_off_outlined,
                    size: 64, color: AppColors.textTertiaryLight),
                AppSpacing.vMd,
                Text(context.l10n.homeNoNearbyTasks,
                    style: const TextStyle(color: AppColors.textSecondaryLight)),
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

        // Build mixed list of tasks + services for waterfall
        final waterfallItems = _buildWaterfallItems(state);

        final content = RefreshIndicator(
          onRefresh: () async {
            final homeBloc = context.read<HomeBloc>();
            await _loadLocation();
            await homeBloc.stream
                .firstWhere((s) => !s.isLoading, orElse: () => state);
          },
          child: CustomScrollView(
            slivers: [
              // Location bar
              SliverToBoxAdapter(
                child: _NearbyLocationBar(
                  city: _city,
                  onSwitchTap: _showNearbyLocationPicker,
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
              if (state.hasMoreNearby)
                SliverToBoxAdapter(
                  child: _NearbyLoadMoreTrigger(
                    onVisible: () {
                      context.read<HomeBloc>().add(HomeLoadNearby(
                        latitude: _currentLat,
                        longitude: _currentLng,
                        loadMore: true,
                        city: _city,
                      ));
                    },
                  ),
                ),
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

/// 附近 tab 顶部定位条
class _NearbyLocationBar extends StatelessWidget {
  const _NearbyLocationBar({
    required this.city,
    required this.onSwitchTap,
  });

  final String? city;
  final VoidCallback onSwitchTap;

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
          const Icon(Icons.location_on, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            l10n.nearbyCurrentLocation(displayCity),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSwitchTap,
            child: Text(
              l10n.nearbySwitch,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
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
    this.distance,
    this.tags = const [],
    this.price,
    this.applicantCount = 0,
    this.onTap,
  });

  final String title;
  final String? imageUrl;
  final double? distance;
  final List<String> tags;
  final String? price;
  final int applicantCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
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
            // Image area with distance badge
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageArea(bool isDark) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Stack(
      children: [
        if (hasImage)
          AsyncImageView(
            imageUrl: imageUrl!,
            width: double.infinity,
            height: 140,
          )
        else
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.task_outlined,
                size: 36,
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
        if (distance != null)
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
                      _formatDistance(distance!),
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
      ],
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
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
