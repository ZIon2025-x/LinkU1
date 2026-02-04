import Foundation
import Combine

// MARK: - 缓存策略

/// 缓存策略
public enum APICachePolicy {
    /// 不使用缓存，始终请求网络
    case networkOnly
    /// 优先使用缓存，缓存过期或不存在时请求网络
    case cacheFirst
    /// 优先请求网络，失败时使用缓存
    case networkFirst
    /// 同时返回缓存和网络数据（先返回缓存，网络返回后更新）
    case cacheAndNetwork
    /// 仅使用缓存，不请求网络
    case cacheOnly
}

/// 缓存条目
public struct APICacheEntry<T: Codable>: Codable {
    public let data: T
    public let timestamp: Date
    public let expiresAt: Date
    public let etag: String?
    public let endpoint: String
    
    public var isExpired: Bool {
        return Date() > expiresAt
    }
    
    public var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
}

// MARK: - 缓存配置

/// 缓存配置
public struct APICacheConfiguration {
    /// 默认过期时间（秒）
    public let defaultTTL: TimeInterval
    /// 最大缓存条目数
    public let maxEntries: Int
    /// 最大缓存大小（字节）
    public let maxSize: Int64
    /// 是否在后台自动清理
    public let autoCleanup: Bool
    
    public static let `default` = APICacheConfiguration(
        defaultTTL: 300, // 5分钟
        maxEntries: 500,
        maxSize: 50 * 1024 * 1024, // 50MB
        autoCleanup: true
    )
    
    public static let aggressive = APICacheConfiguration(
        defaultTTL: 600, // 10分钟
        maxEntries: 1000,
        maxSize: 100 * 1024 * 1024, // 100MB
        autoCleanup: true
    )
    
    public static let minimal = APICacheConfiguration(
        defaultTTL: 60, // 1分钟
        maxEntries: 100,
        maxSize: 10 * 1024 * 1024, // 10MB
        autoCleanup: true
    )
}

/// 端点缓存规则
public struct EndpointCacheRule {
    public let pattern: String // 端点匹配模式（支持通配符 *）
    public let ttl: TimeInterval
    public let policy: APICachePolicy
    
    public init(pattern: String, ttl: TimeInterval, policy: APICachePolicy = .cacheFirst) {
        self.pattern = pattern
        self.ttl = ttl
        self.policy = policy
    }
    
    public func matches(_ endpoint: String) -> Bool {
        if pattern.contains("*") {
            let regex = pattern.replacingOccurrences(of: "*", with: ".*")
            return endpoint.range(of: regex, options: .regularExpression) != nil
        }
        return endpoint == pattern
    }
}

// MARK: - API 缓存管理器

/// API 响应缓存管理器
public final class APICache {
    public static let shared = APICache()
    
    // MARK: - Properties
    
    private let cache = NSCache<NSString, AnyObject>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private var memoryCache: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.link2ur.apicache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    /// 配置
    public var configuration: APICacheConfiguration {
        didSet {
            cache.countLimit = configuration.maxEntries
        }
    }
    
    /// 端点缓存规则
    public var endpointRules: [EndpointCacheRule] = []
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        // 初始化缓存目录
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("APICache", isDirectory: true)
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 默认配置
        configuration = .default
        cache.countLimit = configuration.maxEntries
        
        // 设置默认缓存规则
        setupDefaultRules()
        
        // 设置内存警告监听
        setupMemoryWarningObserver()
        
