import Foundation
import Combine

class FleaMarketViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var items: [FleaMarketItem] = []
    @Published var categories: [FleaMarketCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var favoritedItemIds: Set<String> = [] // 收藏的商品ID集合
    
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
        apiService.request(FleaMarketCategoryResponse.self, "/api/flea-market/categories", method: "GET")
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载跳蚤市场分类")
                }
            }, receiveValue: { [weak self] response in
                self?.categories = response.categoryList
            })
            .store(in: &cancellables)
    }
    
    func loadItems(category: String? = nil, keyword: String? = nil, page: Int = 1, forceRefresh: Bool = false) {
        let startTime = Date()
        
        isLoading = true
        
        // 强制刷新时清除缓存
        if forceRefresh && page == 1 && (keyword == nil || keyword?.isEmpty == true) {
            CacheManager.shared.invalidateFleaMarketCache()
        }
        
        // 尝试从缓存加载数据（仅第一页且无搜索关键词时，且非强制刷新）
        // 注意：如果缓存中有空数组，不要使用缓存，避免显示空列表
        if page == 1 && !forceRefresh && (keyword == nil || keyword?.isEmpty == true) {
            if let cachedItems = CacheManager.shared.loadFleaMarketItems(category: category), !cachedItems.isEmpty {
                self.items = cachedItems
                Logger.success("从缓存加载了 \(self.items.count) 个跳蚤市场商品", category: .cache)
                isLoading = false
                // 继续在后台刷新数据
            }
        }
        
        var endpoint = "/api/flea-market/items?page=\(page)&page_size=20&status=active"
        if let category = category, !category.isEmpty {
            endpoint += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)"
        }
        if let keyword = keyword, !keyword.isEmpty {
            endpoint += "&keyword=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)"
        }
        
        apiService.request(FleaMarketItemListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载跳蚤市场商品")
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
            }, receiveValue: { [weak self] response in
                if page == 1 {
                    self?.items = response.items
                    // 保存到缓存（仅第一页且无搜索关键词时）
                    if keyword == nil || keyword?.isEmpty == true {
                        CacheManager.shared.saveFleaMarketItems(response.items, category: category)
                        Logger.success("已缓存 \(response.items.count) 个跳蚤市场商品", category: .cache)
                    }
                } else {
                    self?.items.append(contentsOf: response.items)
                }
                // 加载收藏列表（如果用户已登录）
                self?.loadFavoriteIds()
            })
            .store(in: &cancellables)
    }
    
    /// 加载收藏的商品ID列表
    func loadFavoriteIds() {
        apiService.request(MyFavoritesResponse.self, "/api/flea-market/favorites?page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { _ in
                // 静默处理错误，不影响主列表显示
            }, receiveValue: { [weak self] response in
                self?.favoritedItemIds = Set(response.items.map { $0.itemId })
            })
            .store(in: &cancellables)
    }
}

