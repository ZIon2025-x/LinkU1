import Foundation
import Combine
import CoreLocation

class TaskExpertViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var experts: [TaskExpert] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    private var rawExperts: [TaskExpert] = [] // 保存原始数据，用于重新排序
    
    init(apiService: APIService? = nil, locationService: LocationService? = nil) {
        self.apiService = apiService ?? APIService.shared
        self.locationService = locationService ?? LocationService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadExperts(category: String? = nil, location: String? = nil, keyword: String? = nil, forceRefresh: Bool = false) {
        let startTime = Date()
        
        // 防止重复请求：如果正在加载且不是强制刷新，则跳过
        guard !isLoading || forceRefresh else {
            Logger.warning("请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 强制刷新时清除缓存
        if forceRefresh && category == nil && location == nil && keyword == nil {
            CacheManager.shared.invalidateTaskExpertsCache()
        }
        
        // 尝试从缓存加载数据（仅在没有筛选条件时，且非强制刷新）
        if !forceRefresh && category == nil && location == nil && keyword == nil {
            if let cachedExperts = CacheManager.shared.loadTaskExperts(category: nil, location: nil) {
                self.experts = cachedExperts
                Logger.success("从缓存加载了 \(self.experts.count) 个任务达人", category: .cache)
                isLoading = false
                // 继续在后台刷新数据
            }
        }
        
        // 构建URL参数
        var queryParams: [String] = [
            "status=active",
            "limit=50"
        ]
        if let category = category, !category.isEmpty {
            let encodedCategory = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
            queryParams.append("category=\(encodedCategory)")
        }
        if let location = location, !location.isEmpty {
            let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
            queryParams.append("location=\(encodedLocation)")
        }
        if let keyword = keyword, !keyword.isEmpty {
            let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
            queryParams.append("keyword=\(encodedKeyword)")
        }
        
        let endpoint = "/api/task-experts?\(queryParams.joined(separator: "&"))"
        
        // 后端返回格式：{"task_experts": [...]} 或直接数组 [...]
        struct TaskExpertListResponse: Decodable {
            let taskExperts: [TaskExpert]?
            let experts: [TaskExpert]?
            let items: [TaskExpert]?
            
            // 支持多种格式：包装对象 {task_experts: [...]}, {experts: [...]}, {items: [...]} 或直接数组 [...]
            init(from decoder: Decoder) throws {
                if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                    // 尝试不同的键名
                    if container.contains(.taskExperts) {
                        taskExperts = try container.decode([TaskExpert].self, forKey: .taskExperts)
                    } else {
                        taskExperts = nil
                    }
                    if container.contains(.experts) {
                        experts = try container.decode([TaskExpert].self, forKey: .experts)
                    } else {
                        experts = nil
                    }
                    if container.contains(.items) {
                        items = try container.decode([TaskExpert].self, forKey: .items)
                    } else {
                        items = nil
                    }
                } else {
                    // 如果所有键都不存在，尝试直接数组格式
                    let container = try decoder.singleValueContainer()
                    let directArray = try container.decode([TaskExpert].self)
                    taskExperts = directArray
                    experts = nil
                    items = nil
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case taskExperts = "task_experts"
                case experts
                case items
            }
            
            var allExperts: [TaskExpert] {
                return taskExperts ?? experts ?? items ?? []
            }
        }
        
        apiService.request(TaskExpertListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务达人")
                    // error 已经是 APIError 类型，无需转换
                    self?.errorMessage = error.userFriendlyMessage
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    Logger.error("任务达人加载失败: \(error)", category: .api)
                    Logger.debug("请求URL: \(endpoint)", category: .api)
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
                
                // 保存原始数据
                self.rawExperts = response.allExperts
                Logger.debug("收到 \(response.allExperts.count) 个任务达人数据", category: .api)
                
                // 如果搜索没有结果，立即清空列表并返回
                if response.allExperts.isEmpty {
                    DispatchQueue.main.async {
                        self.experts = []
                        self.isLoading = false
                    }
                    Logger.debug("搜索无结果，已清空专家列表", category: .api)
                    Logger.success("任务达人加载成功，共0条", category: .api)
                    return
                }
                
                // 检查位置服务状态
                Logger.debug("位置服务状态检查:", category: .general)
                Logger.debug("  - 授权状态: \(self.locationService.authorizationStatus.rawValue)", category: .general)
                Logger.debug("  - 当前位置: \(self.locationService.currentLocation != nil ? "已获取" : "未获取")", category: .general)
                if let location = self.locationService.currentLocation {
                    Logger.debug("  - 位置坐标: \(location.latitude), \(location.longitude)", category: .general)
                    Logger.debug("  - 城市名称: \(location.cityName ?? "未知")", category: .general)
                }
                
                // 立即尝试排序（如果位置已可用）
                self.sortExpertsByDistance()
                
                // 如果位置还没获取到，先显示原始数据，等位置获取后再排序
                if self.locationService.currentLocation == nil {
                    Logger.debug("位置尚未获取，先显示原始顺序，位置获取后将自动重新排序", category: .general)
                    Logger.debug("正在请求位置...", category: .general)
                    // 主动请求一次位置
                    if self.locationService.isAuthorized {
                        self.locationService.requestLocation()
                    } else {
                        self.locationService.requestAuthorization()
                    }
                    DispatchQueue.main.async {
                        self.experts = self.rawExperts
                    }
                }
                
                Logger.success("任务达人加载成功，共\(self.experts.count)条", category: .api)
                // 保存到缓存（仅在没有筛选条件时）
                if category == nil && location == nil {
                    CacheManager.shared.saveTaskExperts(self.experts, category: nil, location: nil)
                    Logger.success("已缓存 \(self.experts.count) 个任务达人", category: .cache)
                }
                
                // 监听位置更新，当位置可用时重新排序
                // 使用 debounce 避免位置频繁更新导致重复排序
                self.locationService.$currentLocation
                    .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
                    .sink { [weak self] newLocation in
                        if newLocation != nil {
                            self?.sortExpertsByDistance()
                        }
                    }
                    .store(in: &self.cancellables)
            })
            .store(in: &cancellables)
    }
    
    /// 按距离排序达人（基于城市距离）
    private func sortExpertsByDistance() {
        guard !rawExperts.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.experts = []
            }
            return
        }
        
        var experts = rawExperts
        
        // 计算距离并排序（如果用户位置可用）
        if let userLocation = locationService.currentLocation {
            let userCoordinate = CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            )
            
            experts = experts.map { expert in
                var expert = expert
                expert.distance = DistanceCalculator.distanceToCity(
                    from: userCoordinate,
                    to: expert.location
                )
                return expert
            }
            
            // 按距离排序（由近到远）
            // Online 服务距离为0，会排在前面
            // 没有距离信息的排在最后
            experts.sort { expert1, expert2 in
                let distance1 = expert1.distance ?? Double.infinity
                let distance2 = expert2.distance ?? Double.infinity
                
                // 如果距离相同，保持原有顺序
                if abs(distance1 - distance2) < 0.01 {
                    return false
                }
                
                return distance1 < distance2
            }
            
        } else {
        }
        
        // 更新到主线程
        DispatchQueue.main.async { [weak self] in
            self?.experts = experts
        }
    }
}