        // 自动清理
        if configuration.autoCleanup {
            scheduleCleanup()
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取缓存
    public func get<T: Codable>(_ type: T.Type, for endpoint: String, queryParams: [String: String]? = nil) -> T? {
        guard isEnabled else { return nil }
        
        let cacheKey = generateCacheKey(endpoint: endpoint, queryParams: queryParams)
        
        // 先检查内存缓存
        if let entry = memoryCache[cacheKey] as? APICacheEntry<T>, !entry.isExpired {
            Logger.debug("API 缓存命中（内存）: \(endpoint)", category: .cache)
            return entry.data
        }
        
        // 检查磁盘缓存
        if let entry: APICacheEntry<T> = loadFromDisk(key: cacheKey), !entry.isExpired {
            // 加载到内存缓存
            memoryCache[cacheKey] = entry
            Logger.debug("API 缓存命中（磁盘）: \(endpoint)", category: .cache)
            return entry.data
        }
        
        Logger.debug("API 缓存未命中: \(endpoint)", category: .cache)
        return nil
    }
    
    /// 设置缓存
    public func set<T: Codable>(_ data: T, for endpoint: String, queryParams: [String: String]? = nil, ttl: TimeInterval? = nil, etag: String? = nil) {
        guard isEnabled else { return }
        
        let cacheKey = generateCacheKey(endpoint: endpoint, queryParams: queryParams)
        let effectiveTTL = ttl ?? getTTL(for: endpoint)
        
        let entry = APICacheEntry(
            data: data,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(effectiveTTL),
            etag: etag,
            endpoint: endpoint
        )
        
        // 保存到内存缓存
        memoryCache[cacheKey] = entry
        
        // 异步保存到磁盘
        queue.async { [weak self] in
            self?.saveToDisk(entry, key: cacheKey)
        }
        
        Logger.debug("API 缓存已设置: \(endpoint), TTL: \(effectiveTTL)s", category: .cache)
    }
    
    /// 删除缓存
    public func remove(for endpoint: String, queryParams: [String: String]? = nil) {
        let cacheKey = generateCacheKey(endpoint: endpoint, queryParams: queryParams)
        
        memoryCache.removeValue(forKey: cacheKey)
        
        queue.async { [weak self] in
            self?.removeFromDisk(key: cacheKey)
        }
        
        Logger.debug("API 缓存已删除: \(endpoint)", category: .cache)
    }
    
    /// 删除匹配模式的所有缓存
    public func removeMatching(pattern: String) {
        let keysToRemove = memoryCache.keys.filter { key in
            if pattern.contains("*") {
                let regex = pattern.replacingOccurrences(of: "*", with: ".*")
                return key.range(of: regex, options: .regularExpression) != nil
            }
            return key.contains(pattern)
        }
        
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
        
        queue.async { [weak self] in
            for key in keysToRemove {
                self?.removeFromDisk(key: key)
            }
        }
        
        Logger.debug("删除匹配缓存: \(pattern), 数量: \(keysToRemove.count)", category: .cache)
    }
    
    /// 清除所有缓存
    public func clearAll() {
        memoryCache.removeAll()
        
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        }
        
        Logger.info("API 缓存已全部清除", category: .cache)
    }
    
    /// 清除过期缓存
    public func clearExpired() {
        queue.async { [weak self] in
            self?.performCleanup()
        }
    }
    
    /// 获取端点的缓存策略
    public func getCachePolicy(for endpoint: String) -> APICachePolicy {
        for rule in endpointRules {
            if rule.matches(endpoint) {
                return rule.policy
            }
        }
        return .cacheFirst
    }
    
    /// 获取端点的 TTL
    public func getTTL(for endpoint: String) -> TimeInterval {
        for rule in endpointRules {
            if rule.matches(endpoint) {
                return rule.ttl
            }
        }
        return configuration.defaultTTL
    }
    