class FleaMarketDetailViewModel: ObservableObject {
    @Published var item: FleaMarketItem?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isFavorited = false
    @Published var isTogglingFavorite = false
    @Published var purchaseRequests: [PurchaseRequest] = []
    @Published var isLoadingPurchaseRequests = false
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var currentItemId: String? // 跟踪当前加载的 itemId
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadItem(itemId: String, preserveItem: Bool = false) {
        // 如果 itemId 相同且已有数据，且 preserveItem 为 true，则跳过加载
        if preserveItem, let existingItem = item, existingItem.id == itemId {
            // 已有数据且ID匹配，不需要重新加载
            return
        }
        
        // 如果正在加载相同的 itemId，跳过
        if currentItemId == itemId && isLoading {
            return
        }
        
        currentItemId = itemId
        
        // 如果 preserveItem 为 true，在加载时保持现有 item，避免视图消失
        if !preserveItem {
            isLoading = true
        }
        
        apiService.request(FleaMarketItem.self, "/api/flea-market/items/\(itemId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] item in
                self?.item = item
                // 加载商品后检查收藏状态
                self?.checkFavoriteStatus(itemId: itemId)
            })
            .store(in: &cancellables)
    }
    
    /// 检查当前商品是否已被收藏
    func checkFavoriteStatus(itemId: String) {
        apiService.request(MyFavoritesResponse.self, "/api/flea-market/favorites?page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("检查收藏状态失败: \(error.localizedDescription)", category: .network)
                }
            }, receiveValue: { [weak self] response in
                // 检查当前商品是否在收藏列表中
                let favoriteItemIds = response.items.map { $0.itemId }
                self?.isFavorited = favoriteItemIds.contains(itemId)
            })
            .store(in: &cancellables)
    }
    
    /// 切换收藏状态
    func toggleFavorite(itemId: String, completion: @escaping (Bool) -> Void) {
        guard !isTogglingFavorite else { return }
        isTogglingFavorite = true
        
        apiService.request(FavoriteToggleResponse.self, "/api/flea-market/items/\(itemId)/favorite", method: "POST", body: [:])
            .sink(receiveCompletion: { [weak self] result in
                self?.isTogglingFavorite = false
                if case .failure(let error) = result {
                    Logger.error("切换收藏状态失败: \(error.localizedDescription)", category: .network)
                    completion(false)
                }
            }, receiveValue: { [weak self] response in
                if response.success {
                    self?.isFavorited = response.data.isFavorited
                    completion(true)
                } else {
                    completion(false)
                }
            })
            .store(in: &cancellables)
    }
    
    func directPurchase(itemId: String, completion: @escaping (DirectPurchaseResponse.DirectPurchaseData?) -> Void, onError: ((String) -> Void)? = nil) {
        apiService.request(DirectPurchaseResponse.self, "/api/flea-market/items/\(itemId)/direct-purchase", method: "POST", body: [:])
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 提取用户友好的错误消息
                    // 注意：error 已经是 APIError 类型（因为 request 方法返回 AnyPublisher<T, APIError>）
                    let errorMessage = error.userFriendlyMessage
                    // 调用错误回调
                    onError?(errorMessage)
                    // 使用 ErrorHandler 处理错误（用于统一错误处理）
                    ErrorHandler.shared.handle(error, context: "直接购买跳蚤市场商品")
                    completion(nil)
                }
            }, receiveValue: { response in
                completion(response.data)
            })
            .store(in: &cancellables)
    }
    
    func requestPurchase(itemId: String, proposedPrice: Double?, message: String?, completion: @escaping (Bool, String?) -> Void) {
        var body: [String: Any] = [:]
        if let price = proposedPrice {
            body["proposed_price"] = price
        }
        if let message = message {
            body["message"] = message
        }
        
        apiService.request(PurchaseRequest.self, "/api/flea-market/items/\(itemId)/purchase-request", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 提取用户友好的错误消息
                    let errorMessage = error.userFriendlyMessage
                    // 使用 ErrorHandler 统一处理错误（用于日志记录）
                    ErrorHandler.shared.handle(error, context: "发送跳蚤市场议价请求")
                    completion(false, errorMessage)
                }
            }, receiveValue: { _ in
                completion(true, nil)
            })
            .store(in: &cancellables)
    }
    
    /// 刷新商品（重置自动删除计时器）
    func refreshItem(itemId: String, completion: @escaping (Bool) -> Void) {
        apiService.refreshFleaMarketItem(itemId: itemId)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("刷新商品失败: \(error.localizedDescription)", category: .network)
                    completion(false)
                }
            }, receiveValue: { [weak self] _ in
                // 刷新成功后，延迟重新加载商品信息以更新refreshed_at
                // 使用 preserveItem: true 避免视图消失
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.loadItem(itemId: itemId, preserveItem: true)
                }
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 加载购买申请列表（仅商品所有者可查看）
    func loadPurchaseRequests(itemId: String) {
        isLoadingPurchaseRequests = true
        
        apiService.request(PurchaseRequestListResponse.self, "/api/flea-market/items/\(itemId)/purchase-requests", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingPurchaseRequests = false
                if case .failure(let error) = result {
                    Logger.error("加载购买申请列表失败: \(error.localizedDescription)", category: .network)
                    ErrorHandler.shared.handle(error, context: "加载购买申请列表")
                }
            }, receiveValue: { [weak self] response in
                if response.success {
                    self?.purchaseRequests = response.data.requests
                }
            })
            .store(in: &cancellables)
    }
    
    /// 同意购买申请
    func approvePurchaseRequest(requestId: String, completion: @escaping (ApprovePurchaseRequestResponse.ApprovePurchaseRequestData?) -> Void) {
        apiService.request(ApprovePurchaseRequestResponse.self, "/api/flea-market/purchase-requests/\(requestId)/approve", method: "POST", body: [:])
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("同意购买申请失败: \(error.localizedDescription)", category: .network)
                    ErrorHandler.shared.handle(error, context: "同意购买申请")
                    completion(nil)
                }
            }, receiveValue: { response in
                if response.success {
                    completion(response.data)
                } else {
                    completion(nil)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 拒绝购买申请
    func rejectPurchaseRequest(itemId: String, requestId: String, completion: @escaping (Bool) -> Void) {
        // 解析请求ID（从格式化ID转换为数据库ID，如"S0020" -> 20）
        let dbRequestId: Int
        if requestId.hasPrefix("S") {
            // 移除"S"前缀并转换为整数
            let numericPart = String(requestId.dropFirst())
            guard let id = Int(numericPart) else {
                Logger.error("无效的请求ID格式: \(requestId)", category: .network)
                completion(false)
                return
            }
            dbRequestId = id
        } else {
            // 直接转换为整数
            guard let id = Int(requestId) else {
                Logger.error("无效的请求ID格式: \(requestId)", category: .network)
                completion(false)
                return
            }
            dbRequestId = id
        }
        
        apiService.request(RejectPurchaseRequestResponse.self, "/api/flea-market/items/\(itemId)/reject-purchase", method: "POST", body: ["purchase_request_id": dbRequestId])
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.error("拒绝购买申请失败: \(error.localizedDescription)", category: .network)
                    ErrorHandler.shared.handle(error, context: "拒绝购买申请")
                    completion(false)
                }
            }, receiveValue: { response in
                completion(response.success)
            })
            .store(in: &cancellables)
    }
}

