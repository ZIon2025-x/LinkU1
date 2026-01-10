import Foundation

/// 翻译缓存管理器 - 管理翻译结果的本地缓存
class TranslationCacheManager {
    static let shared = TranslationCacheManager()
    
    private let cacheKeyPrefix = "translation_cache_"
    private let maxCacheSize = 1000 // 最大缓存条目数
    private let cacheExpirationDays = 30 // 缓存过期天数
    
    private init() {}
    
    /// 生成缓存键
    private func cacheKey(text: String, targetLanguage: String, sourceLanguage: String?) -> String {
        let source = sourceLanguage ?? "auto"
        let key = "\(text)_\(source)_\(targetLanguage)"
        return "\(cacheKeyPrefix)\(key.hash)"
    }
    
    /// 获取缓存的翻译
    func getCachedTranslation(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?
    ) -> String? {
        let key = cacheKey(text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage)
        
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        guard let cacheEntry = try? JSONDecoder().decode(TranslationCacheEntry.self, from: data) else {
            return nil
        }
        
        // 检查是否过期
        if cacheEntry.isExpired(expirationDays: cacheExpirationDays) {
            UserDefaults.standard.removeObject(forKey: key)
            return nil
        }
        
        return cacheEntry.translatedText
    }
    
    /// 保存翻译到缓存
    func saveTranslation(
        text: String,
        translatedText: String,
        targetLanguage: String,
        sourceLanguage: String?
    ) {
        let key = cacheKey(text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage)
        
        let cacheEntry = TranslationCacheEntry(
            originalText: text,
            translatedText: translatedText,
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
            cachedAt: Date()
        )
        
        guard let data = try? JSONEncoder().encode(cacheEntry) else {
            return
        }
        
        UserDefaults.standard.set(data, forKey: key)
        
        // 清理过期缓存（异步执行，避免阻塞）
        DispatchQueue.global(qos: .utility).async {
            self.cleanExpiredCache()
        }
    }
    
    /// 批量获取缓存的翻译
    func getCachedTranslations(
        texts: [String],
        targetLanguage: String,
        sourceLanguage: String?
    ) -> [String: String] {
        var results: [String: String] = [:]
        
        for text in texts {
            if let translated = getCachedTranslation(
                text: text,
                targetLanguage: targetLanguage,
                sourceLanguage: sourceLanguage
            ) {
                results[text] = translated
            }
        }
        
        return results
    }
    
    /// 批量保存翻译到缓存
    func saveTranslations(
        translations: [String: String],
        targetLanguage: String,
        sourceLanguage: String?
    ) {
        for (original, translated) in translations {
            saveTranslation(
                text: original,
                translatedText: translated,
                targetLanguage: targetLanguage,
                sourceLanguage: sourceLanguage
            )
        }
    }
    
    /// 清理过期缓存
    private func cleanExpiredCache() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(cacheKeyPrefix) }
        
        var expiredCount = 0
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let cacheEntry = try? JSONDecoder().decode(TranslationCacheEntry.self, from: data),
               cacheEntry.isExpired(expirationDays: cacheExpirationDays) {
                UserDefaults.standard.removeObject(forKey: key)
                expiredCount += 1
            }
        }
        
        if expiredCount > 0 {
            Logger.debug("清理了 \(expiredCount) 个过期翻译缓存", category: .cache)
        }
        
        // 如果缓存条目过多，清理最旧的
        if keys.count > maxCacheSize {
            cleanupOldestCache(keepCount: maxCacheSize)
        }
    }
    
    /// 清理最旧的缓存
    private func cleanupOldestCache(keepCount: Int) {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(cacheKeyPrefix) }
        
        var entries: [(key: String, date: Date)] = []
        
        for key in keys {
            if let data = UserDefaults.standard.data(forKey: key),
               let cacheEntry = try? JSONDecoder().decode(TranslationCacheEntry.self, from: data) {
                entries.append((key: key, date: cacheEntry.cachedAt))
            }
        }
        
        // 按日期排序，保留最新的
        entries.sort { $0.date > $1.date }
        
        // 删除最旧的
        let toRemove = entries.suffix(max(0, entries.count - keepCount))
        for entry in toRemove {
            UserDefaults.standard.removeObject(forKey: entry.key)
        }
        
        Logger.debug("清理了 \(toRemove.count) 个旧翻译缓存，保留 \(keepCount) 个", category: .cache)
    }
    
    /// 清除所有缓存
    func clearAllCache() {
        let keys = UserDefaults.standard.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(cacheKeyPrefix) }
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        Logger.debug("清除了所有翻译缓存", category: .cache)
    }
}

/// 翻译缓存条目
private struct TranslationCacheEntry: Codable {
    let originalText: String
    let translatedText: String
    let targetLanguage: String
    let sourceLanguage: String?
    let cachedAt: Date
    
    /// 检查是否过期
    func isExpired(expirationDays: Int) -> Bool {
        let expirationDate = cachedAt.addingTimeInterval(TimeInterval(expirationDays * 24 * 60 * 60))
        return Date() > expirationDate
    }
}
