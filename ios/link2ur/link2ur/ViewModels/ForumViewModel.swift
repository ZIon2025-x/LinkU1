import Foundation
import Combine

class ForumViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var categories: [ForumCategory] = []
    @Published var posts: [ForumPost] = []
    @Published var selectedCategory: ForumCategory?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 我的帖子相关状态
    @Published var myPosts: [ForumPost] = []
    @Published var isLoadingMyPosts = false
    @Published var errorMessageMyPosts: String?
    
    // 我收藏的帖子相关状态
    @Published var favoritedPosts: [ForumPost] = []
    @Published var isLoadingFavoritedPosts = false
    @Published var errorMessageFavoritedPosts: String?
    
    // 我喜欢的帖子相关状态
    @Published var likedPosts: [ForumPost] = []
    @Published var isLoadingLikedPosts = false
    @Published var errorMessageLikedPosts: String?
    
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
                    // error 已经是 APIError 类型，直接使用
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
            }, receiveValue: { [weak self] response in
                // 后端应该已经根据用户认证信息返回对应学校的板块
                // 如果还需要前端筛选，可以在这里添加
                var categories = response.categories
                
                // 批量获取收藏状态（如果用户已登录）
                if !categories.isEmpty {
                    let categoryIds = categories.map { $0.id }
                    guard let strongSelf = self else { return }
                    strongSelf.apiService.getCategoryFavoritesBatch(categoryIds: categoryIds)
                        .sink(receiveCompletion: { result in
                            if case .failure(let error) = result {
                                Logger.warning("批量获取板块收藏状态失败: \(error.localizedDescription)", category: .api)
                            }
                        }, receiveValue: { [weak self] favoriteResponse in
                            // 更新收藏状态
                            for i in 0..<categories.count {
                                let categoryId = categories[i].id
                                categories[i].isFavorited = favoriteResponse.favorites[categoryId] ?? false
                            }
                            self?.categories = categories
                            self?.isRequestingCategories = false
                            // 保存到缓存
                            CacheManager.shared.saveForumCategories(categories)
                            Logger.success("加载了 \(categories.count) 个论坛板块（已更新收藏状态）", category: .api)
                        })
                        .store(in: &strongSelf.cancellables)
                } else {
                    self?.categories = categories
                    self?.isRequestingCategories = false
                    // 保存到缓存
                    CacheManager.shared.saveForumCategories(categories)
                    Logger.success("加载了 \(categories.count) 个论坛板块", category: .api)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 收藏/取消收藏板块
    func toggleCategoryFavorite(categoryId: Int, completion: @escaping (Bool) -> Void) {
        apiService.toggleCategoryFavorite(categoryId: categoryId)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "收藏操作")
                    completion(false)
                }
            }, receiveValue: { [weak self] response in
                // 更新本地状态
                if let index = self?.categories.firstIndex(where: { $0.id == categoryId }) {
                    self?.categories[index].isFavorited = response.favorited
                }
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func loadPosts(categoryId: Int? = nil, keyword: String? = nil, page: Int = 1, forceRefresh: Bool = false) {
        let startTime = Date()
        
        // 防止重复请求
        guard !isLoading || page > 1 else {
            Logger.warning("论坛帖子请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isLoading = true
        
        // 强制刷新时清除缓存
        if forceRefresh && page == 1 {
            CacheManager.shared.invalidateForumPostsCache()
        }
        
        // 尝试从缓存加载数据（仅第一页，且非强制刷新，且无搜索关键词）
        if page == 1 && !forceRefresh && (keyword == nil || keyword?.isEmpty == true) {
            if let cachedPosts = CacheManager.shared.loadForumPosts(categoryId: categoryId) {
                self.posts = cachedPosts
                Logger.success("从缓存加载了 \(self.posts.count) 个帖子", category: .cache)
                isLoading = false
                // 继续在后台刷新数据
            }
        }
        
        // 使用 APIService 的 getForumPosts 方法，支持 keyword 参数
        // 确保传递 categoryId，限制搜索范围在当前板块
        Logger.debug("加载论坛帖子 - categoryId: \(categoryId?.description ?? "nil"), keyword: \(keyword?.description ?? "nil")", category: .api)
        
        // 构建 endpoint 字符串用于性能监控
        var endpoint = "/api/forum/posts?page=\(page)&page_size=20&sort=latest"
        if let categoryId = categoryId {
            endpoint += "&category_id=\(categoryId)"
        }
        if let keyword = keyword, !keyword.isEmpty {
            if let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                endpoint += "&q=\(encodedKeyword)"
            } else {
                endpoint += "&q=\(keyword)"
            }
        }
        
        apiService.getForumPosts(page: page, pageSize: 20, categoryId: categoryId, sort: "latest", keyword: keyword)
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
                    // error 已经是 APIError 类型，直接使用
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
    
    /// 加载我的帖子
    func loadMyPosts(page: Int = 1) {
        guard !isLoadingMyPosts || page > 1 else { return }
        isLoadingMyPosts = true
        
        apiService.getMyPosts(page: page, pageSize: 20)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingMyPosts = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载我的帖子")
                    self?.errorMessageMyPosts = error.userFriendlyMessage
                } else {
                    self?.errorMessageMyPosts = nil
                }
            }, receiveValue: { [weak self] response in
                if page == 1 {
                    self?.myPosts = response.posts
                } else {
                    self?.myPosts.append(contentsOf: response.posts)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载我收藏的帖子
    func loadFavoritedPosts(page: Int = 1) {
        guard !isLoadingFavoritedPosts || page > 1 else { return }
        isLoadingFavoritedPosts = true
        
        let endpoint = "/api/forum/my/favorites?page=\(page)&page_size=20"
        apiService.request(ForumFavoriteListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingFavoritedPosts = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载我收藏的帖子")
                    self?.errorMessageFavoritedPosts = error.userFriendlyMessage
                } else {
                    self?.errorMessageFavoritedPosts = nil
                }
            }, receiveValue: { [weak self] response in
                let posts = response.favorites.map { $0.post }
                if page == 1 {
                    self?.favoritedPosts = posts
                } else {
                    self?.favoritedPosts.append(contentsOf: posts)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载我喜欢的帖子
    func loadLikedPosts(page: Int = 1) {
        guard !isLoadingLikedPosts || page > 1 else { return }
        isLoadingLikedPosts = true
        
        let endpoint = "/api/forum/my/likes?target_type=post&page=\(page)&page_size=20"
        apiService.request(ForumLikeListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingLikedPosts = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载我喜欢的帖子")
                    self?.errorMessageLikedPosts = error.userFriendlyMessage
                } else {
                    self?.errorMessageLikedPosts = nil
                }
            }, receiveValue: { [weak self] response in
                // 只提取帖子类型的喜欢（过滤掉回复）
                let posts = response.likes.compactMap { item -> ForumPost? in
                    if item.targetType == "post" {
                        return item.post
                    }
                    return nil
                }
                if page == 1 {
                    self?.likedPosts = posts
                } else {
                    self?.likedPosts.append(contentsOf: posts)
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Async Methods for Refreshable
    
    @MainActor
    func loadMyPostsAsync() async {
        isLoadingMyPosts = true
        errorMessageMyPosts = nil
        
        do {
            let response = try await apiService.getMyPosts(page: 1, pageSize: 20).async()
            myPosts = response.posts
            isLoadingMyPosts = false
        } catch {
            isLoadingMyPosts = false
            if let apiError = error as? APIError {
                ErrorHandler.shared.handle(apiError, context: "加载我的帖子")
                errorMessageMyPosts = apiError.userFriendlyMessage
            } else {
                errorMessageMyPosts = "加载失败，请稍后重试"
            }
        }
    }
    
    @MainActor
    func loadFavoritedPostsAsync() async {
        isLoadingFavoritedPosts = true
        errorMessageFavoritedPosts = nil
        
        do {
            let endpoint = "/api/forum/my/favorites?page=1&page_size=20"
            let response = try await apiService.request(ForumFavoriteListResponse.self, endpoint, method: "GET").async()
            favoritedPosts = response.favorites.map { $0.post }
            isLoadingFavoritedPosts = false
        } catch {
            isLoadingFavoritedPosts = false
            if let apiError = error as? APIError {
                ErrorHandler.shared.handle(apiError, context: "加载我收藏的帖子")
                errorMessageFavoritedPosts = apiError.userFriendlyMessage
            } else {
                errorMessageFavoritedPosts = "加载失败，请稍后重试"
            }
        }
    }
    
    @MainActor
    func loadLikedPostsAsync() async {
        isLoadingLikedPosts = true
        errorMessageLikedPosts = nil
        
        do {
            let endpoint = "/api/forum/my/likes?target_type=post&page=1&page_size=20"
            let response = try await apiService.request(ForumLikeListResponse.self, endpoint, method: "GET").async()
            // 只提取帖子类型的喜欢（过滤掉回复）
            likedPosts = response.likes.compactMap { item -> ForumPost? in
                if item.targetType == "post" {
                    return item.post
                }
                return nil
            }
            isLoadingLikedPosts = false
        } catch {
            isLoadingLikedPosts = false
            if let apiError = error as? APIError {
                ErrorHandler.shared.handle(apiError, context: "加载我喜欢的帖子")
                errorMessageLikedPosts = apiError.userFriendlyMessage
            } else {
                errorMessageLikedPosts = "加载失败，请稍后重试"
            }
        }
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
        // 防止重复请求
        guard !isLoading else {
            Logger.debug("帖子详情请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        isLoading = true
        apiService.request(ForumPost.self, "/api/forum/posts/\(postId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载帖子详情")
                    // error 已经是 APIError 类型，直接使用
                    self?.errorMessage = error.userFriendlyMessage
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
                    // error 已经是 APIError 类型，直接使用
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] response in
                Logger.success("成功加载 \(response.replies.count) 条回复", category: .api)
                self?.replies = response.replies
            })
            .store(in: &cancellables)
    }
    
    func toggleLike(targetType: String, targetId: Int, completion: @escaping (Bool, Int) -> Void) {
        let body = ["target_type": targetType, "target_id": targetId] as [String : Any]
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

