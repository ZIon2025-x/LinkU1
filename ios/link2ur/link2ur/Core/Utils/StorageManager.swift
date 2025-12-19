import Foundation

/// 存储管理器 - 企业级数据存储
public class StorageManager {
    public static let shared = StorageManager()
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - UserDefaults 存储
    
    /// 存储值
    public func set<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    /// 获取值
    public func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return userDefaults.object(forKey: key) as? T
    }
    
    /// 存储 Codable 对象
    public func setCodable<T: Codable>(_ value: T, forKey key: String) {
        userDefaults.setCodable(value, forKey: key)
    }
    
    /// 获取 Codable 对象
    public func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        return userDefaults.codable(type, forKey: key)
    }
    
    // MARK: - 文件存储
    
    /// 存储数据到文件
    public func saveData(_ data: Data, to path: String) throws {
        let url = fileManager.documentsDirectory.appendingPathComponent(path)
        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectoryIfNeeded(at: directory)
        try data.write(to: url)
    }
    
    /// 从文件读取数据
    public func loadData(from path: String) throws -> Data {
        let url = fileManager.documentsDirectory.appendingPathComponent(path)
        return try Data(contentsOf: url)
    }
    
    /// 存储 Codable 对象到文件
    public func saveCodable<T: Codable>(_ value: T, to path: String) throws {
        let data = try JSONEncoder().encode(value)
        try saveData(data, to: path)
    }
    
    /// 从文件读取 Codable 对象
    public func loadCodable<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
        let data = try loadData(from: path)
        return try JSONDecoder().decode(type, from: data)
    }
    
    // MARK: - 清理
    
    /// 清除所有存储
    public func clearAll() {
        // 清除 UserDefaults（保留系统键）
        let domain = Bundle.main.bundleIdentifier!
        userDefaults.removePersistentDomain(forName: domain)
        
        // 清除文档目录（可选，谨慎使用）
        // try? fileManager.removeItem(at: fileManager.documentsDirectory)
    }
    
    /// 清除指定前缀的键
    public func clear(prefix: String) {
        userDefaults.clear(prefix: prefix)
    }
}

