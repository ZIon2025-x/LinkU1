import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 缓存使用示例
class CacheExample {
    
    /// 示例1: 基本缓存操作
    func basicCache() {
        let user = User(id: "1", name: "示例用户")
        
        // 存储（使用 save 方法，支持 struct 类型）
        CacheManager.shared.save(
            user,
            forKey: "user_1"
        )
        
        // 获取（先内存，后磁盘）
        if let cachedUser = CacheManager.shared.load(
            User.self,
            forKey: "user_1"
        ) {
            print("从缓存获取: \(cachedUser.name)")
        }
    }
    
    /// 示例2: 仅内存缓存
    func memoryOnlyCache() {
        #if canImport(UIKit)
        let image = UIImage()
        
        // 仅存储到内存
        CacheManager.shared.setMemoryCache(image, forKey: "avatar_1")
        
        // 从内存获取
        if CacheManager.shared.getMemoryCache(
            forKey: "avatar_1",
            as: UIImage.self
        ) != nil {
            print("从内存缓存获取图片")
        }
        #endif
    }
    
    /// 示例3: 仅磁盘缓存
    func diskOnlyCache() {
        let data = Data()
        
        // 仅存储到磁盘
        do {
            try CacheManager.shared.setDiskCache(
                data,
                forKey: "large_file",
                expiration: 86400 // 24小时
            )
        } catch {
            Logger.error("磁盘缓存失败: \(error)", category: .general)
        }
        
        // 从磁盘获取
        if CacheManager.shared.getDiskCache(
            forKey: "large_file",
            as: Data.self
        ) != nil {
            print("从磁盘缓存获取数据")
        }
    }
    
    /// 示例4: 使用 ExpiringValue
    func expiringValueExample() {
        struct TokenCache {
            @ExpiringValue(ttl: 3600) var token: String?
        }
        
        var cache = TokenCache()
        cache.token = "access_token_123"
        
        // 检查 token 是否存在
        if let token = cache.token {
            print("Token 有效: \(token)")
        }
        
        // 刷新过期时间（通过重新设置值来刷新）
        if cache.token != nil {
            let currentToken = cache.token
            cache.token = currentToken
        }
    }
    
    /// 示例5: 清理缓存
    func clearCache() {
        // 清除指定键
        CacheManager.shared.remove(forKey: "user_1")
        
        // 清除过期缓存
        CacheManager.shared.clearExpiredCache()
        
        // 清除所有缓存
        CacheManager.shared.clearAll()
    }
}

