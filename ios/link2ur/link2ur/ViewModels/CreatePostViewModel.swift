import Foundation
import Combine

class CreatePostViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var title = ""
    @Published var content = ""
    @Published var selectedCategoryId: Int?
    @Published var categories: [ForumCategory] = []
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
    
    func loadCategories() {
        // 使用正确的API端点，后端会根据用户认证信息自动筛选对应学校的板块
        apiService.getForumCategories(includeAll: false, viewAs: nil, includeLatestPost: true)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                // 过滤掉 is_admin_only 的板块（普通用户不能在这些板块发帖）
                // 注意：后端接口应该已经过滤了，这里作为双重保险
                let filteredCategories = response.categories.filter { category in
                    !(category.isAdminOnly ?? false)
                }
                self?.categories = filteredCategories
                Logger.success("加载了 \(filteredCategories.count) 个可用的论坛板块（已过滤管理员专用板块）", category: .api)
            })
            .store(in: &cancellables)
    }
    
    func createPost(completion: @escaping (Bool) -> Void) {
        let startTime = Date()
        let endpoint = "/api/forum/posts"
        
        Logger.debug("CreatePostViewModel.createPost 被调用", category: .api)
        Logger.debug("标题: \(title)", category: .api)
        Logger.debug("内容长度: \(content.count)", category: .api)
        Logger.debug("分类ID: \(selectedCategoryId ?? -1)", category: .api)
        
        guard !title.isEmpty, !content.isEmpty, let categoryId = selectedCategoryId else {
            let missingFields = [
                title.isEmpty ? "标题" : nil,
                content.isEmpty ? "内容" : nil,
                selectedCategoryId == nil ? "板块" : nil
            ].compactMap { $0 }
            errorMessage = "请填写所有必填项：\(missingFields.joined(separator: "、"))"
            Logger.warning("验证失败: \(errorMessage ?? "")", category: .api)
            completion(false)
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let body: [String: Any] = [
            "title": title,
            "content": content,
            "category_id": categoryId
        ]
        
        Logger.debug("发送发布请求", category: .api)
        
        apiService.request(ForumPost.self, endpoint, method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "发布帖子")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    Logger.error("发布失败: \(error.localizedDescription)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                    completion(false)
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] post in
                Logger.success("发布成功: \(post.title)", category: .api)
                self?.reset()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func reset() {
        title = ""
        content = ""
        selectedCategoryId = nil
        errorMessage = nil
    }
}

