import Foundation
import Combine
import CoreLocation

class TasksViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var hasMore = true
    @Published var currentPage = 1
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private let locationService: LocationService
    
    init(apiService: APIService? = nil, locationService: LocationService? = nil) {
        // 使用依赖注入或回退到默认实现
        self.apiService = apiService ?? APIService.shared
        self.locationService = locationService ?? LocationService.shared
        
        // 监听用户交互，触发智能刷新
        setupSmartRefresh()
    }
    
    /// 设置智能刷新机制
    private func setupSmartRefresh() {
        // 监听任务交互通知（申请、完成等）
        NotificationCenter.default.publisher(for: .taskUpdated)
            .sink { [weak self] _ in
                // 用户交互后，增加计数
                self?.userInteractionCount += 1
                
                // 如果交互次数达到阈值（3次），触发推荐任务刷新
                if let count = self?.userInteractionCount, count >= 3 {
                    self?.userInteractionCount = 0
                    // 延迟刷新，避免频繁请求
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self?.refreshRecommendedTasksIfNeeded()
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听网络状态变化
        setupNetworkMonitoring()
    }
    
    /// 设置网络监控
    private func setupNetworkMonitoring() {
        reachability = Reachability.shared
        
        reachability?.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                
                // 网络恢复时，如果推荐任务超过5分钟未更新，自动刷新
                if isConnected {
                    self?.refreshRecommendedTasksIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 智能刷新推荐任务（如果需要）
    private func refreshRecommendedTasksIfNeeded() {
        // 防抖：5秒内只刷新一次
        let now = Date()
        if let lastTrigger = lastRefreshTrigger,
           now.timeIntervalSince(lastTrigger) < 5.0 {
            return
        }
        lastRefreshTrigger = now
        
        // 如果距离上次加载超过5分钟，自动刷新
        if let lastLoad = lastRecommendedTasksLoadTime,
           Date().timeIntervalSince(lastLoad) > 300 {
            Logger.info("智能刷新推荐任务（距离上次加载已超过5分钟）", category: .cache)
            loadRecommendedTasks(limit: 20, algorithm: "hybrid", forceRefresh: false)
        }
    }
    
    /// 从缓存加载任务（用于初始化时立即显示，优先内存缓存，快速响应）
    func loadTasksFromCache(category: String? = nil, city: String? = nil, status: String? = nil) {
        // 先快速检查内存缓存（同步，很快）
        // 仅在没有搜索关键词时从缓存加载
        if let cachedTasks = CacheManager.shared.loadTasks(category: category, city: city) {
            let filteredCachedTasks = cachedTasks.filter { 
                if let status = status {
                    return $0.status.rawValue == status
                } else {
                    return $0.status == .open
                }
            }
            if !filteredCachedTasks.isEmpty {
                self.tasks = filteredCachedTasks
                Logger.success("初始化时从缓存加载了 \(self.tasks.count) 个任务", category: .cache)
            }
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var locationUpdateCancellable: AnyCancellable? // 位置更新监听器（单独管理）
    private var currentCategory: String?
    private var currentCity: String?
    private var currentStatus: String?
    private var currentKeyword: String?
    private var currentSortBy: String?
    private var rawTasks: [Task] = [] // 保存原始数据，用于重新排序
    private var lastLocationUpdateTime: Date? // 记录上次位置更新时间，用于防抖
    private var lastRecommendedTasksLoadTime: Date? // 记录上次推荐任务加载时间
    private var recommendedTasksRefreshTimer: Timer? // 推荐任务自动刷新定时器
    private var userInteractionCount: Int = 0 // 用户交互计数（用于智能刷新）
    @Published var isOffline: Bool = false // 离线状态
    private var reachability: Reachability? // 网络可达性监听
    private var lastRefreshTrigger: Date? // 上次刷新触发时间（用于防抖）
    
    func loadTasks(category: String? = nil, city: String? = nil, status: String? = nil, keyword: String? = nil, sortBy: String? = nil, page: Int = 1, pageSize: Int = 50, forceRefresh: Bool = false) {
        let startTime = Date()
        let endpoint = "/api/tasks"
        
        // 防止重复请求：如果正在加载且不是加载更多，则跳过
        if page == 1 && isLoading && !forceRefresh {
            Logger.warning("请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        // 如果页码为1，说明是重新加载，重置状态
        if page == 1 {
            currentPage = 1
            hasMore = true
            
            // 强制刷新时清除缓存
            if forceRefresh {
                CacheManager.shared.invalidateTasksCache()
            }
            
            // 如果 tasks 已经有数据（说明初始化时已从缓存加载），不需要再次从缓存加载
            // 直接进行网络请求，不显示加载状态
            if tasks.isEmpty {
                // 先尝试从缓存加载数据（仅第一页且无搜索关键词时，且非强制刷新）
                // 如果有缓存数据，立即显示，避免闪烁
                if !forceRefresh && (keyword == nil || keyword?.isEmpty == true) {
                    if let cachedTasks = CacheManager.shared.loadTasks(category: category, city: city) {
                        let filteredCachedTasks = cachedTasks.filter { 
                            if let status = status {
                                return $0.status.rawValue == status
                            } else {
                                return $0.status == .open
                            }
                        }
                        if !filteredCachedTasks.isEmpty {
                            self.tasks = filteredCachedTasks
                            Logger.success("从缓存加载了 \(self.tasks.count) 个任务，立即显示", category: .cache)
                            // 有缓存数据时不设置 isLoading = true，避免闪烁
                            // 继续在后台刷新数据，但不显示加载状态
                        } else {
                            // 缓存为空，需要显示加载状态
                            isLoading = true
                            tasks = []
                        }
                    } else {
                        // 没有缓存，需要显示加载状态
                        isLoading = true
                        tasks = []
                    }
                } else {
                    // 有搜索关键词或强制刷新，需要显示加载状态
                    isLoading = true
                    tasks = []
                }
            }
            // 如果 tasks 已经有数据，不设置 isLoading，直接进行后台刷新
        } else {
            isLoadingMore = true
        }
        
        errorMessage = nil
        
        // 保存当前筛选条件
        currentCategory = category
        currentCity = city
        currentStatus = status
        currentKeyword = keyword
        currentSortBy = sortBy
        
        // 只有明确使用距离排序时，才传递用户位置用于距离排序
        // 推荐任务和任务大厅不使用距离排序，也不隐藏 online 任务
        var userLat: Double? = nil
        var userLon: Double? = nil
        if sortBy == "distance" || sortBy == "nearby" {
            // 只有"附近"功能才传递用户位置
            if let userLocation = locationService.currentLocation {
                userLat = userLocation.latitude
                userLon = userLocation.longitude
            }
        }
        
        // 使用 APIService 的 getTasks 方法
        apiService.getTasks(page: page, pageSize: pageSize, type: category, location: city, keyword: keyword, sortBy: sortBy, userLatitude: userLat, userLongitude: userLon)
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务列表")
                    self?.errorMessage = error.userFriendlyMessage
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // 优化：将数据处理移到后台线程，避免阻塞主线程
                DispatchQueue.global(qos: .userInitiated).async {
                    // 如果指定了状态，过滤任务；否则默认只显示开放中的任务
                    var filteredTasks = response.tasks
                    
                    if let status = status {
                        filteredTasks = filteredTasks.filter { $0.status.rawValue == status }
                    } else {
                        // 默认只显示开放中的任务（未到进行中的任务）
                        filteredTasks = filteredTasks.filter { $0.status == .open }
                    }
                    
                    // 额外确保：排除进行中、已完成、已取消的任务
                    filteredTasks = filteredTasks.filter { task in
                        task.status == .open
                    }
                    
                    // 如果是第一页，保存到缓存（仅第一页且无搜索关键词时）
                    if page == 1 && (keyword == nil || keyword?.isEmpty == true) {
                        CacheManager.shared.saveTasks(filteredTasks, category: category, city: city)
                        Logger.success("已缓存 \(filteredTasks.count) 个任务", category: .cache)
                        
                        // 索引任务到 Spotlight（仅第一页，避免索引过多）
                        // 只索引前 20 个任务，避免性能问题
                        let tasksToIndex = Array(filteredTasks.prefix(20))
                        let indexData = tasksToIndex.map { task in
                            (
                                id: task.id,
                                title: task.title,
                                description: task.description,
                                taskType: task.taskType,
                                location: task.location,
                                reward: task.reward
                            )
                        }
                        SpotlightIndexer.shared.indexTasks(indexData)
                    }
                    
                    // 回到主线程更新UI
                    DispatchQueue.main.async {
                        // 保存原始数据
                        if page == 1 {
                            self.rawTasks = filteredTasks
                        } else {
                            self.rawTasks.append(contentsOf: filteredTasks)
                        }
                        
                        // 直接使用后端返回的数据（后端已经按距离排序并过滤了Online任务）
                        if page == 1 {
                            self.tasks = filteredTasks
                        } else {
                            self.tasks.append(contentsOf: filteredTasks)
                        }
                        
                        // 检查是否还有更多数据
                        self.hasMore = filteredTasks.count == pageSize
                        self.currentPage = page
                        
                        self.isLoading = false
                        self.isLoadingMore = false
                    }
                }
                
                // 监听位置更新，当位置可用时重新加载任务（仅附近视图）
                // 取消之前的监听器，避免重复触发
                locationUpdateCancellable?.cancel()
                
                if city == nil && keyword == nil {
                    locationUpdateCancellable = self.locationService.$currentLocation
                        .debounce(for: .seconds(2), scheduler: DispatchQueue.main) // 增加防抖时间到2秒
                        .sink { [weak self] newLocation in
                            guard let self = self,
                                  let newLocation = newLocation else { return }
                            
                            // 检查位置是否真的发生了变化（避免微小变化触发重新加载）
                            let now = Date()
                            if let lastUpdate = self.lastLocationUpdateTime,
                               now.timeIntervalSince(lastUpdate) < 5.0 {
                                // 5秒内只更新一次
                                return
                            }
                            
                            // 检查位置变化是否足够大（至少100米）
                            if let lastLocation = self.locationService.currentLocation {
                                let distance = CLLocation(
                                    latitude: lastLocation.latitude,
                                    longitude: lastLocation.longitude
                                ).distance(from: CLLocation(
                                    latitude: newLocation.latitude,
                                    longitude: newLocation.longitude
                                ))
                                
                                if distance < 100 {
                                    // 位置变化小于100米，不重新加载
                                    return
                                }
                            }
                            
                            Logger.info("位置已更新，重新加载任务列表", category: .general)
                            self.lastLocationUpdateTime = now
                            
                            // 重新加载第一页以获取按新位置排序的任务
                            self.loadTasks(
                                category: self.currentCategory,
                                city: self.currentCity,
                                status: self.currentStatus,
                                keyword: self.currentKeyword,
                                sortBy: self.currentSortBy,
                                page: 1,
                                forceRefresh: true
                            )
                        }
                } else {
                    // 不是附近视图，取消位置监听
                    locationUpdateCancellable = nil
                }
            })
            .store(in: &cancellables)
    }
    
    func loadMoreTasks() {
        guard !isLoadingMore && hasMore else { return }
        loadTasks(
            category: currentCategory,
            city: currentCity,
            status: currentStatus,
            keyword: currentKeyword,
            sortBy: currentSortBy,
            page: currentPage + 1
        )
    }
    
    /// 加载推荐任务（带重试机制）
    func loadRecommendedTasks(limit: Int = 20, algorithm: String = "hybrid", taskType: String? = nil, location: String? = nil, keyword: String? = nil, forceRefresh: Bool = false, retryCount: Int = 0) {
        let startTime = Date()
        let endpoint = "/api/recommendations"
        let maxRetries = 2
        
        // 防止重复请求
        if isLoading && !forceRefresh && retryCount == 0 {
            Logger.warning("推荐任务请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        // 如果强制刷新，只清除推荐任务缓存（不清除普通任务缓存）
        if forceRefresh {
            CacheManager.shared.invalidateRecommendedTasksCache()
            isLoading = true
            tasks = []
        } else {
            // 如果不是强制刷新，先尝试从推荐任务专用缓存加载
            if let cachedRecommendedTasks = CacheManager.shared.loadTasks(category: taskType, city: location, isRecommended: true) {
                if !cachedRecommendedTasks.isEmpty {
                    // 立即显示缓存的推荐任务（包含推荐原因）
                    self.tasks = cachedRecommendedTasks
                    Logger.success("从推荐任务缓存加载了 \(cachedRecommendedTasks.count) 个任务（包含推荐原因）", category: .cache)
                    
                    // 离线模式：如果有缓存数据，直接使用，不进行网络请求
                    if isOffline {
                        Logger.info("离线模式：使用缓存的推荐任务", category: .cache)
                        self.isLoading = false
                        return
                    }
                    
                    // 在线模式：继续在后台刷新，不显示加载状态（保持现有数据）
                    isLoading = false
                } else {
                    // 离线模式且无缓存：显示错误
                    if isOffline {
                        self.errorMessage = "离线模式：暂无缓存的推荐任务"
                        self.isLoading = false
                        return
                    }
                    isLoading = true
                    tasks = []
                }
            } else {
                // 离线模式且无缓存：显示错误
                if isOffline {
                    self.errorMessage = "离线模式：暂无缓存的推荐任务"
                    self.isLoading = false
                    return
                }
                isLoading = true
                tasks = []
            }
        }
        
        errorMessage = nil
        
        // 增强：获取GPS位置（如果用户允许位置权限）
        var userLat: Double? = nil
        var userLon: Double? = nil
        if let userLocation = locationService.currentLocation {
            userLat = userLocation.latitude
            userLon = userLocation.longitude
            Logger.debug("发送GPS位置到推荐API: lat=\(userLat!), lon=\(userLon!)", category: .api)
        }
        
        // 调用推荐 API（增强：包含GPS位置）
        apiService.getTaskRecommendations(limit: limit, algorithm: algorithm, taskType: taskType, location: location, keyword: keyword, latitude: userLat, longitude: userLon)
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载推荐任务")
                    
                    // 重试机制：网络错误且未达到最大重试次数时自动重试
                    if retryCount < maxRetries && self?.isNetworkOrTimeoutError(error) == true {
                        Logger.info("推荐任务加载失败，\(maxRetries - retryCount)秒后重试...", category: .api)
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(maxRetries - retryCount)) { [weak self] in
                            self?.loadRecommendedTasks(
                                limit: limit,
                                algorithm: algorithm,
                                taskType: taskType,
                                location: location,
                                keyword: keyword,
                                forceRefresh: forceRefresh,
                                retryCount: retryCount + 1
                            )
                        }
                    } else {
                        self?.errorMessage = error.userFriendlyMessage
                    }
                    
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // 将推荐任务转换为 Task 对象
                let recommendedTasks = response.recommendations.map { recommendation -> Task in
                    recommendation.toTask()
                }
                
                // 修复：立即显示所有推荐任务（包括没有图片的），提升用户体验
                // 不再过滤掉没有图片的任务，确保所有推荐任务都能显示
                DispatchQueue.main.async {
                    self.tasks = recommendedTasks
                    self.isLoading = false
                    self.errorMessage = nil
                    self.lastRecommendedTasksLoadTime = Date()
                    
                    // 保存到推荐任务专用缓存（仅第一页）
                    if limit <= 20 {
                        CacheManager.shared.saveTasks(recommendedTasks, category: taskType, city: location, isRecommended: true)
                        Logger.success("已缓存 \(recommendedTasks.count) 个推荐任务", category: .cache)
                    }
                }
                
                // 异步补充缺少图片的任务（后台进行，不阻塞UI）
                let tasksWithoutImages = recommendedTasks.filter { $0.images == nil || ($0.images?.isEmpty ?? true) }
                if !tasksWithoutImages.isEmpty {
                    Logger.debug("发现 \(tasksWithoutImages.count) 个推荐任务缺少图片，异步补充", category: .api)
                    
                    // 限制最多5个任务补充图片，避免过多请求影响性能
                    let taskIdsToFetch = Array(tasksWithoutImages.prefix(5).map { $0.id })
                    let dispatchGroup = DispatchGroup()
                    var taskImageMap: [Int: [String]] = [:]
                    var detailFetchCancellables = Set<AnyCancellable>()
                    let timeout: TimeInterval = 3.0 // 3秒超时
                    
                    for taskId in taskIdsToFetch {
                        dispatchGroup.enter()
                        let startTime = Date()
                        
                        self.apiService.getTaskDetail(taskId: taskId)
                            .timeout(timeout, scheduler: DispatchQueue.global())
                            .sink(
                                receiveCompletion: { completion in
                                    dispatchGroup.leave()
                                    if case .failure(let error) = completion {
                                        Logger.debug("获取任务 \(taskId) 图片失败: \(error.localizedDescription)", category: .api)
                                    }
                                },
                                receiveValue: { fullTask in
                                    if let images = fullTask.images, !images.isEmpty {
                                        taskImageMap[taskId] = images
                                        let duration = Date().timeIntervalSince(startTime)
                                        Logger.debug("成功获取任务 \(taskId) 的图片: \(images.count) 张 (耗时: \(String(format: "%.2f", duration))s)", category: .api)
                                    }
                                }
                            )
                            .store(in: &detailFetchCancellables)
                    }
                    
                    // 等待所有请求完成（带超时保护）
                    dispatchGroup.notify(queue: .global(qos: .utility)) {
                        // 更新推荐任务的图片信息
                        var updatedTasks = recommendedTasks
                        var hasUpdates = false
                        
                        for (index, task) in updatedTasks.enumerated() {
                            if let images = taskImageMap[task.id] {
                                hasUpdates = true
                                // 创建新的 Task 对象，包含图片信息
                                updatedTasks[index] = Task(
                                    id: task.id,
                                    title: task.title,
                                    titleEn: task.titleEn,
                                    titleZh: task.titleZh,
                                    description: task.description,
                                    descriptionEn: task.descriptionEn,
                                    descriptionZh: task.descriptionZh,
                                    taskType: task.taskType,
                                    location: task.location,
                                    latitude: task.latitude,
                                    longitude: task.longitude,
                                    reward: task.reward,
                                    baseReward: task.baseReward,
                                    agreedReward: task.agreedReward,
                                    currency: task.currency,
                                    status: task.status,
                                    images: images, // 使用补充的图片
                                    createdAt: task.createdAt,
                                    deadline: task.deadline,
                                    isFlexible: task.isFlexible,
                                    isPublic: task.isPublic,
                                    posterId: task.posterId,
                                    takerId: task.takerId,
                                    originatingUserId: task.originatingUserId,
                                    taskLevel: task.taskLevel,
                                    pointsReward: task.pointsReward,
                                    isMultiParticipant: task.isMultiParticipant,
                                    maxParticipants: task.maxParticipants,
                                    minParticipants: task.minParticipants,
                                    currentParticipants: task.currentParticipants,
                                    poster: task.poster,
                                    isRecommended: task.isRecommended,
                                    matchScore: task.matchScore,
                                    recommendationReason: task.recommendationReason,
                                    taskSource: task.taskSource
                                )
                            }
                        }
                        
                        // 如果有更新，刷新UI和缓存
                        if hasUpdates {
                            DispatchQueue.main.async {
                                self.tasks = updatedTasks
                                // 更新缓存
                                if limit <= 20 {
                                    CacheManager.shared.saveTasks(updatedTasks, category: taskType, city: location, isRecommended: true)
                                    Logger.success("已更新缓存，补充了 \(taskImageMap.count) 个任务的图片", category: .cache)
                                }
                            }
                        }
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    /// 检查错误是否是网络错误或超时错误
    private func isNetworkOrTimeoutError(_ error: APIError) -> Bool {
        switch error {
        case .requestFailed(let underlyingError):
            // 检查是否是 URLError 的网络错误或超时错误
            if let urlError = underlyingError as? URLError {
                switch urlError.code {
                case .notConnectedToInternet,
                     .networkConnectionLost,
                     .timedOut,
                     .cannotConnectToHost,
                     .cannotFindHost,
                     .dnsLookupFailed:
                    return true
                default:
                    return false
                }
            }
            return false
        default:
            return false
        }
    }
    
    /// 按距离排序任务（基于城市距离）
    private func sortTasksByDistance() {
        Logger.debug("sortTasksByDistance() 被调用", category: .general)
        Logger.debug("rawTasks.count = \(rawTasks.count)", category: .general)
        Logger.debug("locationService.currentLocation = \(locationService.currentLocation != nil ? "有位置" : "无位置")", category: .general)
        Logger.debug("locationService.authorizationStatus = \(locationService.authorizationStatus.rawValue)", category: .general)
        
        guard !rawTasks.isEmpty else {
            Logger.warning("原始任务数据为空，无法排序", category: .general)
            return
        }
        
        var tasks = rawTasks
        
        // 计算距离并排序（如果用户位置可用）
        if let userLocation = locationService.currentLocation {
            let userCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            Logger.debug("开始按城市距离排序任务", category: .general)
            Logger.debug("用户位置: 纬度 \(String(format: "%.4f", userLocation.latitude)), 经度 \(String(format: "%.4f", userLocation.longitude))", category: .general)
            if let cityName = userLocation.cityName {
                Logger.debug("用户城市: \(cityName)", category: .general)
            }
            
            // 按距离排序（由近到远）
            // 由于 Task 可能没有 distance 字段，我们需要在排序时计算距离
            tasks.sort { task1, task2 in
                let distance1 = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: task1.location
                ) ?? Double.infinity
                let distance2 = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: task2.location
                ) ?? Double.infinity
                return distance1 < distance2
            }
            
            Logger.success("已按城市距离排序任务（共\(tasks.count)条）", category: .general)
        } else {
            Logger.warning("用户位置不可用，保持原始顺序", category: .general)
            Logger.warning("位置服务状态: \(locationService.authorizationStatus.rawValue)", category: .general)
        }
        
        // 更新到主线程
        DispatchQueue.main.async { [weak self] in
            self?.tasks = tasks
        }
    }
    
    deinit {
        // 清理位置更新监听器
        locationUpdateCancellable?.cancel()
        locationUpdateCancellable = nil
        
        // 清理推荐任务刷新定时器
        recommendedTasksRefreshTimer?.invalidate()
        recommendedTasksRefreshTimer = nil
    }
}

