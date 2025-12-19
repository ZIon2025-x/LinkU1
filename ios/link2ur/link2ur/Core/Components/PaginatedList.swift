import SwiftUI
import Combine

/// 分页列表视图模型
public class PaginatedListViewModel<T: Identifiable>: ObservableObject {
    @Published public var items: [T] = []
    @Published public var isLoading = false
    @Published public var isLoadingMore = false
    @Published public var hasMore = true
    @Published public var error: Error?
    
    private var currentPage = 1
    private let pageSize: Int
    private let loadPage: (Int, Int) -> AnyPublisher<[T], Error>
    private var cancellables = Set<AnyCancellable>()
    
    public init(
        pageSize: Int = 20,
        loadPage: @escaping (Int, Int) -> AnyPublisher<[T], Error>
    ) {
        self.pageSize = pageSize
        self.loadPage = loadPage
    }
    
    /// 加载第一页
    public func loadFirstPage() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 1
        items = []
        hasMore = true
        
        loadPage(currentPage, pageSize)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] newItems in
                    self?.items = newItems
                    self?.hasMore = newItems.count >= self?.pageSize ?? 0
                }
            )
            .store(in: &cancellables)
    }
    
    /// 加载更多
    public func loadMore() {
        guard !isLoadingMore && hasMore && !isLoading else { return }
        isLoadingMore = true
        currentPage += 1
        
        loadPage(currentPage, pageSize)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMore = false
                    if case .failure(let error) = completion {
                        self?.error = error
                        self?.currentPage -= 1 // 回退页码
                    }
                },
                receiveValue: { [weak self] newItems in
                    self?.items.append(contentsOf: newItems)
                    self?.hasMore = newItems.count >= self?.pageSize ?? 0
                }
            )
            .store(in: &cancellables)
    }
    
    /// 刷新
    public func refresh() {
        loadFirstPage()
    }
}

/// 分页列表视图
public struct PaginatedList<T: Identifiable, RowContent: View>: View {
    @ObservedObject var viewModel: PaginatedListViewModel<T>
    let rowContent: (T) -> RowContent
    
    public init(
        viewModel: PaginatedListViewModel<T>,
        @ViewBuilder rowContent: @escaping (T) -> RowContent
    ) {
        self.viewModel = viewModel
        self.rowContent = rowContent
    }
    
    public var body: some View {
        List {
            ForEach(viewModel.items) { item in
                rowContent(item)
                    .onAppear {
                        if item.id == viewModel.items.last?.id {
                            viewModel.loadMore()
                        }
                    }
            }
            
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .refreshable {
            await withCheckedContinuation { continuation in
                viewModel.refresh()
                // 简化实现，实际应该等待加载完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    continuation.resume()
                }
            }
        }
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.loadFirstPage()
            }
        }
    }
}

