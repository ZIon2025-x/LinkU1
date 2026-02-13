part of 'home_view.dart';

/// 对标iOS: 横向任务卡片 (完全对标 iOS TaskCard 风格)
/// 图片(160px) + 3段渐变遮罩 + ultraThinMaterial毛玻璃标签 + 任务类型标签 + 双层阴影
class _HorizontalTaskCard extends StatelessWidget {
  const _HorizontalTaskCard({required this.task});

  final Task task;

  // 任务类型图标 — 使用统一映射
  IconData _taskTypeIcon(String taskType) => TaskTypeHelper.getIcon(taskType);

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return context.l10n.homeDeadlineExpired;
    if (diff.inDays > 0) return context.l10n.homeDeadlineDays(diff.inDays);
    if (diff.inHours > 0) return context.l10n.homeDeadlineHours(diff.inHours);
    return context.l10n.homeDeadlineMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.safePush('/tasks/${task.id}');
      },
      child: Container(
        width: 220,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 0.5pt separator边框
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          // 单层阴影：减少 GPU 高斯模糊开销（列表中卡片数量多，累积影响显著）
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片区域 (对标iOS + 3段渐变 + 毛玻璃标签) =====
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位背景（对标iOS placeholderBackground）
                  if (task.firstImage != null)
                    Hero(
                      tag: 'task_image_${task.id}',
                      child: AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: 220,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        _taskTypeIcon(task.taskType),
                        color: AppColors.primary.withValues(alpha: 0.25),
                        size: 44,
                      ),
                    ),

                  // 对标iOS: 3段渐变遮罩（0.2→0.0→0.4）
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.40),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 左上: 位置标签 (半透明容器，避免 BackdropFilter 在列表中的性能开销)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: AppRadius.allPill,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              task.isOnline
                                  ? Icons.language
                                  : Icons.location_on,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 80),
                              child: Text(
                                task.blurredLocation ?? task.location!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签（与 frontend .taskTypeBadge 一致：蓝紫渐变）
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.taskTypeBadgeGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppRadius.allPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _taskTypeIcon(task.taskType),
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            task.taskTypeText,
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

                  // 右上: 推荐徽章
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradientOrange,
                        ),
                        borderRadius: AppRadius.allPill,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.busy
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            context.l10n.homeRecommendedBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 内容区域 (对标iOS - title + deadline + price badge) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题（对标iOS .body字号 + lineLimit(2)）
                  Text(
                    task.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 底部: 截止时间 + 价格标签（对标iOS底部信息栏）
                  Row(
                      children: [
                        // 截止时间 (对标iOS clock.fill + formatDeadline)
                        if (task.deadline != null) ...[
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: task.isExpired
                                ? AppColors.error
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatDeadline(context, task.deadline!),
                              style: TextStyle(
                                fontSize: 11,
                                color: task.isExpired
                                    ? AppColors.error
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        // 价格标签 (对标iOS 绿色Capsule + £符号分离)
                        if (task.reward > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: AppRadius.allPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  task.currency == 'GBP' ? '£' : '\$',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  task.reward.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: NearbyTasksView (附近Tab)
/// 使用 Geolocator 获取设备位置，加载附近任务
class _NearbyTab extends StatefulWidget {
  const _NearbyTab();

  @override
  State<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<_NearbyTab> {
  bool _locationLoading = false;
  String? _city; // 反向地理编码得到的城市名

  // 默认坐标（伦敦）
  static const _defaultLat = 51.5074;
  static const _defaultLng = -0.1278;

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

  /// 反向地理编码获取城市名，用于同城过滤
  Future<void> _resolveCity(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        // locality 通常是城市名（如 "Birmingham"、"London"）
        _city = placemarks.first.locality;
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
        context.read<HomeBloc>().add(HomeLoadNearby(
              latitude: position.latitude,
              longitude: position.longitude,
              city: _city,
            ));
      }
    } catch (_) {
      // 精确定位失败不影响已加载的数据
    }
  }

  void _loadWithCoordinates(double lat, double lng) {
    if (!mounted) return;
    setState(() => _locationLoading = false);
    context.read<HomeBloc>().add(HomeLoadNearby(
          latitude: lat,
          longitude: lng,
          city: _city,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    if (_locationLoading) {
      const body = SkeletonTopImageCardList(itemCount: 3, imageHeight: 140);
      return isDesktop ? const ContentConstraint(child: body) : body;
    }

    return BlocBuilder<HomeBloc, HomeState>(
      // 仅在附近任务数据或加载状态变化时重建
      buildWhen: (prev, curr) =>
          prev.nearbyTasks != curr.nearbyTasks ||
          prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading && state.nearbyTasks.isEmpty) {
          const body = SkeletonTopImageCardList(itemCount: 3, imageHeight: 140);
          return isDesktop ? const ContentConstraint(child: body) : body;
        }

        if (state.nearbyTasks.isEmpty) {
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

        final refresh = RefreshIndicator(
          onRefresh: () async {
            final homeBloc = context.read<HomeBloc>();
            await _loadLocation();
            await homeBloc.stream.firstWhere(
              (s) => !s.isLoading,
              orElse: () => state,
            );
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.nearbyTasks.length,
            separatorBuilder: (_, __) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              return AnimatedListItem(
                index: index,
                child: _TaskCard(task: state.nearbyTasks[index]),
              );
            },
          ),
        );
        return isDesktop ? ContentConstraint(child: refresh) : refresh;
      },
    );
  }
}
