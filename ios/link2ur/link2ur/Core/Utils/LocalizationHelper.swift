import Foundation

/// 本地化辅助工具 - 企业级多语言支持
public struct LocalizationHelper {
    
    /// 当前语言代码
    public static var currentLanguage: String {
        return Locale.current.languageCode ?? "en"
    }
    
    /// 当前区域代码
    public static var currentRegion: String {
        return Locale.current.regionCode ?? "US"
    }
    
    /// 当前语言标识符
    public static var currentLocale: String {
        return Locale.current.identifier
    }
    
    /// 获取本地化字符串
    public static func localized(
        _ key: String,
        tableName: String? = nil,
        bundle: Bundle = .main,
        comment: String = ""
    ) -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: bundle, comment: comment)
    }
    
    /// 获取本地化字符串（带参数）
    public static func localized(
        _ key: String,
        arguments: CVarArg...,
        tableName: String? = nil,
        bundle: Bundle = .main
    ) -> String {
        let format = localized(key, tableName: tableName, bundle: bundle)
        return String(format: format, arguments: arguments)
    }
    
    /// 检查是否支持语言
    public static func isLanguageSupported(_ languageCode: String) -> Bool {
        let supportedLanguages = ["en", "zh-Hans", "zh-Hant"]
        return supportedLanguages.contains(languageCode)
    }
    
    /// 获取支持的语言列表
    public static var supportedLanguages: [String] {
        return ["en", "zh-Hans", "zh-Hant"]
    }
}

/// 本地化键
public enum LocalizationKey: String {
    case welcome = "welcome"
    case error = "error"
    case success = "success"
    case loading = "loading"
    case cancel = "cancel"
    case confirm = "confirm"
    case delete = "delete"
    case save = "save"
    case edit = "edit"
    
    public var localized: String {
        return LocalizationHelper.localized(self.rawValue)
    }
}

