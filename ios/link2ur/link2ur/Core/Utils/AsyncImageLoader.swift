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
                receiveCompletion: { [weak self] _ in
                    // ImageCache 返回的 Publisher 不会产生错误（Never 类型）
                    self?.isLoading = false
                },
                receiveValue: { [weak self] image in
                    self?.image = image
                    self?.isLoading = false
                    // 如果图片为 nil，可能是加载失败
                    if image == nil {
                        self?.error = NSError(domain: "ImageLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "图片加载失败"])
                    }
                }
            )
    }
    
    /// 取消加载
    public func cancel() {
        cancellable?.cancel()
        isLoading = false
    }
}

