import Foundation
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedActivity: Activity?
    @Published var timeSlots: [ServiceTimeSlot] = []
    @Published var isLoadingTimeSlots = false
    @Published var expert: TaskExpert? // 活动发布者的达人信息
    
    private var cancellables = Set<AnyCancellable>()
    // 使用依赖注入获取服务
    private let apiService: APIService
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Load Activities
    
    func loadActivities(expertId: String? = nil, status: String? = nil, includeEnded: Bool = false, forceRefresh: Bool = false) {
        let startTime = Date()
        let endpoint = "/api/activities"
        
        // 防止重复请求：如果正在加载且不是强制刷新，则跳过
        guard !isLoading || forceRefresh else {
            Logger.warning("请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        // 优化：将数据处理移到后台线程，避免阻塞主线程
        isLoading = true
        errorMessage = nil
        
        // 强制刷新时清除缓存
        if forceRefresh && expertId == nil && status == nil && !includeEnded {
            CacheManager.shared.invalidateActivitiesCache()
        }
        
        // 尝试从缓存加载数据（仅在没有 expertId 筛选时，且非强制刷新）
        if !forceRefresh && expertId == nil {
            if let cachedActivities = CacheManager.shared.loadActivities() {
                // 根据 status 和 includeEnded 过滤缓存数据
                var filteredActivities = cachedActivities
                if let status = status {
                    filteredActivities = filteredActivities.filter { $0.status == status }
                } else if !includeEnded {
                    // 如果没有指定 status 且不包含已结束的，只显示开放中的
                    filteredActivities = filteredActivities.filter { $0.status == "open" }
                }
                
                if !filteredActivities.isEmpty {
                    self.activities = filteredActivities
                    Logger.success("从缓存加载了 \(self.activities.count) 个活动（过滤后）", category: .cache)
                    isLoading = false
                    // 继续在后台刷新数据
                }
            }
        }
        
        // 如果需要包含已结束的活动（全部选项），需要同时获取进行中和已结束的活动
        if includeEnded && status == nil {
            // 获取进行中的活动
            let activePublisher = apiService.getActivities(expertId: expertId, status: "open", limit: 50, offset: 0)
            
            // 获取已结束的活动
            let completedPublisher = apiService.getActivities(expertId: expertId, status: "completed", limit: 50, offset: 0)
            
            // 合并两个请求的结果
            Publishers.Zip(activePublisher, completedPublisher)
                .map { activeActivities, completedActivities in
                    // 合并并去重（按 id）
                    var allActivities = activeActivities + completedActivities
                    // 去重（保持顺序：先出现的保留）
                    var seenIds = Set<Int>()
                    allActivities = allActivities.filter { activity in
                        if seenIds.contains(activity.id) {
                            return false
                        }
                        seenIds.insert(activity.id)
                        return true
                    }
                    // 后端已经按创建时间降序排序，这里按 id 降序排序（id 越大越新）
                    return allActivities.sorted { $0.id > $1.id }
                }
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        let duration = Date().timeIntervalSince(startTime)
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            // 使用 ErrorHandler 统一处理错误
                            ErrorHandler.shared.handle(error, context: "加载活动列表")
                            // 记录性能指标
                            self?.performanceMonitor.recordNetworkRequest(
                                endpoint: endpoint,
                                method: "GET",
                                duration: duration,
                                error: error
                            )
                            // 错误处理：error 已经是 APIError 类型，直接使用
                            self?.errorMessage = error.userFriendlyMessage
                        } else {
                            // 记录成功请求的性能指标
                            self?.performanceMonitor.recordNetworkRequest(
                                endpoint: endpoint,
                                method: "GET",
                                duration: duration,
                                statusCode: 200
                            )
                        }
                    },
                    receiveValue: { [weak self] activities in
                        guard let self = self else { return }
                        // 优化：将数据处理移到后台线程
                        DispatchQueue.global(qos: .userInitiated).async {
                            // 保存到缓存（仅在没有筛选条件时）
                            if expertId == nil && status == nil && !includeEnded {
                                CacheManager.shared.saveActivities(activities)
                                Logger.success("已缓存 \(activities.count) 个活动", category: .cache)
                            }
                            
                            // 回到主线程更新UI
                            DispatchQueue.main.async {
                                self.activities = activities
                                self.isLoading = false
                            }
                        }
                    }
                )
                .store(in: &cancellables)
        } else {
            // 单个请求
            apiService.getActivities(expertId: expertId, status: status, limit: 50, offset: 0)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        let duration = Date().timeIntervalSince(startTime)
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            // 使用 ErrorHandler 统一处理错误
                            ErrorHandler.shared.handle(error, context: "加载活动列表")
                            // 记录性能指标
                            self?.performanceMonitor.recordNetworkRequest(
                                endpoint: endpoint,
                                method: "GET",
                                duration: duration,
                                error: error
                            )
                            // 错误处理：error 已经是 APIError 类型，直接使用
                            self?.errorMessage = error.userFriendlyMessage
                        } else {
                            // 记录成功请求的性能指标
                            self?.performanceMonitor.recordNetworkRequest(
                                endpoint: endpoint,
                                method: "GET",
                                duration: duration,
                                statusCode: 200
                            )
                        }
                    },
                    receiveValue: { [weak self] activities in
                        guard let self = self else { return }
                        // 优化：将数据处理移到后台线程
                        DispatchQueue.global(qos: .userInitiated).async {
                            // 保存到缓存（仅在没有筛选条件时）
                            if expertId == nil && status == nil && !includeEnded {
                                CacheManager.shared.saveActivities(activities)
                                Logger.success("已缓存 \(activities.count) 个活动", category: .cache)
                            }
                            
                            // 回到主线程更新UI
                            DispatchQueue.main.async {
                                self.activities = activities
                                self.isLoading = false
                            }
                        }
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    // MARK: - Load Activity Detail
    
    func loadActivityDetail(activityId: Int) {
        isLoading = true
        errorMessage = nil
        expert = nil // 重置达人信息
        
        apiService.getActivityDetail(activityId: activityId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载活动详情")
                        // 错误处理：error 已经是 APIError 类型，直接使用
                        self?.errorMessage = error.userFriendlyMessage
                    }
                },
                receiveValue: { [weak self] activity in
                    self?.selectedActivity = activity
                    self?.isLoading = false
                    // 加载达人信息
                    self?.loadExpertInfo(expertId: activity.expertId)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Load Expert Info
    
    private func loadExpertInfo(expertId: String) {
        apiService.request(TaskExpert.self, "/api/task-experts/\(expertId)", method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.warning("加载达人信息失败: \(error.localizedDescription)", category: .api)
                    }
                },
                receiveValue: { [weak self] expert in
                    self?.expert = expert
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Load Time Slots
    
    func loadTimeSlots(serviceId: Int, activityId: Int) {
        isLoadingTimeSlots = true
        
        // 计算日期范围（未来60天）
        let today = Date()
        let futureDate = Calendar.current.date(byAdding: .day, value: 60, to: today) ?? today
        
        // 格式化日期为 UTC 时间发送给后端
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let startDate = formatter.string(from: today)
        let endDate = formatter.string(from: futureDate)
        
        let endpoint = "/api/task-experts/services/\(serviceId)/time-slots?start_date=\(startDate)&end_date=\(endDate)"
        
        apiService.request([ServiceTimeSlot].self, endpoint, method: "GET")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingTimeSlots = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载时间段")
                        Logger.error("加载时间段失败: \(error.localizedDescription)", category: .api)
                        self?.timeSlots = []
                    }
                },
                receiveValue: { [weak self] slots in
                    // 只显示与该活动关联的时间段
                    self?.timeSlots = slots.filter { slot in
                        slot.hasActivity == true && slot.activityId == activityId
                    }
                    self?.isLoadingTimeSlots = false
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Apply to Activity
    
    func applyToActivity(activityId: Int, timeSlotId: Int? = nil, preferredDeadline: String? = nil, isFlexibleTime: Bool = false) -> AnyPublisher<Bool, Error> {
        return apiService.applyToActivity(
            activityId: activityId,
            timeSlotId: timeSlotId,
            preferredDeadline: preferredDeadline,
            isFlexibleTime: isFlexibleTime
        )
        .map { _ in true }
        .mapError { $0 as Error }
        .eraseToAnyPublisher()
    }
}