    /// 获取缓存统计信息
    public func getStatistics() -> [String: Any] {
        return [
            "memory_entries": memoryCache.count,
            "is_enabled": isEnabled,
            "configuration": [
                "default_ttl": configuration.defaultTTL,
                "max_entries": configuration.maxEntries,
                "max_size": configuration.maxSize
            ]
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultRules() {
        endpointRules = [
            // 任务列表 - 5分钟缓存
            EndpointCacheRule(pattern: "/api/tasks", ttl: 300, policy: .cacheFirst),
            EndpointCacheRule(pattern: "/api/tasks?*", ttl: 300, policy: .cacheFirst),
            
            // 任务详情 - 3分钟缓存
            EndpointCacheRule(pattern: "/api/tasks/*", ttl: 180, policy: .cacheFirst),
            
            // 用户信息 - 10分钟缓存
            EndpointCacheRule(pattern: "/api/users/profile/*", ttl: 600, policy: .cacheFirst),
            EndpointCacheRule(pattern: "/api/users/profile/me", ttl: 600, policy: .cacheFirst),
            
            // Banner - 1小时缓存
            EndpointCacheRule(pattern: "/api/banners", ttl: 3600, policy: .cacheFirst),
            
            // 论坛分类 - 1小时缓存
            EndpointCacheRule(pattern: "/api/forum/forums/*", ttl: 3600, policy: .cacheFirst),
            
            // FAQ - 24小时缓存
            EndpointCacheRule(pattern: "/api/faq*", ttl: 86400, policy: .cacheFirst),
            
            // 法律文档 - 24小时缓存
            EndpointCacheRule(pattern: "/api/legal/*", ttl: 86400, policy: .cacheFirst),
            
            // 排行榜 - 10分钟缓存
            EndpointCacheRule(pattern: "/api/custom-leaderboards*", ttl: 600, policy: .cacheFirst),
            
            // 活动列表 - 15分钟缓存
            EndpointCacheRule(pattern: "/api/activities*", ttl: 900, policy: .cacheFirst),
        ]
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: .memoryCleanupRequired)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        // 清除内存缓存，保留磁盘缓存
        memoryCache.removeAll()
        Logger.debug("内存警告，已清除 API 内存缓存", category: .cache)
    }
    
    private func generateCacheKey(endpoint: String, queryParams: [String: String]?) -> String {
        var key = endpoint
        
        if let params = queryParams, !params.isEmpty {
            let sortedParams = params.sorted { $0.key < $1.key }
            let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            key += "?\(paramString)"
        }
        
        return key
    }
    
    private func saveToDisk<T: Codable>(_ entry: APICacheEntry<T>, key: String) {
        let fileURL = cacheFileURL(for: key)
        
        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.error("保存 API 缓存失败: \(error.localizedDescription)", category: .cache)
        }
    }
    
    private func loadFromDisk<T: Codable>(key: String) -> APICacheEntry<T>? {
        let fileURL = cacheFileURL(for: key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let entry = try? JSONDecoder().decode(APICacheEntry<T>.self, from: data) else {
            return nil
        }
        
        return entry
    }
    
    private func removeFromDisk(key: String) {
        let fileURL = cacheFileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func cacheFileURL(for key: String) -> URL {
        let filename = key.data(using: .utf8)?.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            ?? UUID().uuidString
        return cacheDirectory.appendingPathComponent("\(filename).cache")
    }
    
    private func scheduleCleanup() {
        // 每小时清理一次过期缓存
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.clearExpired()
        }
    }
    
    private func performCleanup() {
        var removedCount = 0
        
        // 清除过期的内存缓存
        let expiredKeys = memoryCache.compactMap { key, value -> String? in
            if let entry = value as? APICacheEntry<Data>, entry.isExpired {
                return key
            }
            return nil
        }
        
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
            removedCount += 1
        }
        
        // 清除过期的磁盘缓存
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.creationDateKey]) {
            for file in files {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   Date().timeIntervalSince(creationDate) > configuration.defaultTTL * 2 {
                    try? fileManager.removeItem(at: file)
                    removedCount += 1
                }
            }
        }
        
        if removedCount > 0 {
            Logger.debug("API 缓存清理完成，删除 \(removedCount) 个条目", category: .cache)
        }
    }
}

// MARK: - APIService 缓存扩展

