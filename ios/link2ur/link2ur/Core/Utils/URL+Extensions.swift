import Foundation

/// URL 扩展 - 企业级 URL 处理工具
extension URL {
    
    // MARK: - 查询参数
    
    /// 获取查询参数
    public var queryParameters: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        for item in queryItems {
            parameters[item.name] = item.value
        }
        return parameters
    }
    
    /// 添加查询参数
    public func appendingQueryParameters(_ parameters: [String: String]) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        var queryItems = components.queryItems ?? []
        for (key, value) in parameters {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = queryItems
        
        return components.url
    }
    
    // MARK: - 路径操作
    
    /// 获取文件扩展名
    public var fileExtension: String {
        return pathExtension
    }
    
    /// 获取文件名（不含扩展名）
    public var fileNameWithoutExtension: String {
        return deletingPathExtension().lastPathComponent
    }
    
    /// 获取文件名（含扩展名）
    public var fileName: String {
        return lastPathComponent
    }
    
    // MARK: - 验证
    
    /// 是否是有效的 HTTP/HTTPS URL
    public var isValidHTTPURL: Bool {
        guard let scheme = scheme else { return false }
        return ["http", "https"].contains(scheme.lowercased())
    }
    
    /// 是否是文件 URL
    public var isFileURL: Bool {
        return scheme == "file"
    }
    
    // MARK: - 文件信息
    
    /// 获取文件大小
    public var fileSize: Int64? {
        guard isFileURL else { return nil }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// 文件是否存在
    public var fileExists: Bool {
        guard isFileURL else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
    
    /// 是否是目录
    public var isDirectory: Bool {
        guard isFileURL else { return false }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}

