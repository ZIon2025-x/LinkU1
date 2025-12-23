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
            isLoading = true
            currentPage = 1
            hasMore = true
            
            // 强制刷新时清除缓存
            if forceRefresh {
                CacheManager.shared.invalidateTasksCache()
            }
            
            // 尝试从缓存加载数据（仅第一页且无搜索关键词时，且非强制刷新）
            if !forceRefresh && (keyword == nil || keyword?.isEmpty == true) {
                if let cachedTasks = CacheManager.shared.loadTasks(category: category, city: city) {
                    self.tasks = cachedTasks.filter { $0.status == .open }
                    Logger.success("从缓存加载了 \(self.tasks.count) 个任务", category: .cache)
                    isLoading = false
                    // 继续在后台刷新数据
                }
            } else {
                tasks = []
            }
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
    }
}

