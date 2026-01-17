import Foundation

/// 缓存管理器 - 企业级缓存系统（内存 + 磁盘）
/// 提供高性能的内存缓存和持久化的磁盘缓存
public class CacheManager {
    public static let shared = CacheManager()
    
    // MARK: - 企业级缓存组件
    
    /// 内存缓存（NSCache）- 快速访问
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    /// 磁盘缓存目录
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    /// 线程安全锁
    private let lock = NSLock()
    
    // MARK: - 缓存统计
    
    /// 缓存统计信息
    public struct CacheStatistics {
        public let totalHits: Int
        public let totalMisses: Int
        public let hitRate: Double
        public let memoryCacheCount: Int
        public let diskCacheCount: Int
        public let totalCacheSize: Int64 // 字节
        public let oldestCacheDate: Date?
        public let newestCacheDate: Date?
    }
    
    // 缓存统计计数器
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    
    // 缓存过期时间（秒）- 根据数据类型设置不同过期时间
    private let defaultCacheExpirationTime: TimeInterval = 300 // 5分钟（默认）
    private let shortCacheExpirationTime: TimeInterval = 180 // 3分钟（频繁更新的数据）
    private let longCacheExpirationTime: TimeInterval = 600 // 10分钟（相对稳定的数据）
    private let personalDataCacheExpirationTime: TimeInterval = 1800 // 30分钟（用户个人数据，如支付、提现、我的任务等）
    
    // 缓存大小限制（字节）
    private let maxCacheSize: Int64 = 50 * 1024 * 1024 // 50MB
    
    // 获取特定数据类型的缓存过期时间
    private func cacheExpirationTime(forKey key: String) -> TimeInterval {
        // 用户个人数据使用更长的缓存时间（30分钟），减少频繁加载
        if key.contains("my_") || 
           key.contains("payment") || 
           key.contains("payout") || 
           key.contains("balance") ||
           key.contains("applications") ||
           key.contains("my_tasks") ||
           key.contains("my_posts") ||
           key.contains("my_forum") ||
           key.contains("my_items") {
            return personalDataCacheExpirationTime // 个人数据缓存30分钟
        } else if key.contains("tasks") || key.contains("activities") {
            return shortCacheExpirationTime // 任务和活动更新频繁
        } else if key.contains("leaderboards") || key.contains("task_experts") {
            return longCacheExpirationTime // 排行榜和达人相对稳定
        }
        return defaultCacheExpirationTime
    }
    
