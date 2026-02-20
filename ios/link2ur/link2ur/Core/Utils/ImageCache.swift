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
        // 配置内存缓存（优化：减少内存占用，防止内存溢出）
        cache.countLimit = 30  // 进一步减少缓存数量（从50降到30）
        cache.totalCostLimit = 20 * 1024 * 1024 // 20MB（从30MB降到20MB，防止内存溢出）
        
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = cacheDir.appendingPathComponent("ImageCache")
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // 收到内存警告时，清理部分缓存
        Logger.warning("收到内存警告，清理图片缓存", category: .general)
        cache.removeAllObjects()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 图片加载
    
    /// 同步检查缓存（用于立即显示已缓存的图片）
    public func getCachedImage(from url: String) -> UIImage? {
        // 检查内存缓存
        if let cachedImage = cache.object(forKey: url as NSString) {
            return cachedImage
        }
        
        // 检查磁盘缓存
        if let diskImage = loadFromDisk(url: url) {
            cache.setObject(diskImage, forKey: url as NSString)
            return diskImage
        }
        
        return nil
    }
    
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
                // 检查数据大小，防止加载过大的图片（超过5MB的图片数据）
                if data.count > 5 * 1024 * 1024 {
                    Logger.warning("图片数据过大: \(data.count) bytes，跳过加载", category: .general)
                    return nil
                }
                guard let image = UIImage(data: data) else { return nil }
                // 优化图片大小（减少内存占用）- 限制最大尺寸为 800x800（从1200降到800，进一步减少内存占用）
                return self.optimizeImageSize(image, maxSize: CGSize(width: 800, height: 800))
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
        let fileName = url.md5Hash
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // 尝试不同的压缩质量，确保文件不超过 5MB
        var compressionQuality: CGFloat = 0.8
        var data: Data?
        
        // 最多尝试 5 次，逐步降低压缩质量
        for _ in 0..<5 {
            if let imageData = image.jpegData(compressionQuality: compressionQuality) {
                // 如果数据大小在限制内，使用这个质量
                if imageData.count <= 5 * 1024 * 1024 {
                    data = imageData
                    break
                }
                // 如果数据过大，降低压缩质量
                compressionQuality -= 0.15
            } else {
                break
            }
        }
        
        // 如果仍然无法压缩到 5MB 以内，使用最低质量（0.2）
        if data == nil || (data?.count ?? 0) > 5 * 1024 * 1024 {
            data = image.jpegData(compressionQuality: 0.2)
        }
        
        // 如果最终数据仍然过大，不保存（避免占用过多磁盘空间）
        guard let finalData = data, finalData.count <= 5 * 1024 * 1024 else {
            Logger.warning("图片压缩后仍然过大，跳过保存: \(url)", category: .general)
            return
        }
        
        try? finalData.write(to: fileURL)
    }
    
    private func loadFromDisk(url: String) -> UIImage? {
        let fileName = url.md5Hash
        let fileURL = cacheDirectory.appendingPathComponent(fileName)
        
        // 检查文件是否存在
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 检查文件大小，防止加载过大的图片
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64 else {
            // 无法读取文件属性，尝试删除并返回 nil
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        // 如果文件过大（超过5MB），删除它并返回 nil（会触发从网络重新加载并优化）
        if fileSize > 5 * 1024 * 1024 {
            Logger.warning("磁盘缓存图片过大: \(fileSize / 1024 / 1024)MB，删除并重新加载: \(fileURL.lastPathComponent)", category: .general)
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            // 读取失败，删除损坏的文件
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        // 再次检查数据大小
        if data.count > 5 * 1024 * 1024 {
            Logger.warning("磁盘缓存图片数据过大: \(data.count / 1024 / 1024)MB，删除并重新加载: \(fileURL.lastPathComponent)", category: .general)
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        guard let image = UIImage(data: data) else {
            // 图片数据损坏，删除文件
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return image
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
        var clearedCount = 0
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let modificationDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modificationDate) > maxAge {
                try? fileManager.removeItem(at: file)
                clearedCount += 1
            }
        }
        if clearedCount > 0 {
            Logger.debug("已清理 \(clearedCount) 个过期图片缓存（超过 \(Int(maxAge / 86400)) 天）", category: .cache)
        }
    }
    
    /// 清除指定任务的图片缓存（当任务完成或取消时调用）
    /// - Parameter task: 已完成或取消的任务
    func clearTaskImages(task: Task) {
        // 只清理已完成或取消的任务图片
        guard task.status == .completed || task.status == .cancelled else {
            return
        }
        
        guard let images = task.images, !images.isEmpty else {
            return
        }
        
        var clearedCount = 0
        for imageUrl in images {
            // 从内存缓存中移除
            cache.removeObject(forKey: imageUrl as NSString)
            
            // 从磁盘缓存中移除
            let fileName = imageUrl.md5Hash
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
                clearedCount += 1
            }
        }
        
        if clearedCount > 0 {
            Logger.debug("已清理任务 \(task.id) 的 \(clearedCount) 张图片缓存（任务状态: \(task.status.rawValue)）", category: .cache)
        }
    }
    
    /// 批量清除已完成或取消任务的图片缓存
    /// - Parameter tasks: 任务列表（只处理已完成或取消的任务）
    func clearCompletedOrCancelledTaskImages(tasks: [Task]) {
        let tasksToClear = tasks.filter { $0.status == .completed || $0.status == .cancelled }
        guard !tasksToClear.isEmpty else { return }
        
        var totalClearedCount = 0
        for task in tasksToClear {
            guard let images = task.images, !images.isEmpty else { continue }
            
            for imageUrl in images {
                // 从内存缓存中移除
                cache.removeObject(forKey: imageUrl as NSString)
                
                // 从磁盘缓存中移除
                let fileName = imageUrl.md5Hash
                let fileURL = cacheDirectory.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try? fileManager.removeItem(at: fileURL)
                    totalClearedCount += 1
                }
            }
        }
        
        if totalClearedCount > 0 {
            Logger.debug("已批量清理 \(tasksToClear.count) 个已完成/取消任务的 \(totalClearedCount) 张图片缓存", category: .cache)
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