class TaskExpertDetailViewModel: ObservableObject {
    @Published var expert: TaskExpert?
    @Published var services: [TaskExpertService] = []
    @Published var reviews: [PublicReview] = []
    @Published var reviewsTotal: Int = 0
    @Published var hasMoreReviews = false
    @Published var isLoading = false
    @Published var isLoadingReviews = false
    @Published var isLoadingMoreReviews = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private let reviewsPageSize = 20
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadExpert(expertId: String) {
        isLoading = true
        apiService.request(TaskExpert.self, "/api/task-experts/\(expertId)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务达人详情")
                    // error 已经是 APIError 类型，无需转换
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] expert in
                self?.expert = expert
            })
            .store(in: &cancellables)
    }
    
    func loadReviews(expertId: String, limit: Int = 20, offset: Int = 0) {
        if offset == 0 {
            isLoadingReviews = true
        } else {
            isLoadingMoreReviews = true
        }
        
        struct ReviewsResponse: Decodable {
            let total: Int
            let items: [PublicReview]
            let limit: Int
            let offset: Int
            let hasMore: Bool
            
            enum CodingKeys: String, CodingKey {
                case total, items, limit, offset
                case hasMore = "has_more"
            }
        }
        
        apiService.request(ReviewsResponse.self, "/api/task-experts/\(expertId)/reviews?limit=\(limit)&offset=\(offset)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                if offset == 0 {
                    self?.isLoadingReviews = false
                } else {
                    self?.isLoadingMoreReviews = false
                }
                if case .failure(let error) = completion {
                    // 评价加载失败不影响页面显示，只记录错误
                    Logger.error("加载达人评价失败: \(error)", category: .api)
                }
            }, receiveValue: { [weak self] response in
                if offset == 0 {
                    self?.reviews = response.items
                } else {
                    self?.reviews.append(contentsOf: response.items)
                }
                self?.reviewsTotal = response.total
                self?.hasMoreReviews = response.hasMore
            })
            .store(in: &cancellables)
    }
    
    func loadMoreReviews(expertId: String) {
        guard !isLoadingMoreReviews && hasMoreReviews else { return }
        loadReviews(expertId: expertId, limit: reviewsPageSize, offset: reviews.count)
    }
    
    func loadServices(expertId: String) {
        // 后端返回格式：{"expert_id":"...", "expert_name":"...", "services":[...]}
        struct ExpertServicesResponse: Decodable {
            let services: [TaskExpertService]
            
            // 支持两种格式：包装对象 {services: [...]} 或直接数组 [...]
            init(from decoder: Decoder) throws {
                if let container = try? decoder.container(keyedBy: CodingKeys.self) {
                    services = try container.decode([TaskExpertService].self, forKey: .services)
                } else {
                    let container = try decoder.singleValueContainer()
                    services = try container.decode([TaskExpertService].self)
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case services
            }
        }
        
        apiService.request(ExpertServicesResponse.self, "/api/task-experts/\(expertId)/services", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载服务列表")
                    // error 已经是 APIError 类型，无需转换
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] response in
                self?.services = response.services.filter { $0.status == "active" }
            })
            .store(in: &cancellables)
    }
}

