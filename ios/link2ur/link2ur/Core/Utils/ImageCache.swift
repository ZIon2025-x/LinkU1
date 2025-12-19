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
        // 配置内存缓存
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
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
        guard let imageURL = URL(string: url) else {
            return Just(nil)
                .eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: imageURL)
            .map { data, _ in UIImage(data: data) }
            .catch { _ in Just(nil) }
            .handleEvents(receiveOutput: { [weak self] image in
                if let image = image {
                    self?.saveToCache(image: image, url: url)
                }
            })
            .receive(on: DispatchQueue.main)
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
}

