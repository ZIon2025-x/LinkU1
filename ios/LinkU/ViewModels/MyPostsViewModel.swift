import Foundation
import Combine

class MyPostsViewModel: ObservableObject {
    @Published var items: [FleaMarketItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadItems() {
        isLoading = true
        // 需要从AppState获取当前用户ID，这里暂时使用seller_id参数
        // 实际应该从AppState获取
        apiService.request(FleaMarketItemListResponse.self, "/api/flea-market/items?status=all&page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                // 这里应该过滤出当前用户的商品
                // 暂时显示所有商品，实际应该使用 /api/users/flea-market/items
                self?.items = response.items
            })
            .store(in: &cancellables)
    }
    
    func loadMyItems(userId: String) {
        isLoading = true
        apiService.request(FleaMarketItemListResponse.self, "/api/flea-market/items?seller_id=\(userId)&status=all&page=1&page_size=100", method: "GET")
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] response in
                self?.items = response.items
            })
            .store(in: &cancellables)
    }
}