class ServiceDetailViewModel: ObservableObject {
    @Published var service: TaskExpertService?
    @Published var timeSlots: [ServiceTimeSlot] = []
    @Published var reviews: [PublicReview] = []
    @Published var reviewsTotal: Int = 0
    @Published var hasMoreReviews = false
    @Published var isLoading = false
    @Published var isLoadingReviews = false
    @Published var isLoadingMoreReviews = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private let reviewsPageSize = 20
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadService(serviceId: Int) {
        isLoading = true
        apiService.request(TaskExpertService.self, "/api/task-experts/services/\(serviceId)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载服务详情")
                    // error 已经是 APIError 类型，无需转换
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] service in
                self?.service = service
            })
            .store(in: &cancellables)
    }
    
    func loadReviews(serviceId: Int, limit: Int = 20, offset: Int = 0) {
        if offset == 0 {
            isLoadingReviews = true
        } else {
            isLoadingMoreReviews = true
        }
        
        struct ReviewsResponse: Decodable {
            let total: Int
            let items: [PublicReview]
            let limit: Int
            let offset: Int
            let hasMore: Bool
            
            enum CodingKeys: String, CodingKey {
                case total, items, limit, offset
                case hasMore = "has_more"
            }
        }
        
        apiService.request(ReviewsResponse.self, "/api/task-experts/services/\(serviceId)/reviews?limit=\(limit)&offset=\(offset)", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                if offset == 0 {
                    self?.isLoadingReviews = false
                } else {
                    self?.isLoadingMoreReviews = false
                }
                if case .failure(let error) = completion {
                    // 评价加载失败不影响页面显示，只记录错误
                    Logger.error("加载服务评价失败: \(error)", category: .api)
                }
            }, receiveValue: { [weak self] response in
                if offset == 0 {
                    self?.reviews = response.items
                } else {
                    self?.reviews.append(contentsOf: response.items)
                }
                self?.reviewsTotal = response.total
                self?.hasMoreReviews = response.hasMore
            })
            .store(in: &cancellables)
    }
    
    func loadMoreReviews(serviceId: Int) {
        guard !isLoadingMoreReviews && hasMoreReviews else { return }
        loadReviews(serviceId: serviceId, limit: reviewsPageSize, offset: reviews.count)
    }
    
    func loadTimeSlots(serviceId: Int) {
        apiService.request([ServiceTimeSlot].self, "/api/task-experts/services/\(serviceId)/time-slots", method: "GET")
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] slots in
                self?.timeSlots = slots.filter { $0.isAvailable }
            })
            .store(in: &cancellables)
    }
    
    func applyService(serviceId: Int, message: String?, counterPrice: Double?, deadline: Date?, isFlexible: Int, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [:]
        if let message = message {
            body["application_message"] = message
        }
        if let counterPrice = counterPrice {
            body["negotiated_price"] = counterPrice
        }
        // 添加日期和灵活模式字段
        // 只有在非灵活模式时才发送 deadline
        if isFlexible == 0, let deadline = deadline {
            // 转换为 ISO 8601 格式（包含时间部分）
            // 将日期设置为当天的23:59:59 UTC，确保是有效的截止时间
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!
            let components = calendar.dateComponents([.year, .month, .day], from: deadline)
            if let dateWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: calendar.date(from: components) ?? deadline) {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                formatter.timeZone = TimeZone(identifier: "UTC")
                body["deadline"] = formatter.string(from: dateWithTime)
            } else {
                // 如果转换失败，使用原始日期
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                formatter.timeZone = TimeZone(identifier: "UTC")
                body["deadline"] = formatter.string(from: deadline)
            }
        }
        body["is_flexible"] = isFlexible
        
        // 注意：申请服务时用户是客户/付款方，不需要收款账户
        apiService.request(ServiceApplication.self, "/api/task-experts/services/\(serviceId)/apply", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "申请服务")
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
}

