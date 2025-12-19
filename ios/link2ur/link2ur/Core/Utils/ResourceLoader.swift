import Foundation
import SwiftUI

/// 资源加载器 - 企业级资源管理
public struct ResourceLoader {
    
    // MARK: - 本地化字符串
    
    /// 加载本地化字符串
    public static func localizedString(
        _ key: String,
        tableName: String? = nil,
        bundle: Bundle = .main,
        value: String = "",
        comment: String = ""
    ) -> String {
        return NSLocalizedString(key, tableName: tableName, bundle: bundle, value: value, comment: comment)
    }
    
    /// 加载本地化字符串（带参数）
    public static func localizedString(
        _ key: String,
        arguments: CVarArg...,
        tableName: String? = nil,
        bundle: Bundle = .main
    ) -> String {
        let format = ResourceLoader.localizedString(key, tableName: tableName, bundle: bundle, value: "", comment: "")
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - 图片资源
    
    /// 加载图片资源
    public static func loadImage(named name: String) -> Image? {
        if UIImage(named: name) != nil {
            return Image(name)
        }
        return nil
    }
    
    /// 加载系统图标
    public static func systemImage(_ name: String) -> Image {
        return Image(systemName: name)
    }
    
    // MARK: - JSON 资源
    
    /// 加载 JSON 文件
    public static func loadJSON<T: Decodable>(
        _ type: T.Type,
        from filename: String,
        bundle: Bundle = .main
    ) throws -> T {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw ResourceError.fileNotFound(filename)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - 配置文件
    
    /// 加载配置文件
    public static func loadConfig(from filename: String, bundle: Bundle = .main) -> [String: Any]? {
        guard let url = bundle.url(forResource: filename, withExtension: "plist") else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
    }
    
    // MARK: - 文本文件
    
    /// 加载文本文件
    public static func loadText(from filename: String, bundle: Bundle = .main) -> String? {
        guard let url = bundle.url(forResource: filename, withExtension: "txt") else {
            return nil
        }
        
        return try? String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - 资源错误

enum ResourceError: LocalizedError {
    case fileNotFound(String)
    case decodingFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "资源文件未找到: \(filename)"
        case .decodingFailed:
            return "资源解码失败"
        case .invalidFormat:
            return "资源格式无效"
        }
    }
}