    private init() {
        // 配置内存缓存
        memoryCache.countLimit = 100 // 最多缓存100个对象
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB 内存限制
        
        // 配置磁盘缓存目录
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesPath.appendingPathComponent("Link2UrCache", isDirectory: true)
        
        // 创建缓存目录（如果不存在）
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - 企业级缓存方法（内存 + 磁盘）
    
    /// 企业级方法：存储到内存和磁盘（支持过期时间）
    /// - Parameters:
    ///   - object: 要缓存的对象（必须是 Codable 和 AnyObject，即 class 类型）
    ///   - key: 缓存键
    ///   - expiration: 过期时间（秒），nil 表示使用默认过期策略
    public func set<T: Codable & AnyObject>(_ object: T, forKey key: String, expiration: TimeInterval? = nil) throws {
        lock.lock()
        defer { lock.unlock() }
        
        // 存储到内存缓存
        memoryCache.setObject(object, forKey: key as NSString)
        
        // 存储到磁盘缓存
        try setDiskCache(object, forKey: key, expiration: expiration)
    }
    
    /// 企业级方法：从内存或磁盘获取（优先内存）
    /// - Parameters:
    ///   - key: 缓存键
    ///   - type: 对象类型
    /// - Returns: 缓存的对象，如果不存在或已过期则返回 nil
    public func get<T: Codable & AnyObject>(forKey key: String, as type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        // 先尝试从内存缓存获取
        if let cached = memoryCache.object(forKey: key as NSString) as? T {
            cacheHits += 1
            return cached
        }
        
        // 再尝试从磁盘缓存获取
        if let cached = getDiskCache(forKey: key, as: type) {
            // 回填到内存缓存
            memoryCache.setObject(cached, forKey: key as NSString)
            cacheHits += 1
            return cached
        }
        
        cacheMisses += 1
        return nil
    }
    
    /// 仅存储到内存缓存（用于非 Codable 对象，如 UIImage）
    public func setMemoryCache<T: AnyObject>(_ object: T, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        memoryCache.setObject(object, forKey: key as NSString)
    }
    
    /// 仅从内存缓存获取
    public func getMemoryCache<T>(forKey key: String, as type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return memoryCache.object(forKey: key as NSString) as? T
    }
    
    /// 仅存储到磁盘缓存（支持过期时间）
    public func setDiskCache<T: Codable>(_ object: T, forKey key: String, expiration: TimeInterval? = nil) throws {
        let cacheItem = DiskCacheItem(
            data: object,
            expirationDate: expiration.map { Date().addingTimeInterval($0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(cacheItem)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        // 检查缓存大小，如果超过限制则清理
        checkAndCleanCacheIfNeeded()
        
        try data.write(to: fileURL)
        
        // 保存缓存时间戳（用于兼容旧版本的时间戳检查）
        saveCacheTimestamp(forKey: key)
    }
    
    /// 仅从磁盘缓存获取（同步版本，但优化了性能）
    /// 注意：此方法在主线程调用时应该快速返回，大文件读取应该在后台线程
    public func getDiskCache<T: Decodable>(forKey key: String, as type: T.Type) -> T? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        // 快速检查文件是否存在（不阻塞）
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 检查缓存是否过期（使用旧版本的时间戳检查作为后备）
        if isCacheExpired(forKey: key) {
            Logger.warning("缓存已过期 [\(key)]，将清除", category: .cache)
            // 异步清除，不阻塞主线程
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.clearCache(forKey: key)
            }
            return nil
        }
        
        // 检查文件大小，如果文件过大，异步读取
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? Int64,
           fileSize > 1024 * 1024 { // 超过1MB的文件，不应该在主线程同步读取
            Logger.warning("缓存文件过大 [\(key)]: \(fileSize) bytes，跳过同步读取", category: .cache)
            return nil
        }
        
        do {
            // 对于小文件，同步读取是可以接受的
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // 尝试解码为企业级格式（带过期时间）
            if let cacheItem = try? decoder.decode(DiskCacheItemWrapper<T>.self, from: data) {
                // 检查是否过期
                if let expirationDate = cacheItem.expirationDate, expirationDate < Date() {
                    // 异步删除过期文件
                    DispatchQueue.global(qos: .utility).async { [weak self] in
                        try? self?.fileManager.removeItem(at: fileURL)
                    }
                    return nil
                }
                return cacheItem.data
            }
            
            // 兼容旧格式（直接解码）
            return try decoder.decode(type, from: data)
        } catch {
            Logger.error("缓存加载失败 [\(key)]: \(error.localizedDescription)", category: .cache)
            return nil
        }
    }
    
    // MARK: - 协议方法（向后兼容）
    
    /// 保存数据到缓存（协议方法，兼容旧代码）
    /// 自动使用内存+磁盘缓存，使用默认过期策略
    nonisolated public func save<T: Codable>(_ data: T, forKey key: String) {
        // 对于值类型（struct），只能存储到磁盘
        // 对于引用类型（class），可以同时存储到内存和磁盘
        // 使用 Mirror 来检查是否为类类型（引用类型）
        let isReferenceType = Mirror(reflecting: data).displayStyle == .class
        if isReferenceType {
            // 引用类型：使用企业级方法
            do {
                let expiration = cacheExpirationTime(forKey: key)
                try setDiskCache(data, forKey: key, expiration: expiration)
                // 注意：值类型无法存储到 NSCache，所以只存磁盘
            } catch {
                Logger.error("缓存保存失败 [\(key)]: \(error.localizedDescription)", category: .cache)
            }
        } else {
            // 值类型：只存储到磁盘
            do {
                let expiration = cacheExpirationTime(forKey: key)
                try setDiskCache(data, forKey: key, expiration: expiration)
            } catch {
                Logger.error("缓存保存失败 [\(key)]: \(error.localizedDescription)", category: .cache)
            }
        }
    }
    
    /// 从缓存加载数据（协议方法，兼容旧代码）
    /// 优先从内存获取（同步，快速），然后从磁盘获取（同步，但优化了性能）
    nonisolated public func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        
        // 先尝试从内存获取（同步，非常快，不会阻塞）
        if let cached = memoryCache.object(forKey: key as NSString) as? T {
            cacheHits += 1
            return cached
        }
        
        // 从磁盘获取（同步，但已优化：大文件会跳过，过期文件异步删除）
        if let cached = getDiskCache(forKey: key, as: type) {
            // 回填到内存缓存，下次就能快速获取
            // 使用 Mirror 检查是否为引用类型（class），只有引用类型才能存储到 NSCache
            let isReferenceType = Mirror(reflecting: cached).displayStyle == .class
            if isReferenceType {
                // 对于引用类型，直接转换为 AnyObject（不需要条件转换，因为已经确认是引用类型）
                let object = cached as AnyObject
                memoryCache.setObject(object, forKey: key as NSString)
            }
            cacheHits += 1
            return cached
        }
        
        cacheMisses += 1
        return nil
    }
    
    /// 清除指定缓存（内存 + 磁盘）
    func clearCache(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        
        // 清除内存缓存
        memoryCache.removeObject(forKey: key as NSString)
        
        // 清除磁盘缓存
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        let timestampURL = cacheDirectory.appendingPathComponent("\(key)_timestamp.txt")
        
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: timestampURL)
    }
    
