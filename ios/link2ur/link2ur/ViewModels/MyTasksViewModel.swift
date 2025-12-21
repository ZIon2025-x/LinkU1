import Foundation
import Combine

// 用户任务申请记录（用于"我的任务"页面的待处理申请标签页）
struct UserTaskApplication: Decodable, Identifiable {
    let id: Int
    let taskId: Int
    let taskTitle: String
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
        case taskReward = "task_reward"
        case taskLocation = "task_location"
        case taskStatus = "task_status"
        case status
        case message
        case createdAt = "created_at"
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
    case all = "全部"
    case posted = "我发布的"
    case taken = "我接受的"
    case pending = "待处理申请"
    case completed = "已完成"
    case cancelled = "已取消"
    
    var icon: String {
        switch self {
        case .all: return "📋"
        case .posted: return "📤"
        case .taken: return "📥"
        case .pending: return "⏳"
        case .completed: return "✅"
        case .cancelled: return "❌"
        }
    }
}

class MyTasksViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var applications: [UserTaskApplication] = [] // 申请记录
    
    var filterType: TaskFilterType = .all
    var statusFilter: TaskStatusFilter = .all
    var currentTab: TaskTab = .all
    var currentUserId: String? // 从View传入当前用户ID
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    // 统计数据
    var totalTasksCount: Int {
        tasks.count
    }
    
    var postedTasksCount: Int {
        guard let userId = currentUserId else { return 0 }
        return tasks.filter { task in
            if let posterId = task.posterId, String(posterId) == userId {
                return task.status != .cancelled
            }
            return false
        }.count
    }
    
    var takenTasksCount: Int {
        guard let userId = currentUserId else { return 0 }
        return tasks.filter { task in
            if let takerId = task.takerId, String(takerId) == userId {
                return task.status != .cancelled
            }
            return false
        }.count
    }
    
    var completedTasksCount: Int {
        tasks.filter { $0.status == .completed }.count
    }
    
    var pendingApplicationsCount: Int {
        applications.filter { app in
            app.status == "pending" && app.taskStatus != "cancelled"
        }.count
    }
    
    // 获取待处理申请列表
    func getPendingApplications() -> [UserTaskApplication] {
        applications.filter { app in
            app.status == "pending" && app.taskStatus != "cancelled"
        }
    }
    
    // 根据当前标签页获取过滤后的任务
    func getFilteredTasks() -> [Task] {
        guard let userId = currentUserId else { return [] }
        
        switch currentTab {
        case .all:
            return tasks
        case .posted:
            return tasks.filter { task in
                if let posterId = task.posterId, String(posterId) == userId {
                    return task.status != .cancelled
                }
                return false
            }
        case .taken:
            return tasks.filter { task in
                if let takerId = task.takerId, String(takerId) == userId {
                    return task.status != .cancelled
                }
                return false
            }
        case .pending:
            return [] // 待处理申请显示在单独的列表中
        case .completed:
            return tasks.filter { $0.status == .completed }
        case .cancelled:
            return tasks.filter { $0.status == .cancelled }
        }
    }
    
    func loadTasks() {
        isLoading = true
        errorMessage = nil
        
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
        if let statusValue = statusFilter.apiValue {
            endpoint += "&status=\(statusValue)"
        }
        
        // 加载任务列表
        apiService.request([Task].self, endpoint, method: "GET")
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
                    // 我发布的：只显示poster_id匹配的任务
                    if let userId = self.currentUserId {
                        filteredTasks = filteredTasks.filter { task in
                            if let posterId = task.posterId {
                                return String(posterId) == userId
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
                
                self.tasks = filteredTasks
            })
            .store(in: &cancellables)
        
        // 并行加载申请记录（失败不影响任务列表显示）
        apiService.request([UserTaskApplication].self, "/api/my-applications", method: "GET")
            .sink(receiveCompletion: { _ in
                // 静默处理错误，不影响主任务列表
            }, receiveValue: { [weak self] applications in
                self?.applications = applications
            })
            .store(in: &cancellables)
    }
}

