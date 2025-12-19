import Foundation
import Combine

class FleaMarketViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var categories: [FleaMarketCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadCategories() {
        apiService.request(FleaMarketCategoryResponse.self, "/api/flea-market/categories", method: "GET")
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] response in
                self?.categories = response.categories
            })
            .store(in: &cancellables)
    }
    
    func loadItems(category: String? = nil, keyword: String? = nil, page: Int = 1) {
        isLoading = true
        var endpoint = "/api/flea-market/items?page=\(page)&page_size=20&status=active"
        if let category = category {
            endpoint += "&category=\(category)"
        }
        if let keyword = keyword {
            endpoint += "&keyword=\(keyword)"
        }
        
        apiService.request(FleaMarketItemListResponse.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                if page == 1 {
                    self?.items = response.items
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
    
    func loadItem(itemId: Int) {
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
    
    func directPurchase(itemId: Int, completion: @escaping (Bool) -> Void) {
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
    
    func requestPurchase(itemId: Int, proposedPrice: Double?, message: String?, completion: @escaping (Bool) -> Void) {
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