extension APIService {
    /// 带缓存的请求（Combine 版本）
    public func requestWithCache<T: Codable>(
        _ type: T.Type,
        _ endpoint: String,
        method: String = "GET",
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        cachePolicy: APICachePolicy = .cacheFirst
    ) -> AnyPublisher<T, APIError> {
        let cache = APICache.shared
        
        switch cachePolicy {
        case .networkOnly:
            return request(type, endpoint, method: method, body: body, headers: headers)
            
        case .cacheOnly:
            if let cached: T = cache.get(type, for: endpoint, queryParams: queryParams) {
                return Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
            return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
            
        case .cacheFirst:
            // 先检查缓存
            if let cached: T = cache.get(type, for: endpoint, queryParams: queryParams) {
                return Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
            
            // 缓存不存在，请求网络
            return request(type, endpoint, method: method, body: body, headers: headers)
                .handleEvents(receiveOutput: { data in
                    cache.set(data, for: endpoint, queryParams: queryParams)
                })
                .eraseToAnyPublisher()
            
        case .networkFirst:
            return request(type, endpoint, method: method, body: body, headers: headers)
                .handleEvents(receiveOutput: { data in
                    cache.set(data, for: endpoint, queryParams: queryParams)
                })
                .catch { error -> AnyPublisher<T, APIError> in
                    // 网络失败，尝试使用缓存
                    if let cached: T = cache.get(type, for: endpoint, queryParams: queryParams) {
                        Logger.debug("网络请求失败，使用缓存: \(endpoint)", category: .cache)
                        return Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .eraseToAnyPublisher()
            
        case .cacheAndNetwork:
            // 先返回缓存（如果有），然后请求网络
            let cachedPublisher: AnyPublisher<T, APIError>
            if let cached: T = cache.get(type, for: endpoint, queryParams: queryParams) {
                cachedPublisher = Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
            } else {
                cachedPublisher = Empty().eraseToAnyPublisher()
            }
            
            let networkPublisher = request(type, endpoint, method: method, body: body, headers: headers)
                .handleEvents(receiveOutput: { data in
                    cache.set(data, for: endpoint, queryParams: queryParams)
                })
                .eraseToAnyPublisher()
            
            return cachedPublisher.merge(with: networkPublisher).eraseToAnyPublisher()
        }
    }
    
    /// 带缓存的请求（async/await 版本）
    public func requestWithCache<T: Codable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        cachePolicy: APICachePolicy = .cacheFirst
    ) async throws -> T {
        let cache = APICache.shared
        
        switch cachePolicy {
        case .networkOnly:
            let result: T = try await request(endpoint, method: method, queryParams: queryParams, body: body, headers: headers)
            cache.set(result, for: endpoint, queryParams: queryParams)
            return result
            
        case .cacheOnly:
            if let cached: T = cache.get(T.self, for: endpoint, queryParams: queryParams) {
                return cached
            }
            throw APIError.invalidResponse
            
        case .cacheFirst:
            if let cached: T = cache.get(T.self, for: endpoint, queryParams: queryParams) {
                return cached
            }
            
            let result: T = try await request(endpoint, method: method, queryParams: queryParams, body: body, headers: headers)
            cache.set(result, for: endpoint, queryParams: queryParams)
            return result
            
        case .networkFirst:
            do {
                let result: T = try await request(endpoint, method: method, queryParams: queryParams, body: body, headers: headers)
                cache.set(result, for: endpoint, queryParams: queryParams)
                return result
            } catch {
                if let cached: T = cache.get(T.self, for: endpoint, queryParams: queryParams) {
                    Logger.debug("网络请求失败，使用缓存: \(endpoint)", category: .cache)
                    return cached
                }
                throw error
            }
            
        case .cacheAndNetwork:
            // async 版本只能返回一个值，使用 networkFirst 策略
            return try await requestWithCache(endpoint, method: method, queryParams: queryParams, body: body, headers: headers, cachePolicy: .networkFirst)
        }
    }
    
    /// 使缓存失效
    public func invalidateCache(for endpoint: String, queryParams: [String: String]? = nil) {
        APICache.shared.remove(for: endpoint, queryParams: queryParams)
    }
    
    /// 使匹配模式的缓存失效
    public func invalidateCacheMatching(pattern: String) {
        APICache.shared.removeMatching(pattern: pattern)
    }
}
