import Foundation
import NaturalLanguage
import Combine

/// 翻译服务 - 优先使用iOS系统翻译（通过UITextChecker和系统API），备用使用后端API
@MainActor
class TranslationService {
    static let shared = TranslationService()
    
    private var cancellables = Set<AnyCancellable>()
    private let cacheManager = TranslationCacheManager.shared
    
    // 语言检测结果缓存（避免重复检测相同文本）
    // 使用 NSCache 而不是普通字典，支持内存压力时自动清理
    private let languageDetectionCache = NSCache<NSString, NSString>()
    private let maxDetectionCacheSize = 500 // 最大缓存条目数
    
    private init() {
        // 配置语言检测缓存
        languageDetectionCache.countLimit = maxDetectionCacheSize
        // 设置总成本限制（估算：每个条目平均约100字节）
        languageDetectionCache.totalCostLimit = maxDetectionCacheSize * 100
    }
    
    /// 获取用户系统语言代码
    func getUserSystemLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        // 提取语言代码（例如：zh-Hans-CN -> zh）
        if #available(iOS 16.0, *) {
            let languageCode = Locale(identifier: preferredLanguage).language.languageCode?.identifier ?? "en"
            return languageCode
        } else {
            let languageCode = Locale(identifier: preferredLanguage).languageCode ?? "en"
            return languageCode
        }
    }
    
    /// 检测文本语言（带缓存优化）
    func detectLanguage(_ text: String) -> String? {
        // 先检查缓存
        if let cached = languageDetectionCache.object(forKey: text as NSString) {
            let cachedString = cached as String
            return cachedString.isEmpty ? nil : cachedString
        }
        
        // 对于太短的文本，跳过检测（提高性能）
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.count < 3 {
            languageDetectionCache.setObject("" as NSString, forKey: text as NSString)
            return nil
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmedText)
        
        guard let dominantLanguage = recognizer.dominantLanguage else {
            languageDetectionCache.setObject("" as NSString, forKey: text as NSString)
            return nil
        }
        
        // 转换为语言代码（例如：zh-Hans -> zh）
        let languageCode = dominantLanguage.rawValue.components(separatedBy: "-").first ?? dominantLanguage.rawValue
        
        // 保存到缓存（NSCache 会自动管理大小，无需手动清理）
        languageDetectionCache.setObject(languageCode as NSString, forKey: text as NSString, cost: text.count)
        
        return languageCode
    }
    
    /// 判断是否需要翻译
    func needsTranslation(_ text: String) -> Bool {
        guard let detectedLanguage = detectLanguage(text) else {
            return false
        }
        
        let userLanguage = getUserSystemLanguage()
        
        // 如果检测到的语言与用户系统语言不同，则需要翻译
        return detectedLanguage.lowercased() != userLanguage.lowercased()
    }
    
    /// 翻译文本（优先使用缓存，然后尝试系统翻译，最后使用后端API）
    func translate(
        _ text: String,
        targetLanguage: String? = nil,
        sourceLanguage: String? = nil
    ) async throws -> String {
        let targetLang = targetLanguage ?? getUserSystemLanguage()
        let sourceLang = sourceLanguage ?? detectLanguage(text)
        
        // 1. 先检查缓存
        if let cached = cacheManager.getCachedTranslation(
            text: text,
            targetLanguage: targetLang,
            sourceLanguage: sourceLang
        ) {
            Logger.debug("使用缓存的翻译: \(text.prefix(20))...", category: .cache)
            return cached
        }
        
        // 2. 尝试系统翻译
        var translatedText: String?
        if #available(iOS 15.0, *) {
            translatedText = try? await translateWithSystem(text: text, targetLanguage: targetLang, sourceLanguage: sourceLang)
        }
        
        // 3. 如果系统翻译失败，使用后端API
        if translatedText == nil {
            translatedText = try await translateWithBackend(text: text, targetLanguage: targetLang, sourceLanguage: sourceLang)
        }
        
        guard let translated = translatedText else {
            throw TranslationError.backendTranslationFailed("翻译失败")
        }
        
        // 4. 保存到缓存
        cacheManager.saveTranslation(
            text: text,
            translatedText: translated,
            targetLanguage: targetLang,
            sourceLanguage: sourceLang
        )
        
        return translated
    }
    
    /// 批量翻译文本（优先使用缓存）
    func translateBatch(
        texts: [String],
        targetLanguage: String? = nil,
        sourceLanguage: String? = nil
    ) async throws -> [String: String] {
        let targetLang = targetLanguage ?? getUserSystemLanguage()
        let sourceLang = sourceLanguage
        
        var results: [String: String] = [:]
        var textsToTranslate: [String] = []
        
        // 1. 先检查缓存
        let cached = cacheManager.getCachedTranslations(
            texts: texts,
            targetLanguage: targetLang,
            sourceLanguage: sourceLang
        )
        
        results.merge(cached) { (_, new) in new }
        
        // 2. 找出需要翻译的文本
        for text in texts {
            if results[text] == nil {
                textsToTranslate.append(text)
            }
        }
        
        // 3. 批量翻译未缓存的文本
        if !textsToTranslate.isEmpty {
            // 使用后端批量翻译API
            let translated = try await translateBatchWithBackend(
                texts: textsToTranslate,
                targetLanguage: targetLang,
                sourceLanguage: sourceLang
            )
            
            // 4. 保存到缓存
            cacheManager.saveTranslations(
                translations: translated,
                targetLanguage: targetLang,
                sourceLanguage: sourceLang
            )
            
            // 5. 合并结果
            results.merge(translated) { (_, new) in new }
        }
        
        return results
    }
    
    /// 使用iOS系统翻译（iOS 15+）- 使用UITextChecker和系统API
    @available(iOS 15.0, *)
    private func translateWithSystem(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?
    ) async throws -> String {
        // iOS系统没有直接的翻译API，但可以通过UITextChecker进行一些基础处理
        // 这里我们直接返回nil，让系统使用后端API
        // 如果未来iOS提供了翻译API，可以在这里实现
        throw TranslationError.systemTranslationFailed("系统翻译暂不可用")
    }
    
    /// 使用后端API翻译
    private func translateWithBackend(
        text: String,
        targetLanguage: String,
        sourceLanguage: String?
    ) async throws -> String {
        var body: [String: Any] = [
            "text": text,
            "target_language": targetLanguage
        ]
        
        if let sourceLang = sourceLanguage {
            body["source_language"] = sourceLang
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIService.shared.request(
                TranslationResponse.self,
                "/api/translate",
                method: "POST",
                body: body
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: TranslationError.backendTranslationFailed(error.localizedDescription))
                    }
                },
                receiveValue: { response in
                    continuation.resume(returning: response.translated_text)
                }
            )
            .store(in: &self.cancellables)
        }
    }
    
    /// 使用后端API批量翻译
    private func translateBatchWithBackend(
        texts: [String],
        targetLanguage: String,
        sourceLanguage: String?
    ) async throws -> [String: String] {
        var body: [String: Any] = [
            "texts": texts,
            "target_language": targetLanguage
        ]
        
        if let sourceLang = sourceLanguage {
            body["source_language"] = sourceLang
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            APIService.shared.request(
                BatchTranslationResponse.self,
                "/api/translate/batch",
                method: "POST",
                body: body
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(throwing: TranslationError.backendTranslationFailed(error.localizedDescription))
                    }
                },
                receiveValue: { response in
                    var results: [String: String] = [:]
                    for translation in response.translations {
                        results[translation.original_text] = translation.translated_text
                    }
                    continuation.resume(returning: results)
                }
            )
            .store(in: &self.cancellables)
        }
    }
    
}

/// 翻译响应模型
private struct TranslationResponse: Codable {
    let translated_text: String
    let source_language: String?
    let target_language: String?
    let original_text: String?
}

/// 批量翻译响应模型
private struct BatchTranslationResponse: Codable {
    let translations: [TranslationItem]
    let target_language: String?
}

/// 批量翻译项
private struct TranslationItem: Codable {
    let original_text: String
    let translated_text: String
    let source_language: String?
}

/// 翻译错误
enum TranslationError: LocalizedError {
    case unsupportedLanguage
    case systemTranslationFailed(String)
    case backendTranslationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedLanguage:
            return "不支持的语言"
        case .systemTranslationFailed(let message):
            return "系统翻译失败: \(message)"
        case .backendTranslationFailed(let message):
            return "后端翻译失败: \(message)"
        }
    }
}
