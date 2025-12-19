import Foundation
import Combine

class FleaMarketViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var categories: [FleaMarketCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadCategories() {
        apiService.request(FleaMarketCategoryResponse.self, "/api/flea-market/categories", method: "GET")
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载跳蚤市场分类")
                }
            }, receiveValue: { [weak self] response in
                self?.categories = response.categories
            })
            .store(in: &cancellables)
    }
    
    func loadItems(category: String? = nil, keyword: String? = nil, page: Int = 1, forceRefresh: Bool = false) {
        isLoading = true
        
        // 强制刷新时清除缓存
        if forceRefresh && page == 1 && (keyword == nil || keyword?.isEmpty == true) {
            CacheManager.shared.invalidateFleaMarketCache()
        }
        
        // 尝试从缓存加载数据（仅第一页且无搜索关键词时，且非强制刷新）
        if page == 1 && !forceRefresh && (keyword == nil || keyword?.isEmpty == true) {
            if let cachedItems = CacheManager.shared.loadFleaMarketItems(category: category) {
                self.items = cachedItems
                print("✅ 从缓存加载了 \(self.items.count) 个跳蚤市场商品")
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
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载跳蚤市场商品")
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] response in
                if page == 1 {
                    self?.items = response.items
                    // 保存到缓存（仅第一页且无搜索关键词时）
                    if keyword == nil || keyword?.isEmpty == true {
                        CacheManager.shared.saveFleaMarketItems(response.items, category: category)
                        print("✅ 已缓存 \(response.items.count) 个跳蚤市场商品")
                    }
                } else {
                    self?.items.append(contentsOf: response.items)
                }
            })
            .store(in: &cancellables)
    }
}

class FleaMarketDetailViewModel: ObservableObject {
    @Published var item: FleaMarketItem?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadItem(itemId: String) {
        isLoading = true
        apiService.request(FleaMarketItem.self, "/api/flea-market/items/\(itemId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] item in
                self?.item = item
            })
            .store(in: &cancellables)
    }
    
    func directPurchase(itemId: String, completion: @escaping (Bool) -> Void) {
        apiService.request(EmptyResponse.self, "/api/flea-market/items/\(itemId)/direct-purchase", method: "POST", body: [:])
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func requestPurchase(itemId: String, proposedPrice: Double?, message: String?, completion: @escaping (Bool) -> Void) {
        var body: [String: Any] = [:]
        if let price = proposedPrice {
            body["proposed_price"] = price
        }
        if let message = message {
            body["message"] = message
        }
        
        apiService.request(PurchaseRequest.self, "/api/flea-market/items/\(itemId)/purchase-request", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
}

