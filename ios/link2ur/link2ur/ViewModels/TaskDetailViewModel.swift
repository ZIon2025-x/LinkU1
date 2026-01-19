import Foundation
import Combine

class TaskDetailViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var task: Task?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var applications: [TaskApplication] = []
    @Published var isLoadingApplications = false
    @Published var userApplication: TaskApplication?
    @Published var reviews: [Review] = []
    @Published var isLoadingReviews = false
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadTask(taskId: Int, force: Bool = false) {
        // 防止重复请求（除非强制刷新）
        if !force && isLoading {
            Logger.debug("任务详情请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        let startTime = Date()
        let endpoint = "/api/tasks/\(taskId)"
        
        isLoading = true
        apiService.getTaskDetail(taskId: taskId)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务详情")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
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
            }, receiveValue: { [weak self] task in
                DispatchQueue.main.async {
                    // 如果任务状态变为已完成或取消，清理相关图片缓存
                    if task.status == .completed || task.status == .cancelled {
                        ImageCache.shared.clearTaskImages(task: task)
                    }
                    
                    self?.task = task
                    // 发送任务更新通知，让其他页面（如"我的任务"）也更新
                    NotificationCenter.default.post(name: .taskUpdated, object: task)
                    // 如果任务状态变为已完成，也发送状态更新通知
                    if task.status == .completed {
                        NotificationCenter.default.post(name: .taskStatusUpdated, object: task)
                    }
                }
            })
            .store(in: &cancellables)
    }
    
    func loadApplications(taskId: Int, currentUserId: String?) {
        let startTime = Date()
        let endpoint = "/api/tasks/\(taskId)/applications"
        
        isLoadingApplications = true
        apiService.getTaskApplications(taskId: taskId)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoadingApplications = false
                if case .failure(let error) = result {
                    // 403 错误表示用户没有权限查看申请列表（例如不是任务发布者），静默处理
                    if case .httpError(let statusCode) = error, statusCode == 403 {
                        Logger.debug("用户无权限查看申请列表（403），静默处理", category: .api)
                        DispatchQueue.main.async {
                            self?.applications = [] // 设置为空数组，不显示错误
                        }
                    } else {
                        // 其他错误才显示
                        ErrorHandler.shared.handle(error, context: "加载任务申请列表")
                        Logger.error("加载申请列表失败: \(error.localizedDescription)", category: .api)
                    }
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
                self?.applications = response.applications
                // 查找当前用户的申请
                if let userId = currentUserId {
                    self?.userApplication = response.applications.first { app in
                        String(app.applicantId) == userId
                    }
                }
                self?.isLoadingApplications = false
            })
            .store(in: &cancellables)
    }
    
    func loadReviews(taskId: Int) {
        isLoadingReviews = true
        apiService.getTaskReviews(taskId: taskId)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingReviews = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务评价")
                    Logger.error("加载评价失败: \(error.localizedDescription)", category: .api)
                }
            }, receiveValue: { [weak self] reviews in
                self?.reviews = reviews
                self?.isLoadingReviews = false
            })
            .store(in: &cancellables)
    }
    
    func applyTask(taskId: Int, message: String?, negotiatedPrice: Double? = nil, currency: String? = nil, completion: @escaping (Bool) -> Void) {
        apiService.applyForTask(taskId: taskId, message: message, negotiatedPrice: negotiatedPrice, currency: currency)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "申请任务")
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func approveApplication(taskId: Int, applicationId: Int, completion: @escaping (Bool, String?, String?, String?) -> Void) {
        apiService.acceptApplication(taskId: taskId, applicationId: applicationId)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure = result {
                    completion(false, nil, nil, nil)
                } else {
                    // 重新加载任务以获取最新状态
                    self?.loadTask(taskId: taskId)
                }
            }, receiveValue: { [weak self] response in
                // 如果返回了 client_secret，说明需要支付
                completion(true, response.clientSecret, response.customerId, response.ephemeralKeySecret)
                // 重新加载任务以获取最新状态
                self?.loadTask(taskId: taskId)
            })
            .store(in: &cancellables)
    }
    
    func rejectApplication(taskId: Int, applicationId: Int, completion: @escaping (Bool) -> Void) {
        apiService.rejectApplication(taskId: taskId, applicationId: applicationId)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                } else {
                    completion(true)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func completeTask(taskId: Int, evidenceImages: [String]? = nil, completion: @escaping (Bool) -> Void) {
        apiService.completeTask(taskId: taskId, evidenceImages: evidenceImages)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure = result {
                    completion(false)
                } else {
                    completion(true)
                    // 重新加载任务以获取最新状态
                    self?.loadTask(taskId: taskId)
                }
            }, receiveValue: { [weak self] _ in
                completion(true)
                // 重新加载任务以获取最新状态
                self?.loadTask(taskId: taskId)
            })
            .store(in: &cancellables)
    }
    
    func confirmTaskCompletion(taskId: Int, completion: @escaping (Bool) -> Void) {
        apiService.confirmTaskCompletion(taskId: taskId)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误，显示友好的错误信息
                    ErrorHandler.shared.handle(error, context: "确认任务完成")
                    completion(false)
                } else {
                    completion(true)
                    // 立即强制重新加载任务以获取最新状态
                    DispatchQueue.main.async {
                        self?.loadTask(taskId: taskId, force: true)
                    }
                }
            }, receiveValue: { [weak self] response in
                completion(true)
                // 立即强制重新加载任务以获取最新状态
                DispatchQueue.main.async {
                    self?.loadTask(taskId: taskId, force: true)
                }
            })
            .store(in: &cancellables)
    }
    
    func cancelTask(taskId: Int, reason: String?, completion: @escaping (Bool) -> Void) {
        apiService.cancelTask(taskId: taskId, reason: reason)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure = result {
                    completion(false)
                } else {
                    completion(true)
                    // 重新加载任务以获取最新状态
                    self?.loadTask(taskId: taskId)
                }
            }, receiveValue: { [weak self] _ in
                completion(true)
                // 重新加载任务以获取最新状态
                self?.loadTask(taskId: taskId)
            })
            .store(in: &cancellables)
    }
    
    func createReview(taskId: Int, rating: Double, comment: String?, isAnonymous: Bool = false, completion: @escaping (Bool) -> Void) {
        apiService.reviewTask(taskId: taskId, rating: rating, comment: comment, isAnonymous: isAnonymous)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                } else {
                    completion(true)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
}

