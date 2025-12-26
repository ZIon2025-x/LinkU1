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
    
    func loadTask(taskId: Int) {
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
                self?.task = task
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
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务申请列表")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    Logger.error("加载申请列表失败: \(error.localizedDescription)", category: .api)
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
    
    func approveApplication(taskId: Int, applicationId: Int, completion: @escaping (Bool) -> Void) {
        apiService.acceptApplication(taskId: taskId, applicationId: applicationId)
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
    
    func completeTask(taskId: Int, completion: @escaping (Bool) -> Void) {
        apiService.completeTask(taskId: taskId)
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
    
    func confirmTaskCompletion(taskId: Int, completion: @escaping (Bool) -> Void) {
        apiService.confirmTaskCompletion(taskId: taskId)
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
    
    func cancelTask(taskId: Int, reason: String?, completion: @escaping (Bool) -> Void) {
        apiService.cancelTask(taskId: taskId, reason: reason)
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

