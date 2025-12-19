import Foundation
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedActivity: Activity?
    @Published var timeSlots: [ServiceTimeSlot] = []
    @Published var isLoadingTimeSlots = false
    
    private var cancellables = Set<AnyCancellable>()
    // 使用依赖注入获取服务
    private let apiService: APIService
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    // MARK: - Load Activities
    
    func loadActivities(expertId: String? = nil, status: String? = nil, includeEnded: Bool = false, forceRefresh: Bool = false) {
        isLoading = true
        errorMessage = nil
        
        // 强制刷新时清除缓存
        if forceRefresh && expertId == nil && status == nil && !includeEnded {
            CacheManager.shared.invalidateActivitiesCache()
        }
        
        // 尝试从缓存加载数据（仅在没有筛选条件时，且非强制刷新）
        if !forceRefresh && expertId == nil && status == nil && !includeEnded {
            if let cachedActivities = CacheManager.shared.loadActivities() {
                self.activities = cachedActivities
                print("✅ 从缓存加载了 \(self.activities.count) 个活动")
                isLoading = false
                // 继续在后台刷新数据
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
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            // 使用 ErrorHandler 统一处理错误
                            ErrorHandler.shared.handle(error, context: "加载活动列表")
                            if let apiError = error as? APIError {
                                self?.errorMessage = apiError.userFriendlyMessage
                            } else {
                                self?.errorMessage = error.localizedDescription
                            }
                        }
                    },
                    receiveValue: { [weak self] activities in
                        self?.activities = activities
                        self?.isLoading = false
                        // 保存到缓存（仅在没有筛选条件时）
                        if expertId == nil && status == nil && !includeEnded {
                            CacheManager.shared.saveActivities(activities)
                            print("✅ 已缓存 \(activities.count) 个活动")
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
                        self?.isLoading = false
                        if case .failure(let error) = completion {
                            // 使用 ErrorHandler 统一处理错误
                            ErrorHandler.shared.handle(error, context: "加载活动列表")
                            if let apiError = error as? APIError {
                                self?.errorMessage = apiError.userFriendlyMessage
                            } else {
                                self?.errorMessage = error.localizedDescription
                            }
                        }
                    },
                    receiveValue: { [weak self] activities in
                        self?.activities = activities
                        self?.isLoading = false
                        // 保存到缓存（仅在没有筛选条件时）
                        if expertId == nil && status == nil && !includeEnded {
                            CacheManager.shared.saveActivities(activities)
                            print("✅ 已缓存 \(activities.count) 个活动")
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
        
        apiService.getActivityDetail(activityId: activityId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        // 使用 ErrorHandler 统一处理错误
                        ErrorHandler.shared.handle(error, context: "加载活动详情")
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                    }
                },
                receiveValue: { [weak self] activity in
                    self?.selectedActivity = activity
                    self?.isLoading = false
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
                        print("加载时间段失败: \(error.localizedDescription)")
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

