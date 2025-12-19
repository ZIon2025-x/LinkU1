import SwiftUI
import Combine

/// 异步图片加载器 - 企业级图片加载
public class AsyncImageLoader: ObservableObject {
    @Published public var image: UIImage?
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var cancellable: AnyCancellable?
    private let cache: ImageCache
    
    public init(cache: ImageCache = .shared) {
        self.cache = cache
    }
    
    /// 加载图片
    public func load(from url: String) {
        isLoading = true
        error = nil
        
        cancellable = cache.loadImage(from: url)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] image in
                    self?.image = image
                    self?.isLoading = false
                }
            )
    }
    
    /// 取消加载
    public func cancel() {
        cancellable?.cancel()
        isLoading = false
    }
}

