import Foundation
import SwiftUI
import Combine

/// 企业级图片缓存管理器
public final class ImageCache: ObservableObject {
    public static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // 配置内存缓存（优化：减少内存占用）
        cache.countLimit = 50  // 减少缓存数量
        cache.totalCostLimit = 30 * 1024 * 1024 // 30MB（减少内存占用）
        
        // 创建磁盘缓存目录
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("ImageCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - 图片加载
    
    /// 加载图片（带缓存）
    public func loadImage(from url: String) -> AnyPublisher<UIImage?, Never> {
        // 检查内存缓存
        if let cachedImage = cache.object(forKey: url as NSString) {
            return Just(cachedImage)
                .eraseToAnyPublisher()
        }
        
        // 检查磁盘缓存
        if let diskImage = loadFromDisk(url: url) {
            cache.setObject(diskImage, forKey: url as NSString)
            return Just(diskImage)
                .eraseToAnyPublisher()
        }
        
        // 从网络加载
        guard let imageURL = url.toImageURL() else {
            return Just(nil)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: imageURL)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated)) // 在后台线程处理网络请求
            .map { data, _ -> UIImage? in
                // 优化：在后台线程解码图片
                guard let image = UIImage(data: data) else { return nil }
                // 优化图片大小（减少内存占用）- 限制最大尺寸为 1200x1200（优化性能）
                return self.optimizeImageSize(image, maxSize: CGSize(width: 1200, height: 1200))
            }
            .catch { _ in Just(nil) }
            .handleEvents(receiveOutput: { [weak self] image in
                // 在后台线程保存缓存
                if let image = image {
                    DispatchQueue.global(qos: .utility).async {
                        self?.saveToCache(image: image, url: url)
                    }
                }
            })
            .receive(on: DispatchQueue.main) // 只在最后更新UI时回到主线程
            .eraseToAnyPublisher()
    }
    
    // MARK: - 缓存管理
    
    private func saveToCache(image: UIImage, url: String) {
        // 保存到内存缓存
        cache.setObject(image, forKey: url as NSString)
        
        // 保存到磁盘缓存
        saveToDisk(image: image, url: url)
    }
    
    private func saveToDisk(image: UIImage, url: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = url.md5Hash
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        try? data.write(to: fileURL)
    }
    
    private func loadFromDisk(url: String) -> UIImage? {
        let fileName = url.md5Hash
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    /// 清除所有缓存
    public func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    /// 清除过期缓存
    public func clearExpiredCache(maxAge: TimeInterval = 7 * 24 * 3600) {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return
        }
        
        let now = Date()
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let modificationDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modificationDate) > maxAge {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    // MARK: - 图片优化
    
    /// 优化图片尺寸（减少内存占用）- 在后台线程执行
    private func optimizeImageSize(_ image: UIImage, maxSize: CGSize) -> UIImage {
        let size = image.size
        
        // 如果图片尺寸小于最大尺寸，直接返回
        guard size.width > maxSize.width || size.height > maxSize.height else {
            return image
        }
        
        // 计算缩放比例
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio)
        
        // 计算新尺寸
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // 使用更高效的图片缩放方法
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

