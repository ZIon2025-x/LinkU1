import Foundation
import Combine
import SwiftUI

/// 发现更多 Feed ViewModel（与 Flutter HomeBloc discovery 一致，数据来自 /api/discovery/feed）
class DiscoveryFeedViewModel: ObservableObject {
    @Published var items: [DiscoveryFeedItem] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var currentPage = 1
    private let pageSize = 20
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadFeed() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentPage = 1
        
        apiService.getDiscoveryFeed(page: 1, limit: pageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.items = response.items
                self?.hasMore = response.hasMore
                self?.currentPage = 1
            }
            .store(in: &cancellables)
    }
    
    func loadMore() {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        apiService.getDiscoveryFeed(page: nextPage, limit: pageSize)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            } receiveValue: { [weak self] response in
                self?.errorMessage = nil
                self?.items.append(contentsOf: response.items)
                self?.hasMore = response.hasMore
                self?.currentPage = nextPage
            }
            .store(in: &cancellables)
    }
    
    func refresh() {
        loadFeed()
    }
}