class MyServiceApplicationsViewModel: ObservableObject {
    @Published var applications: [ServiceApplication] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadApplications() {
        isLoading = true
        // 使用正确的端点：/api/task-experts/me/applications (任务达人获取收到的申请)
        // 或 /api/users/me/service-applications (普通用户获取自己申请的达人服务)
        // 根据上下文，这里应该是普通用户获取自己申请的达人服务
        apiService.request(ServiceApplicationListResponse.self, "/api/users/me/service-applications", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载服务申请")
                    // error 已经是 APIError 类型，无需转换
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] response in
                self?.applications = response.items
            })
            .store(in: &cancellables)
    }
}

class TaskExpertApplicationViewModel: ObservableObject {
    @Published var application: TaskExpertApplication?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadMyApplication() {
        isLoading = true
        apiService.request(TaskExpertApplication.self, "/api/task-experts/my-application", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 404 表示没有申请，这是正常的
                    if case APIError.httpError(404) = error {
                        self?.application = nil
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] application in
                self?.application = application
            })
            .store(in: &cancellables)
    }
    
    func apply(message: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        let body = ["application_message": message]
        apiService.request(TaskExpertApplication.self, "/api/task-experts/apply", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] application in
                self?.application = application
                completion(true)
            })
            .store(in: &cancellables)
    }
}

