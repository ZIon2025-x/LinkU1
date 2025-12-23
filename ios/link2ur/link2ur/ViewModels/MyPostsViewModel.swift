import Foundation
import Combine

/// 我的闲置分类枚举
enum MyItemsCategory: Int, CaseIterable, Hashable {
    case selling = 0      // 正在出售
    case purchased = 1    // 收的闲置（已购买）
    case favorites = 2    // 收藏的
    case sold = 3         // 已售出
    
    var title: String {
        switch self {
        case .selling: return "正在出售"
        case .purchased: return "收的闲置"
        case .favorites: return "收藏的"
        case .sold: return "已售出"
        }
    }
    
    var emptyTitle: String {
        switch self {
        case .selling: return "暂无在售商品"
        case .purchased: return "暂无购买记录"
        case .favorites: return "暂无收藏"
        case .sold: return "暂无已售商品"
        }
    }
    
    var emptyMessage: String {
        switch self {
        case .selling: return "您还没有发布任何闲置商品"
        case .purchased: return "您还没有购买过任何商品"
        case .favorites: return "您还没有收藏任何商品"
        case .sold: return "您还没有成功出售过商品"
        }
    }
    
    var icon: String {
        switch self {
        case .selling: return "tag.fill"
        case .purchased: return "bag.fill"
        case .favorites: return "heart.fill"
        case .sold: return "checkmark.circle.fill"
        }
    }
}

class MyPostsViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    
    // 各分类的数据
    @Published var sellingItems: [FleaMarketItem] = []
    @Published var purchasedItems: [FleaMarketItem] = []
    @Published var favoriteItems: [FleaMarketItem] = []
    @Published var soldItems: [FleaMarketItem] = []
    
    // 各分类的加载状态
    @Published var isLoadingSelling = false
    @Published var isLoadingPurchased = false
    @Published var isLoadingFavorites = false
    @Published var isLoadingSold = false
    
    @Published var errorMessage: String?
    
    // 当前选中的分类
    @Published var selectedCategory: MyItemsCategory = .selling
    
    // 防止重复加载的标志
    private var hasLoadedOnce = false
    private var lastLoadTime: Date?
    private let minLoadInterval: TimeInterval = 5 // 最小加载间隔（秒）
    
    // 兼容旧代码
    var items: [FleaMarketItem] {
        switch selectedCategory {
        case .selling: return sellingItems
        case .purchased: return purchasedItems
        case .favorites: return favoriteItems
        case .sold: return soldItems
        }
    }
    
    var isLoading: Bool {
        switch selectedCategory {
        case .selling: return isLoadingSelling
        case .purchased: return isLoadingPurchased
        case .favorites: return isLoadingFavorites
        case .sold: return isLoadingSold
        }
    }
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// 加载所有分类的数据
    func loadAllCategories(userId: String, forceRefresh: Bool = false) {
        // 防止频繁刷新：如果不是强制刷新，且距离上次加载时间太短，则跳过
        if !forceRefresh {
            if let lastLoad = lastLoadTime {
                let timeSinceLastLoad = Date().timeIntervalSince(lastLoad)
                if timeSinceLastLoad < minLoadInterval {
                    return // 距离上次加载时间太短，跳过
                }
            }
        }
        
        lastLoadTime = Date()
        hasLoadedOnce = true
        
        loadSellingItems(userId: userId)
        loadPurchasedItems()
        loadFavoriteItems()
        loadSoldItems(userId: userId)
    }
    
    /// 加载正在出售的商品
    func loadSellingItems(userId: String) {
        let startTime = Date()
        let endpoint = "/api/flea-market/items"
        
        isLoadingSelling = true
        apiService.request(FleaMarketItemListResponse.self, "\(endpoint)?seller_id=\(userId)&status=active&page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoadingSelling = false
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载在售商品")
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    self?.errorMessage = error.userFriendlyMessage
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                // 优化：在主线程更新UI，但数据处理在后台线程
                DispatchQueue.main.async {
                    self.sellingItems = response.items
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载已购买的商品
    func loadPurchasedItems() {
        let startTime = Date()
        let endpoint = "/api/flea-market/my-purchases"
        
        isLoadingPurchased = true
        apiService.getMyPurchases(page: 1, pageSize: 100)
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoadingPurchased = false
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载购买记录")
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                // 优化：在主线程更新UI
                DispatchQueue.main.async {
                    self.purchasedItems = response.items
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载收藏的商品
    func loadFavoriteItems() {
        let startTime = Date()
        let endpoint = "/api/flea-market/favorites"
        
        isLoadingFavorites = true
        apiService.getMyFavorites(page: 1, pageSize: 100)
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoadingFavorites = false
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载收藏列表")
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                // 优化：在主线程更新UI
                DispatchQueue.main.async {
                    self.favoriteItems = response.items
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载已售出的商品
    func loadSoldItems(userId: String) {
        let startTime = Date()
        let endpoint = "/api/flea-market/items"
        
        isLoadingSold = true
        apiService.request(FleaMarketItemListResponse.self, "\(endpoint)?seller_id=\(userId)&status=sold&page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoadingSold = false
                if case .failure(let error) = completion {
                    ErrorHandler.shared.handle(error, context: "加载已售商品")
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                // 优化：在主线程更新UI
                DispatchQueue.main.async {
                    self.soldItems = response.items
                }
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 兼容旧代码的方法
    
    func loadItems() {
        loadSellingItems(userId: "")
    }
    
    func loadMyItems(userId: String) {
        loadAllCategories(userId: userId)
    }
}