    /// 清除所有缓存（内存 + 磁盘）
    func clearAllCache() {
        lock.lock()
        defer { lock.unlock() }
        
        // 清除内存缓存
        memoryCache.removeAllObjects()
        
        // 清除磁盘缓存
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? fileManager.removeItem(at: file)
            }
            Logger.success("所有缓存已清除", category: .cache)
        } catch {
            Logger.error("清除缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    // MARK: - 协议适配方法（CacheManagerProtocol）
    
    /// 协议适配：remove(forKey:) -> clearCache(forKey:)
    public func remove(forKey key: String) {
        clearCache(forKey: key)
    }
    
    /// 协议适配：clearAll() -> clearAllCache()
    public func clearAll() {
        clearAllCache()
    }
    
    /// 检查并清理缓存（如果超过大小限制）
    private func checkAndCleanCacheIfNeeded() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            
            // 计算总缓存大小
            var totalSize: Int64 = 0
            var fileInfos: [(url: URL, size: Int64, date: Date)] = []
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                if let size = resourceValues.fileSize,
                   let date = resourceValues.contentModificationDate {
                    totalSize += Int64(size)
                    fileInfos.append((url: file, size: Int64(size), date: date))
                }
            }
            
            // 如果超过限制，删除最旧的文件
            if totalSize > maxCacheSize {
                // 按修改时间排序，最旧的在前
                fileInfos.sort { $0.date < $1.date }
                
                var removedSize: Int64 = 0
                for fileInfo in fileInfos {
                    if totalSize - removedSize <= maxCacheSize * 8 / 10 { // 清理到80%以下
                        break
                    }
                    try? fileManager.removeItem(at: fileInfo.url)
                    removedSize += fileInfo.size
                    totalSize -= fileInfo.size
                }
                
                print("🧹 缓存清理完成，释放了 \(removedSize / 1024 / 1024)MB 空间")
            }
        } catch {
            print("⚠️ 检查缓存大小失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取当前缓存大小（字节）
    func getCacheSize() -> Int64 {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            var totalSize: Int64 = 0
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
            return totalSize
        } catch {
            return 0
        }
    }
    
    // MARK: - 缓存失效策略
    
    /// 清除任务相关缓存（不包括推荐任务缓存）
    func invalidateTasksCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var clearedCount = 0
            for file in files {
                let fileName = file.lastPathComponent
                // 只清除普通任务缓存，保留推荐任务缓存
                // 推荐任务缓存键是 "recommended_tasks"，普通任务缓存键是 "tasks"
                if fileName.contains("tasks") && !fileName.contains("recommended_tasks") {
                    try? fileManager.removeItem(at: file)
                    clearedCount += 1
                }
            }
            Logger.success("已清除 \(clearedCount) 个普通任务缓存文件（保留推荐任务缓存）", category: .cache)
        } catch {
            Logger.error("清除任务缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除推荐任务缓存
    func invalidateRecommendedTasksCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var clearedCount = 0
            for file in files {
                let fileName = file.lastPathComponent
                // 只清除推荐任务缓存
                if fileName.contains("recommended_tasks") {
                    try? fileManager.removeItem(at: file)
                    clearedCount += 1
                }
            }
            Logger.success("已清除 \(clearedCount) 个推荐任务缓存文件", category: .cache)
        } catch {
            Logger.error("清除推荐任务缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除所有任务缓存（包括推荐任务和普通任务）
    func invalidateAllTasksCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var clearedCount = 0
            for file in files {
                if file.lastPathComponent.contains("tasks") {
                    try? fileManager.removeItem(at: file)
                    clearedCount += 1
                }
            }
            Logger.success("已清除 \(clearedCount) 个任务缓存文件（包括推荐任务和普通任务）", category: .cache)
        } catch {
            Logger.error("清除所有任务缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除活动相关缓存
    func invalidateActivitiesCache() {
        clearCache(forKey: "activities")
        print("✅ 活动缓存已清除")
    }
    
    /// 清除论坛帖子相关缓存
    func invalidateForumPostsCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.contains("forum_posts") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("论坛帖子缓存已清除", category: .cache)
        } catch {
            print("⚠️ 清除论坛帖子缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除跳蚤市场相关缓存
    func invalidateFleaMarketCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.contains("flea_market") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("跳蚤市场缓存已清除", category: .cache)
        } catch {
            print("⚠️ 清除跳蚤市场缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除任务达人相关缓存
    func invalidateTaskExpertsCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.contains("task_experts") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("任务达人缓存已清除", category: .cache)
        } catch {
            print("⚠️ 清除任务达人缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除排行榜相关缓存
    func invalidateLeaderboardsCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                if file.lastPathComponent.contains("leaderboards") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("排行榜缓存已清除", category: .cache)
        } catch {
            print("⚠️ 清除排行榜缓存失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 个人数据缓存失效
    
    /// 清除用户个人数据缓存（支付、提现、任务、商品等）
    func invalidatePersonalDataCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            var clearedCount = 0
            for file in files {
                let fileName = file.lastPathComponent
                // 清除所有个人数据相关的缓存
                if fileName.contains("my_") ||
                   fileName.contains("payment") ||
                   fileName.contains("payout") ||
                   fileName.contains("balance") ||
                   fileName.contains("applications") ||
                   fileName.contains("notifications") {
                    try? fileManager.removeItem(at: file)
                    clearedCount += 1
                }
            }
            Logger.success("已清除 \(clearedCount) 个个人数据缓存文件", category: .cache)
        } catch {
            Logger.error("清除个人数据缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除我的任务相关缓存
    func invalidateMyTasksCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let fileName = file.lastPathComponent
                if fileName.contains("my_tasks") || fileName.contains("my_applications") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("我的任务缓存已清除", category: .cache)
        } catch {
            Logger.error("清除我的任务缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除我的商品相关缓存
    func invalidateMyItemsCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let fileName = file.lastPathComponent
                if fileName.contains("my_items") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("我的商品缓存已清除", category: .cache)
        } catch {
            Logger.error("清除我的商品缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除支付和提现相关缓存
    func invalidatePaymentCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let fileName = file.lastPathComponent
                if fileName.contains("payment") || fileName.contains("payout") || fileName.contains("balance") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("支付和提现缓存已清除", category: .cache)
        } catch {
            Logger.error("清除支付缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除通知相关缓存
    func invalidateNotificationsCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                let fileName = file.lastPathComponent
                if fileName.contains("notifications") {
                    try? fileManager.removeItem(at: file)
                }
            }
            Logger.success("通知缓存已清除", category: .cache)
        } catch {
            Logger.error("清除通知缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    /// 清除所有过期缓存
    func clearExpiredCache() {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            var clearedCount = 0
            for file in files {
                // 只检查 JSON 文件，跳过时间戳文件
                if file.lastPathComponent.hasSuffix(".json") {
                    let key = String(file.lastPathComponent.dropLast(5)) // 移除 .json 后缀
                    if isCacheExpired(forKey: key) {
                        try? fileManager.removeItem(at: file)
                        // 同时删除对应的时间戳文件
                        let timestampURL = cacheDirectory.appendingPathComponent("\(key)_timestamp.txt")
                        try? fileManager.removeItem(at: timestampURL)
                        clearedCount += 1
                    }
                }
            }
            if clearedCount > 0 {
                print("🧹 已清除 \(clearedCount) 个过期缓存文件")
            }
        } catch {
            print("⚠️ 清除过期缓存失败: \(error.localizedDescription)")
        }
    }
    
    /// 获取缓存统计信息（旧方法，保持兼容）
    func getCacheStats() -> (fileCount: Int, totalSize: Int64, oldestDate: Date?, newestDate: Date?) {
        let stats = getStatistics()
        return (
            fileCount: stats.diskCacheCount,
            totalSize: stats.totalCacheSize,
            oldestDate: stats.oldestCacheDate,
            newestDate: stats.newestCacheDate
        )
    }
    
    /// 获取完整的缓存统计信息
    public func getStatistics() -> CacheStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) : 0.0
        
        // 获取磁盘缓存信息
        var diskCacheCount = 0
        var totalSize: Int64 = 0
        var dates: [Date] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey])
            
            for file in files {
                // 只统计 JSON 文件
                if file.lastPathComponent.hasSuffix(".json") {
                    diskCacheCount += 1
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(size)
                    }
                    if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                        dates.append(date)
                    }
                }
            }
        } catch {
            // 忽略错误
        }
        
        // 内存缓存数量（NSCache 不提供直接计数，这里估算）
        let memoryCacheCount = memoryCache.countLimit // 这是限制，不是实际数量
        
        return CacheStatistics(
            totalHits: cacheHits,
            totalMisses: cacheMisses,
            hitRate: hitRate,
            memoryCacheCount: memoryCacheCount,
            diskCacheCount: diskCacheCount,
            totalCacheSize: totalSize,
            oldestCacheDate: dates.min(),
            newestCacheDate: dates.max()
        )
    }
    
    /// 重置缓存统计
    public func resetStatistics() {
        lock.lock()
        defer { lock.unlock() }
        cacheHits = 0
        cacheMisses = 0
    }
    
    // MARK: - 缓存时间戳管理
    
    private func saveCacheTimestamp(forKey key: String) {
        let timestampURL = cacheDirectory.appendingPathComponent("\(key)_timestamp.txt")
        let timestamp = String(Date().timeIntervalSince1970)
        try? timestamp.write(to: timestampURL, atomically: true, encoding: .utf8)
    }
    
    private func getCacheTimestamp(forKey key: String) -> Date? {
        let timestampURL = cacheDirectory.appendingPathComponent("\(key)_timestamp.txt")
        guard let timestampString = try? String(contentsOf: timestampURL, encoding: .utf8),
              let timestamp = Double(timestampString) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    private func isCacheExpired(forKey key: String) -> Bool {
        guard let timestamp = getCacheTimestamp(forKey: key) else {
            return true
        }
        let expirationTime = cacheExpirationTime(forKey: key)
        return Date().timeIntervalSince(timestamp) > expirationTime
    }
    
    // MARK: - 特定数据类型的缓存方法
    
    /// 保存任务列表
    func saveTasks(_ tasks: [Task], category: String? = nil, city: String? = nil, isRecommended: Bool = false) {
        let key = cacheKeyForTasks(category: category, city: city, isRecommended: isRecommended)
        save(tasks, forKey: key)
    }
    
    /// 加载任务列表
    func loadTasks(category: String? = nil, city: String? = nil, isRecommended: Bool = false) -> [Task]? {
        let key = cacheKeyForTasks(category: category, city: city, isRecommended: isRecommended)
        return load([Task].self, forKey: key)
    }
    
    /// 保存活动列表
    func saveActivities(_ activities: [Activity]) {
        save(activities, forKey: "activities")
    }
    
    /// 加载活动列表
    func loadActivities() -> [Activity]? {
        return load([Activity].self, forKey: "activities")
    }
    
    /// 保存论坛帖子列表
    func saveForumPosts(_ posts: [ForumPost], categoryId: Int? = nil) {
        let key = cacheKeyForForumPosts(categoryId: categoryId)
        save(posts, forKey: key)
    }
    
    /// 加载论坛帖子列表
    func loadForumPosts(categoryId: Int? = nil) -> [ForumPost]? {
        let key = cacheKeyForForumPosts(categoryId: categoryId)
        return load([ForumPost].self, forKey: key)
    }
    
    /// 保存跳蚤市场商品列表
    func saveFleaMarketItems(_ items: [FleaMarketItem], category: String? = nil) {
        let key = cacheKeyForFleaMarketItems(category: category)
        save(items, forKey: key)
    }
    
    /// 加载跳蚤市场商品列表
    func loadFleaMarketItems(category: String? = nil) -> [FleaMarketItem]? {
        let key = cacheKeyForFleaMarketItems(category: category)
        return load([FleaMarketItem].self, forKey: key)
    }
    
    /// 保存任务达人列表
    func saveTaskExperts(_ experts: [TaskExpert], category: String? = nil, location: String? = nil) {
        let key = cacheKeyForTaskExperts(category: category, location: location)
        save(experts, forKey: key)
    }
    
    /// 加载任务达人列表
    func loadTaskExperts(category: String? = nil, location: String? = nil) -> [TaskExpert]? {
        let key = cacheKeyForTaskExperts(category: category, location: location)
        return load([TaskExpert].self, forKey: key)
    }
    
    /// 保存排行榜列表
    func saveLeaderboards(_ leaderboards: [CustomLeaderboard], location: String? = nil, sort: String? = nil) {
        let key = cacheKeyForLeaderboards(location: location, sort: sort)
        save(leaderboards, forKey: key)
    }
    
    /// 加载排行榜列表
    func loadLeaderboards(location: String? = nil, sort: String? = nil) -> [CustomLeaderboard]? {
        let key = cacheKeyForLeaderboards(location: location, sort: sort)
        return load([CustomLeaderboard].self, forKey: key)
    }
    
    /// 保存 Banner 列表
    func saveBanners(_ banners: [Banner]) {
        save(banners, forKey: "banners")
    }
    
    /// 加载 Banner 列表
    func loadBanners() -> [Banner]? {
        return load([Banner].self, forKey: "banners")
    }
    
    // MARK: - 缓存键生成
    
    private func cacheKeyForTasks(category: String?, city: String?, isRecommended: Bool = false) -> String {
        var key = isRecommended ? "recommended_tasks" : "tasks"
        if let category = category {
            key += "_cat_\(category)"
        }
        if let city = city {
            key += "_city_\(city)"
        }
        return key
    }
    
    private func cacheKeyForForumPosts(categoryId: Int?) -> String {
        if let categoryId = categoryId {
            return "forum_posts_cat_\(categoryId)"
        }
        return "forum_posts_all"
    }
    
    private func cacheKeyForFleaMarketItems(category: String?) -> String {
        if let category = category {
            return "flea_market_items_cat_\(category)"
        }
        return "flea_market_items_all"
    }
    
    private func cacheKeyForTaskExperts(category: String?, location: String?) -> String {
        var key = "task_experts"
        if let category = category {
            key += "_cat_\(category)"
        }
        if let location = location {
            key += "_loc_\(location)"
        }
        return key
    }
    
    private func cacheKeyForLeaderboards(location: String?, sort: String?) -> String {
        var key = "leaderboards"
        if let location = location {
            key += "_loc_\(location)"
        }
        if let sort = sort {
            key += "_sort_\(sort)"
        }
        return key
    }
}

// MARK: - 企业级缓存数据结构

/// 磁盘缓存项（用于存储过期时间）
/// 注意：使用泛型包装器以支持只符合 Decodable 的类型
private struct DiskCacheItemWrapper<T: Decodable>: Decodable {
    let data: T
    let expirationDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case data
        case expirationDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(T.self, forKey: .data)
        expirationDate = try container.decodeIfPresent(Date.self, forKey: .expirationDate)
    }
}

/// 磁盘缓存项（用于编码，需要 Codable）
private struct DiskCacheItem<T: Codable>: Codable {
    let data: T
    let expirationDate: Date?
}
