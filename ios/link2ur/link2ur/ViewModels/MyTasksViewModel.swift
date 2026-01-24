import Foundation
import Combine

// 用户任务申请记录（用于"我的任务"页面的待处理申请标签页）
struct UserTaskApplication: Codable, Identifiable {
    let id: Int
    let taskId: Int
    let taskTitle: String
    let taskTitleEn: String?
    let taskTitleZh: String?
    let taskReward: Double
    let taskLocation: String
    let taskStatus: String
    let status: String
    let message: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case taskTitle = "task_title"
        case taskTitleEn = "task_title_en"
        case taskTitleZh = "task_title_zh"
        case taskReward = "task_reward"
        case taskLocation = "task_location"
        case taskStatus = "task_status"
        case status
        case message
        case createdAt = "created_at"
    }
    
    var displayTitle: String {
        let currentLang = LocalizationHelper.currentLanguage
        if currentLang == "en", let titleEn = taskTitleEn, !titleEn.isEmpty {
            return titleEn
        } else if currentLang == "zh-Hans" || currentLang == "zh-Hant", let titleZh = taskTitleZh, !titleZh.isEmpty {
            return titleZh
        }
        return taskTitle
    }
}

enum TaskFilterType: String, CaseIterable {
    case all = "全部"
    case posted = "我发布的"
    case accepted = "我接受的"
}

enum TaskStatusFilter: String, CaseIterable {
    case all = "全部"
    case open = "开放中"
    case inProgress = "进行中"
    case completed = "已完成"
    case cancelled = "已取消"
    
    var apiValue: String? {
        switch self {
        case .all:
            return nil
        case .open:
            return "open"
        case .inProgress:
            return "in_progress"
        case .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        }
    }
}

// 标签页类型（参考 frontend）
enum TaskTab: String, CaseIterable {
    case all
    case posted
    case taken
    case inProgress
    case pending
    case completed
    case cancelled
    
    var localizedName: String {
        switch self {
        case .all: return LocalizationKey.myTasksTabAll.localized
        case .posted: return LocalizationKey.myTasksTabPosted.localized
        case .taken: return LocalizationKey.myTasksTabTaken.localized
        case .inProgress: return LocalizationKey.profileInProgress.localized
        case .pending: return LocalizationKey.myTasksTabPending.localized
        case .completed: return LocalizationKey.myTasksTabCompleted.localized
        case .cancelled: return LocalizationKey.myTasksTabCancelled.localized
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "📋"
        case .posted: return "📤"
        case .taken: return "📥"
        case .inProgress: return "🔄"
        case .pending: return "⏳"
        case .completed: return "✅"
        case .cancelled: return "❌"
        }
    }
}

// 任务更新通知
extension Notification.Name {
    static let taskStatusUpdated = Notification.Name("taskStatusUpdated")
    static let taskUpdated = Notification.Name("taskUpdated")
    static let refreshRecommendedTasks = Notification.Name("refreshRecommendedTasks")
    static let refreshHomeContent = Notification.Name("refreshHomeContent") // 刷新首页所有内容
}

class MyTasksViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    private let cacheManager = CacheManager.shared
    private let reachability = Reachability.shared
    
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var isLoadingCompletedTasks = false // 单独跟踪已完成任务的加载状态
    @Published var errorMessage: String?
    @Published var applications: [UserTaskApplication] = [] // 申请记录
    @Published var isOffline = false // 网络状态
    
    // 缓存统计
    private var cacheHits = 0
    private var cacheMisses = 0
    
    var filterType: TaskFilterType = .all
    var statusFilter: TaskStatusFilter = .all
    var currentTab: TaskTab = .all
    var currentUserId: String? // 从View传入当前用户ID
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    // 缓存键（统一使用 all，因为"全部"标签页包含所有任务）
    private var cacheKey: String {
        guard let userId = currentUserId else { return "my_tasks_all" }
        // 使用统一的缓存键，因为"全部"标签页包含所有状态的任务
        // 其他标签页只是过滤显示，不需要单独的缓存
        return "my_tasks_\(userId)_all"
    }
    
    private var applicationsCacheKey: String {
        guard let userId = currentUserId else { return "my_applications" }
        return "my_applications_\(userId)"
    }
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
        setupObservers()
    }
    
    deinit {
        cancellables.removeAll()
        NotificationCenter.default.removeObserver(self)
    }
    
    // 设置观察者
    private func setupObservers() {
        // 监听网络状态变化
        reachability.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOffline = !isConnected
                if isConnected {
                    // 网络恢复时，后台刷新数据
                    self?.refreshIfNeeded()
                }
            }
            .store(in: &cancellables)
        
        // 监听任务状态更新通知
        NotificationCenter.default.publisher(for: .taskStatusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let task = notification.object as? Task {
                    self?.updateTask(task)
                }
            }
            .store(in: &cancellables)
        
        // 监听任务更新通知
        NotificationCenter.default.publisher(for: .taskUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let task = notification.object as? Task {
                    self?.updateTask(task)
                }
            }
            .store(in: &cancellables)
    }
    
    // 网络恢复时刷新数据（如果需要）
    private func refreshIfNeeded() {
        // 如果数据为空或超过5分钟，刷新
        if tasks.isEmpty {
            loadTasks(forceRefresh: false)
        } else if let lastUpdate = lastUpdateTime, Date().timeIntervalSince(lastUpdate) > 300 {
            loadTasks(forceRefresh: false)
        }
    }
    
    // 记录最后更新时间
    private var lastUpdateTime: Date?
    
    // 缓存统计数据，避免重复计算
    private var cachedStats: (total: Int, posted: Int, taken: Int, completed: Int, pending: Int, inProgress: Int)?
    private var lastTasksCount: Int = 0
    private var lastApplicationsCount: Int = 0
    private var lastUserId: String?
    
    // 统计数据（使用缓存优化性能）
    var totalTasksCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.total ?? 0
    }
    
    var postedTasksCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.posted ?? 0
    }
    
    var takenTasksCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.taken ?? 0
    }
    
    var completedTasksCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.completed ?? 0
    }
    
    var pendingApplicationsCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.pending ?? 0
    }
    
    var inProgressTasksCount: Int {
        updateStatsIfNeeded()
        return cachedStats?.inProgress ?? 0
    }
    
    private func updateStatsIfNeeded() {
        // 如果数据没有变化，使用缓存
        if cachedStats != nil,
           tasks.count == lastTasksCount,
           applications.count == lastApplicationsCount,
           currentUserId == lastUserId {
            return
        }
        
        // 重新计算统计数据
        let total = tasks.count
        let posted: Int
        let taken: Int
        let completed = tasks.filter { $0.status == .completed }.count
        let inProgress = tasks.filter { $0.status == .inProgress }.count
        let pending = applications.filter { app in
            app.status == "pending" && app.taskStatus != "cancelled"
        }.count
        
        if let userId = currentUserId {
            posted = tasks.filter { task in
                if let posterId = task.posterId, String(posterId) == userId {
                    return task.status != .cancelled
                }
                return false
            }.count
            
            taken = tasks.filter { task in
                if let takerId = task.takerId, String(takerId) == userId {
                    return task.status != .cancelled
                }
                return false
            }.count
        } else {
            posted = 0
            taken = 0
        }
        
        cachedStats = (total, posted, taken, completed, pending, inProgress)
        lastTasksCount = tasks.count
        lastApplicationsCount = applications.count
        lastUserId = currentUserId
    }
    
    // 获取待处理申请列表
    func getPendingApplications() -> [UserTaskApplication] {
        applications.filter { app in
            app.status == "pending" && app.taskStatus != "cancelled"
        }
    }
    
    // 缓存过滤后的任务，避免重复计算
    private var cachedFilteredTasks: [Task]?
    private var lastFilterKey: String = ""
    
    // 根据当前标签页获取过滤后的任务（使用缓存优化性能）
    func getFilteredTasks() -> [Task] {
        guard let userId = currentUserId else { return [] }
        
        // 生成缓存键
        let filterKey = "\(currentTab.rawValue)_\(userId)_\(tasks.count)"
        
        // 如果过滤条件没变，返回缓存
        if let cached = cachedFilteredTasks, filterKey == lastFilterKey {
            return cached
        }
        
        // 重新计算过滤后的任务
        let filtered: [Task]
        switch currentTab {
        case .all:
            filtered = tasks
        case .posted:
            filtered = tasks.filter { task in
                if let posterId = task.posterId, String(posterId) == userId {
                    return task.status != .cancelled
                }
                return false
            }
        case .taken:
            filtered = tasks.filter { task in
                if let takerId = task.takerId, String(takerId) == userId {
                    return task.status != .cancelled
                }
                return false
            }
        case .inProgress:
            filtered = tasks.filter { $0.status == .inProgress }
        case .pending:
            filtered = [] // 待处理申请显示在单独的列表中
        case .completed:
            filtered = tasks.filter { $0.status == .completed }
        case .cancelled:
            filtered = tasks.filter { $0.status == .cancelled }
        }
        
        cachedFilteredTasks = filtered
        lastFilterKey = filterKey
        return filtered
    }
    
    func loadTasks(forceRefresh: Bool = false) {
        // 如果不强制刷新，先尝试从缓存加载
        if !forceRefresh {
            loadTasksFromCache()
        }
        
        // 防止重复请求
        guard !isLoading else {
            Logger.warning("我的任务请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 如果当前标签页是"全部"，并行加载所有状态的任务
        if currentTab == .all {
            loadAllTasksInParallel(forceRefresh: forceRefresh)
            return
        }
        
        var endpoint = "/api/users/my-tasks?limit=100"
        
        // 根据筛选类型添加参数
        switch filterType {
        case .all:
            break // 不添加额外参数
        case .posted:
            endpoint += "&role=poster"
        case .accepted:
            endpoint += "&role=taker"
        }
        
        // 根据状态筛选添加参数
        // 如果当前标签页是"已完成"，明确请求已完成的任务
        if currentTab == .completed {
            endpoint += "&status=completed"
        } else if currentTab == .inProgress {
            endpoint += "&status=in_progress"
        } else if let statusValue = statusFilter.apiValue {
            endpoint += "&status=\(statusValue)"
        }
        
        // 加载任务列表
        let mainRequest = apiService.request([Task].self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载我的任务")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] tasks in
                guard let self = self else { return }
                
                // 客户端过滤：确保只显示与当前用户相关的任务
                var filteredTasks = tasks
                
                if let userId = self.currentUserId {
                    filteredTasks = filteredTasks.filter { task in
                        // 检查是否是用户发布的任务
                        if let posterId = task.posterId, String(posterId) == userId {
                            return true
                        }
                        // 检查是否是用户接受的任务
                        if let takerId = task.takerId, String(takerId) == userId {
                            return true
                        }
                        // 检查是否是用户申请活动创建的任务（包括多人任务中 poster_id 为 None 的情况）
                        if let originatingUserId = task.originatingUserId, String(originatingUserId) == userId {
                            return true
                        }
                        // 对于多人任务，如果任务的 posterId、takerId 和 originatingUserId 都不匹配用户ID，
                        // 但任务已经在 API 响应中，说明用户是参与者（后端已经通过 TaskParticipant join 返回）
                        // 后端已经过滤了，所以这里信任后端返回的数据
                        if task.isMultiParticipant == true {
                            // 只有在 posterId、takerId 和 originatingUserId 都不匹配时，才认为是参与者
                            let isNotPoster = task.posterId == nil || String(task.posterId!) != userId
                            let isNotTaker = task.takerId == nil || String(task.takerId!) != userId
                            let isNotOriginator = task.originatingUserId == nil || String(task.originatingUserId!) != userId
                            if isNotPoster && isNotTaker && isNotOriginator {
                                return true  // 用户是参与者
                            }
                        }
                        // 如果都没有匹配，过滤掉
                        return false
                    }
                }
                
                // 根据筛选类型进一步过滤
                switch self.filterType {
                case .all:
                    // 全部：显示所有与用户相关的任务（已在上一步过滤）
                    break
                case .posted:
                    // 我发布的：显示poster_id匹配的任务，或者通过活动申请创建的任务（originating_user_id匹配）
                    if let userId = self.currentUserId {
                        filteredTasks = filteredTasks.filter { task in
                            // 检查是否是用户发布的任务
                            if let posterId = task.posterId, String(posterId) == userId {
                                return true
                            }
                            // 检查是否是用户申请活动创建的任务（包括多人任务中 poster_id 为 None 的情况）
                            if let originatingUserId = task.originatingUserId, String(originatingUserId) == userId {
                                return true
                            }
                            return false
                        }
                    }
                case .accepted:
                    // 我接受的：只显示taker_id匹配的任务
                    if let userId = self.currentUserId {
                        filteredTasks = filteredTasks.filter { task in
                            if let takerId = task.takerId {
                                return String(takerId) == userId
                            }
                            return false
                        }
                    }
                }
                
                // 合并数据而不是覆盖，保留其他状态的任务
                // 这样可以避免在特定标签页刷新时丢失其他状态的任务
                // 策略：只更新/添加API返回的任务，不主动移除现有任务
                // 这样可以避免API返回不完整数据时丢失任务
                var mergedTasks = self.tasks
                
                // 更新或添加新加载的任务
                for newTask in filteredTasks {
                    if let existingIndex = mergedTasks.firstIndex(where: { $0.id == newTask.id }) {
                        // 如果任务已存在，更新它（新数据可能更完整）
                        mergedTasks[existingIndex] = newTask
                    } else {
                        // 如果任务不存在，添加它
                        mergedTasks.append(newTask)
                    }
                }
                
                // 注意：我们不主动移除现有任务，因为：
                // 1. API可能只返回部分数据（分页、筛选等）
                // 2. 移除任务可能导致数据丢失
                // 3. 如果任务状态真的改变了，会在下次"全部"标签页刷新时更新
                
                // 按创建时间倒序排序
                mergedTasks.sort { $0.createdAt > $1.createdAt }
                
                self.tasks = mergedTasks
                self.lastUpdateTime = Date()
                
                // 清除缓存，触发重新计算
                self.cachedStats = nil
                self.cachedFilteredTasks = nil
                
                // 保存到缓存
                self.saveTasksToCache()
            })
        
        mainRequest.store(in: &cancellables)
        
        // 并行加载申请记录（失败不影响任务列表显示）
        loadApplications()
    }
    
    // 从缓存加载任务（公开方法，供 View 调用，优先内存缓存，快速响应）
    func loadTasksFromCache() {
        // 先快速检查内存缓存（同步，很快）
        if let cachedTasks: [Task] = cacheManager.load([Task].self, forKey: cacheKey) {
            if !cachedTasks.isEmpty {
                self.tasks = cachedTasks
                self.cachedStats = nil
                self.cachedFilteredTasks = nil
                cacheHits += 1
                Logger.debug("✅ 缓存命中：从内存缓存加载了 \(cachedTasks.count) 条任务", category: .cache)
            } else {
                cacheMisses += 1
            }
        } else {
            cacheMisses += 1
        }
        
        // 加载申请记录缓存
        if let cachedApplications: [UserTaskApplication] = cacheManager.load([UserTaskApplication].self, forKey: applicationsCacheKey) {
            if !cachedApplications.isEmpty {
                self.applications = cachedApplications
                Logger.debug("从缓存加载了 \(cachedApplications.count) 条申请记录", category: .cache)
            }
        }
    }
    
    // 获取缓存统计信息
    var cacheStats: (hits: Int, misses: Int, hitRate: Double) {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        return (cacheHits, cacheMisses, hitRate)
    }
    
    // 保存任务到缓存
    private func saveTasksToCache() {
        // 只缓存最近的任务，避免内存占用过大（最多缓存200条）
        let tasksToCache = Array(tasks.prefix(200))
        if !tasksToCache.isEmpty {
            do {
                try cacheManager.setDiskCache(tasksToCache, forKey: cacheKey, expiration: 300) // 5分钟过期
                Logger.debug("已缓存 \(tasksToCache.count) 条任务", category: .cache)
            } catch {
                Logger.error("缓存保存失败: \(error.localizedDescription)", category: .cache)
            }
        }
        
        if !applications.isEmpty {
            do {
                try cacheManager.setDiskCache(applications, forKey: applicationsCacheKey, expiration: 300) // 5分钟过期
                Logger.debug("已缓存 \(applications.count) 条申请记录", category: .cache)
            } catch {
                Logger.error("申请记录缓存保存失败: \(error.localizedDescription)", category: .cache)
            }
        }
    }
    
    // 清除缓存（当任务状态在其他地方更新时调用）
    func clearCache() {
        cacheManager.clearCache(forKey: cacheKey)
        cacheManager.clearCache(forKey: applicationsCacheKey)
        Logger.debug("已清除我的任务缓存", category: .cache)
    }
    
    // 更新单个任务（当任务状态在其他页面更新时调用）
    func updateTask(_ updatedTask: Task) {
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks[index] = updatedTask
            cachedStats = nil
            cachedFilteredTasks = nil
            lastUpdateTime = Date()
            // 更新缓存
            saveTasksToCache()
            Logger.debug("已更新任务 #\(updatedTask.id) 的状态为 \(updatedTask.status.rawValue)", category: .cache)
        } else {
            // 如果任务不在列表中，可能是新任务，尝试添加到列表
            // 检查是否与当前用户相关
            if let userId = currentUserId {
                let isUserRelated = (updatedTask.posterId != nil && String(updatedTask.posterId!) == userId) ||
                                   (updatedTask.takerId != nil && String(updatedTask.takerId!) == userId)
                if isUserRelated {
                    tasks.append(updatedTask)
                    tasks.sort { $0.createdAt > $1.createdAt }
                    cachedStats = nil
                    cachedFilteredTasks = nil
                    saveTasksToCache()
                    Logger.debug("已添加新任务 #\(updatedTask.id) 到列表", category: .cache)
                }
            }
        }
    }
    
    // 并行加载所有状态的任务（用于"全部"标签页）
    private func loadAllTasksInParallel(forceRefresh: Bool = false) {
        guard let userId = currentUserId else {
            isLoading = false
            return
        }
        
        let group = DispatchGroup()
        var allTasks: [Task] = []
        var completedTasks: [Task] = []
        var hasError = false
        let lock = NSLock() // 保护共享数据
        
        // 1. 加载非已完成的任务（从 /api/users/my-tasks）
        group.enter()
        var endpoint = "/api/users/my-tasks?limit=100"
        switch filterType {
        case .posted:
            endpoint += "&role=poster"
        case .accepted:
            endpoint += "&role=taker"
        case .all:
            break
        }
        
        apiService.request([Task].self, endpoint, method: "GET")
            .sink(receiveCompletion: { completion in
                defer { group.leave() }
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载我的任务")
                    hasError = true
                }
            }, receiveValue: { tasks in
                lock.lock()
                // 过滤与用户相关的任务，并排除已完成的任务（已完成的任务会从另一个API加载）
                let userTasks = tasks.filter { task in
                    // 先检查是否与用户相关
                    let isPoster = task.posterId != nil && String(task.posterId!) == userId
                    let isTaker = task.takerId != nil && String(task.takerId!) == userId
                    let isOriginator = task.originatingUserId != nil && String(task.originatingUserId!) == userId
                    let isParticipant = task.isMultiParticipant == true && !isPoster && !isTaker && !isOriginator
                    // 对于多人任务，如果任务的 posterId、takerId 和 originatingUserId 都不匹配用户ID，
                    // 但任务已经在 API 响应中，说明用户是参与者（后端已经通过 TaskParticipant join 返回）
                    let isUserRelated = isPoster || isTaker || isOriginator || isParticipant
                    // 排除已完成的任务（已完成的任务会从另一个API加载）
                    // 注意：对于多人任务，用户可能是参与者，后端已经通过 TaskParticipant join 返回了这些任务
                    return isUserRelated && task.status != .completed
                }
                allTasks.append(contentsOf: userTasks)
                lock.unlock()
            })
            .store(in: &cancellables)
        
        // 2. 并行加载已完成的任务
        group.enter()
        loadCompletedTasksForAllTab { tasks in
            lock.lock()
            completedTasks = tasks
            lock.unlock()
            group.leave()
        }
        
        // 3. 等待所有请求完成，然后一次性合并显示
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            
            // 合并所有任务，去重
            var mergedTasks: [Task] = []
            var seenTaskIds = Set<Int>()
            
            // 先添加非已完成的任务
            for task in allTasks {
                if !seenTaskIds.contains(task.id) {
                    mergedTasks.append(task)
                    seenTaskIds.insert(task.id)
                }
            }
            
            // 再添加已完成的任务
            for task in completedTasks {
                if !seenTaskIds.contains(task.id) {
                    mergedTasks.append(task)
                    seenTaskIds.insert(task.id)
                } else {
                    // 如果任务已存在，更新它（已完成的任务信息可能更完整）
                    if let index = mergedTasks.firstIndex(where: { $0.id == task.id }) {
                        mergedTasks[index] = task
                    }
                }
            }
            
            // 按创建时间倒序排序
            mergedTasks.sort { $0.createdAt > $1.createdAt }
            
            // 一次性设置所有任务，避免分步显示
            self.tasks = mergedTasks
            self.cachedStats = nil
            self.cachedFilteredTasks = nil
            self.lastUpdateTime = Date()
            
            // 保存到缓存
            self.saveTasksToCache()
            
            if hasError && mergedTasks.isEmpty {
                self.errorMessage = "加载任务失败，请稍后重试"
            }
        }
    }
    
    // 加载已完成的任务（用于"全部"标签页）
    private func loadCompletedTasksForAllTab(completion: @escaping ([Task]) -> Void) {
        guard let userId = currentUserId else {
            completion([])
            return
        }
        
        let endpoint = "/api/messages/tasks?limit=100&offset=0"
        
        apiService.request(TaskChatListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("加载已完成任务失败: \(error.localizedDescription)", category: .api)
                    completion([])
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else {
                    completion([])
                    return
                }
                
                // 筛选已完成的任务
                let completedTaskChats = response.taskChats.filter { taskChat in
                    if let status = taskChat.taskStatus ?? taskChat.status {
                        return status.lowercased() == "completed"
                    }
                    return false
                }
                
                // 筛选与用户相关的任务
                // 注意：对于多人任务，用户可能是参与者，需要通过其他方式识别
                let userRelatedTasks = completedTaskChats.filter { taskChat in
                    if let posterId = taskChat.posterId, String(posterId) == userId {
                        return true
                    }
                    if let takerId = taskChat.takerId, String(takerId) == userId {
                        return true
                    }
                    // 对于多人任务，如果任务已经在响应中，说明用户是参与者（后端已经通过 TaskParticipant join 返回）
                    // 这里我们信任后端返回的数据，因为后端已经过滤了
                    if taskChat.isMultiParticipant == true {
                        return true
                    }
                    return false
                }
                
                let completedTaskIds = Array(Set(userRelatedTasks.map { $0.id }))
                
                if completedTaskIds.isEmpty {
                    completion([])
                    return
                }
                
                // 加载任务详情
                self.loadTaskDetailsForIds(completedTaskIds) { loadedTasks in
                    completion(loadedTasks)
                }
            })
            .store(in: &cancellables)
    }
    
    // 加载申请记录
    private func loadApplications() {
        apiService.request([UserTaskApplication].self, "/api/my-applications", method: "GET")
            .sink(receiveCompletion: { _ in
                // 静默处理错误，不影响主任务列表
            }, receiveValue: { [weak self] applications in
                guard let self = self else { return }
                self.applications = applications
                // 保存申请记录到缓存
                self.saveTasksToCache()
            })
            .store(in: &cancellables)
    }
    
    // 加载已完成的任务（公开方法，供View调用）
    // 使用 /api/messages/tasks API 来获取已完成的任务，因为这个API会返回所有状态的任务
    func loadCompletedTasks() {
        loadCompletedTasksIfNeeded()
    }
    
    // 加载已完成的任务（如果需要）
    // 使用 /api/messages/tasks API 来获取已完成的任务，因为这个API会返回所有状态的任务
    private func loadCompletedTasksIfNeeded() {
        guard let userId = currentUserId else { return }
        
        // 使用消息页面的API来获取已完成的任务
        let endpoint = "/api/messages/tasks?limit=100&offset=0"
        
        apiService.request(TaskChatListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isLoadingCompletedTasks = false
                }
                if case .failure(let error) = completion {
                    Logger.error("加载已完成任务失败: \(error.localizedDescription)", category: .api)
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                // 从 TaskChatItem 中筛选已完成的任务
                let completedTaskChats = response.taskChats.filter { taskChat in
                    // 检查任务状态是否为 completed
                    if let status = taskChat.taskStatus ?? taskChat.status {
                        return status.lowercased() == "completed"
                    }
                    return false
                }
                
                // 检查是否是当前用户相关的任务
                let userRelatedCompletedTasks = completedTaskChats.filter { taskChat in
                    if let posterId = taskChat.posterId, String(posterId) == userId {
                        return true
                    }
                    if let takerId = taskChat.takerId, String(takerId) == userId {
                        return true
                    }
                    return false
                }
                
                // 获取已完成任务的ID列表
                let completedTaskIds = Set(userRelatedCompletedTasks.map { $0.id })
                
                // 检查现有任务列表中是否已有这些任务
                let existingTaskIds = Set(self.tasks.map { $0.id })
                let missingTaskIds = completedTaskIds.subtracting(existingTaskIds)
                
                if !missingTaskIds.isEmpty {
                    // 为每个缺失的任务ID请求完整的任务详情
                    self.loadTaskDetailsForIds(Array(missingTaskIds))
                } else {
                    // 如果没有缺失的任务，直接设置加载完成
                    DispatchQueue.main.async {
                        self.isLoadingCompletedTasks = false
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    // 根据任务ID列表加载任务详情（优化版：批量加载，减少并发请求）
    private func loadTaskDetailsForIds(_ taskIds: [Int], completion: (([Task]) -> Void)? = nil) {
        guard !taskIds.isEmpty else {
            completion?([])
            return
        }
        
        // 限制并发数量，避免同时发起过多请求（最多5个并发）
        let batchSize = 5
        let batches = taskIds.chunked(into: batchSize)
        var allLoadedTasks: [Task] = []
        var completedBatches = 0
        let totalBatches = batches.count
        let lock = NSLock()
        let group = DispatchGroup()
        
        for batch in batches {
            group.enter()
            var batchTasks: [Task] = []
            var batchCompleted = 0
            let batchCount = batch.count
            
            for taskId in batch {
                apiService.request(Task.self, "/api/tasks/\(taskId)", method: "GET")
                    .sink(receiveCompletion: { result in
                        lock.lock()
                        batchCompleted += 1
                        let isBatchComplete = batchCompleted == batchCount
                        lock.unlock()
                        
                        if isBatchComplete {
                            lock.lock()
                            allLoadedTasks.append(contentsOf: batchTasks)
                            completedBatches += 1
                            let allComplete = completedBatches == totalBatches
                            lock.unlock()
                            
                            group.leave()
                            
                            // 当所有批次完成时
                            if allComplete {
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    
                                    if let completion = completion {
                                        // 如果有回调，直接返回结果
                                        completion(allLoadedTasks)
                                    } else {
                                        // 否则合并到现有任务列表中
                                        guard !allLoadedTasks.isEmpty else { return }
                                        
                                        let existingTaskIds = Set(self.tasks.map { $0.id })
                                        let newTasks = allLoadedTasks.filter { !existingTaskIds.contains($0.id) }
                                        
                                        if !newTasks.isEmpty {
                                            self.tasks.append(contentsOf: newTasks)
                                            // 清除缓存，触发重新计算
                                            self.cachedStats = nil
                                            self.cachedFilteredTasks = nil
                                            self.isLoadingCompletedTasks = false
                                            // 更新缓存
                                            self.saveTasksToCache()
                                            Logger.debug("已加载 \(newTasks.count) 个已完成的任务详情", category: .api)
                                        }
                                    }
                                }
                            }
                        }
                    }, receiveValue: { task in
                        lock.lock()
                        batchTasks.append(task)
                        lock.unlock()
                    })
                    .store(in: &cancellables)
            }
        }
    }
}

