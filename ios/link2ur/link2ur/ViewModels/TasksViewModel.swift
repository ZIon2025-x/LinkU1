import Foundation
import Combine
import CoreLocation

class TasksViewModel: ObservableObject {
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
    private var currentCategory: String?
    private var currentCity: String?
    private var currentStatus: String?
    private var currentKeyword: String?
    private var currentSortBy: String?
    private var rawTasks: [Task] = [] // 保存原始数据，用于重新排序
    
    func loadTasks(category: String? = nil, city: String? = nil, status: String? = nil, keyword: String? = nil, sortBy: String? = nil, page: Int = 1, pageSize: Int = 50, forceRefresh: Bool = false) {
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
                    print("✅ 从缓存加载了 \(self.tasks.count) 个任务")
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
        
        // 如果是"附近"视图（没有指定城市），传递用户位置用于距离排序
        var userLat: Double? = nil
        var userLon: Double? = nil
        if city == nil && keyword == nil {
            // "附近"视图：传递用户位置
            if let userLocation = locationService.currentLocation {
                userLat = userLocation.latitude
                userLon = userLocation.longitude
            }
        }
        
        // 使用 APIService 的 getTasks 方法
        apiService.getTasks(page: page, pageSize: pageSize, type: category, location: city, keyword: keyword, sortBy: sortBy, userLatitude: userLat, userLongitude: userLon)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务列表")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
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
                
                // 如果是第一页，保存到缓存（仅第一页且无搜索关键词时）
                if page == 1 && (keyword == nil || keyword?.isEmpty == true) {
                    CacheManager.shared.saveTasks(self.tasks, category: category, city: city)
                    print("✅ 已缓存 \(self.tasks.count) 个任务")
                }
                
                // 检查是否还有更多数据
                self.hasMore = filteredTasks.count == pageSize
                self.currentPage = page
                
                self.isLoading = false
                self.isLoadingMore = false
                
                // 监听位置更新，当位置可用时重新加载任务（仅附近视图）
                if city == nil && keyword == nil {
                    self.locationService.$currentLocation
                        .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        .sink { [weak self] newLocation in
                            if newLocation != nil {
                                print("🔄 [TasksViewModel] 位置已更新，重新加载任务列表")
                                // 重新加载第一页以获取按新位置排序的任务
                                self?.loadTasks(
                                    category: self?.currentCategory,
                                    city: self?.currentCity,
                                    status: self?.currentStatus,
                                    keyword: self?.currentKeyword,
                                    sortBy: self?.currentSortBy,
                                    page: 1,
                                    forceRefresh: true
                                )
                            }
                        }
                        .store(in: &self.cancellables)
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
        print("🔍 [TasksViewModel] sortTasksByDistance() 被调用")
        print("🔍 [TasksViewModel] rawTasks.count = \(rawTasks.count)")
        print("🔍 [TasksViewModel] locationService.currentLocation = \(locationService.currentLocation != nil ? "有位置" : "无位置")")
        print("🔍 [TasksViewModel] locationService.authorizationStatus = \(locationService.authorizationStatus.rawValue)")
        
        guard !rawTasks.isEmpty else {
            print("⚠️ [TasksViewModel] 原始任务数据为空，无法排序")
            return
        }
        
        var tasks = rawTasks
        
        // 计算距离并排序（如果用户位置可用）
        if let userLocation = locationService.currentLocation {
            let userCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            print("📍 [TasksViewModel] 开始按城市距离排序任务")
            print("📍 [TasksViewModel] 用户位置: 纬度 \(String(format: "%.4f", userLocation.latitude)), 经度 \(String(format: "%.4f", userLocation.longitude))")
            if let cityName = userLocation.cityName {
                print("📍 [TasksViewModel] 用户城市: \(cityName)")
            }
            
            // 计算每个任务的距离（基于城市）
            // Task 模型的 location 是 String 类型（非可选），直接使用
            for task in tasks {
                let distance = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: task.location
                )
                
                if let dist = distance {
                    print("  - \(task.title) [\(task.location)]: \(String(format: "%.2f", dist)) km")
                } else {
                    print("  - \(task.title) [\(task.location)]: 无法计算距离")
                }
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
            
            print("✅ [TasksViewModel] 已按城市距离排序任务（共\(tasks.count)条）")
            print("📊 [TasksViewModel] 排序结果（前5名）:")
            for (index, task) in tasks.prefix(5).enumerated() {
                let dist = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: task.location
                )
                let distStr = dist.map { String(format: "%.2f km", $0) } ?? "未知"
                print("  \(index + 1). \(task.title) [\(task.location)] - \(distStr)")
            }
        } else {
            print("⚠️ [TasksViewModel] 用户位置不可用，保持原始顺序")
            print("⚠️ [TasksViewModel] 位置服务状态: \(locationService.authorizationStatus.rawValue)")
        }
        
        // 更新到主线程
        DispatchQueue.main.async { [weak self] in
            self?.tasks = tasks
        }
    }
}

