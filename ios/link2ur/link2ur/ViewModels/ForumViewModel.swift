import Foundation
import Combine

class ForumViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var categories: [ForumCategory] = []
    @Published var posts: [ForumPost] = []
    @Published var selectedCategory: ForumCategory?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var isRequestingCategories = false // 防止重复请求
    
    init(apiService: APIService? = nil) {
        // 使用依赖注入或回退到默认实现
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadCategories(universityId: Int? = nil) {
        let startTime = Date()
        let endpoint = "/api/forum/forums/visible"
        
        // 防止重复请求
        guard !isRequestingCategories else {
            Logger.warning("论坛分类请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isRequestingCategories = true
        isLoading = true
        
        // 使用正确的API端点，后端会根据用户认证信息自动筛选对应学校的板块
        // 如果提供了 universityId，可以用于额外筛选（如果需要）
        apiService.getForumCategories(includeAll: false, viewAs: nil, includeLatestPost: true)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                self?.isRequestingCategories = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载论坛分类")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
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
                // 后端应该已经根据用户认证信息返回对应学校的板块
                // 如果还需要前端筛选，可以在这里添加
                self?.categories = response.categories
                self?.isRequestingCategories = false
                Logger.success("加载了 \(response.categories.count) 个论坛板块", category: .api)
            })
            .store(in: &cancellables)
    }
    
    func loadPosts(categoryId: Int? = nil, page: Int = 1, forceRefresh: Bool = false) {
        let startTime = Date()
        
        isLoading = true
        
        // 强制刷新时清除缓存
        if forceRefresh && page == 1 {
            CacheManager.shared.invalidateForumPostsCache()
        }
        
        // 尝试从缓存加载数据（仅第一页，且非强制刷新）
        if page == 1 && !forceRefresh {
            if let cachedPosts = CacheManager.shared.loadForumPosts(categoryId: categoryId) {
                self.posts = cachedPosts
                Logger.success("从缓存加载了 \(self.posts.count) 个帖子", category: .cache)
                isLoading = false
                // 继续在后台刷新数据
            }
        }
        
        var endpoint = "/api/forum/posts?page=\(page)&page_size=20"
        if let categoryId = categoryId {
            endpoint += "&category_id=\(categoryId)"
        }
        
        apiService.request(ForumPostListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载论坛帖子")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
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
                if page == 1 {
                    self?.posts = response.posts
                    // 保存到缓存（仅第一页）
                    CacheManager.shared.saveForumPosts(response.posts, categoryId: categoryId)
                    Logger.success("已缓存 \(response.posts.count) 个帖子", category: .cache)
                } else {
                    self?.posts.append(contentsOf: response.posts)
                }
            })
            .store(in: &cancellables)
    }
}

class ForumPostDetailViewModel: ObservableObject {
    @Published var post: ForumPost?
    @Published var replies: [ForumReply] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        // 使用依赖注入或回退到默认实现
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadPost(postId: Int) {
        isLoading = true
        apiService.request(ForumPost.self, "/api/forum/posts/\(postId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载帖子详情")
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] post in
                self?.post = post
            })
            .store(in: &cancellables)
    }
    
    func loadReplies(postId: Int, page: Int = 1, pageSize: Int = 50) {
        Logger.debug("开始加载回复，postId: \(postId), page: \(page), pageSize: \(pageSize)", category: .api)
        // 使用带分页参数的 API 端点（参考前端实现：page_size=50）
        apiService.getForumReplies(postId: postId, page: page, pageSize: pageSize)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载帖子回复")
                    Logger.error("加载回复失败: \(error.localizedDescription)", category: .api)
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] response in
                Logger.success("成功加载 \(response.replies.count) 条回复", category: .api)
                self?.replies = response.replies
            })
            .store(in: &cancellables)
    }
    
    func toggleLike(targetType: String, targetId: Int, completion: @escaping (Bool, Int) -> Void) {
        let body = ["target_type": targetType, "target_id": targetId] as [String : Any] as [String : Any]
        apiService.request(ForumLikeResponse.self, "/api/forum/likes", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.liked, response.likeCount)
            })
            .store(in: &cancellables)
    }
    
    func toggleFavorite(postId: Int, completion: @escaping (Bool) -> Void) {
        let body = ["post_id": postId]
        apiService.request(ForumFavoriteResponse.self, "/api/forum/favorites", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.favorited)
            })
            .store(in: &cancellables)
    }
    
    func replyToPost(postId: Int, content: String, parentReplyId: Int? = nil, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [
            "content": content
        ]
        
        if let parentId = parentReplyId {
            body["parent_reply_id"] = parentId
        }
        
        apiService.request(ForumReply.self, "/api/forum/posts/\(postId)/replies", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] _ in
                // 重新加载回复列表
                self?.loadReplies(postId: postId)
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func likeReply(replyId: Int, completion: @escaping (Bool, Int) -> Void) {
        let body: [String: Any] = [
            "target_type": "reply",
            "target_id": replyId
        ]
        
        apiService.request(ForumLikeResponse.self, "/api/forum/likes", method: "POST", body: body)
            .sink(receiveCompletion: { _ in }, receiveValue: { response in
                completion(response.liked, response.likeCount)
            })
            .store(in: &cancellables)
    }
}

