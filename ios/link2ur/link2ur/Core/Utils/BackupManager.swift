import Foundation

/// 备份管理器 - 企业级数据备份
public class BackupManager {
    public static let shared = BackupManager()
    
    private let fileManager = FileManager.default
    private let backupDirectory: URL
    
    private init() {
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        backupDirectory = urls[0].appendingPathComponent("Backups")
        fileManager.createDirectoryIfNeeded(at: backupDirectory)
    }
    
    /// 创建备份
    public func createBackup(
        data: Data,
        name: String,
        metadata: [String: Any]? = nil
    ) throws -> URL {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "\(name)_\(Int(timestamp)).backup"
        let fileURL = backupDirectory.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        
        // 保存元数据
        if let metadata = metadata {
            let metadataURL = fileURL.appendingPathExtension("meta")
            let metadataData = try JSONSerialization.data(withJSONObject: metadata)
            try metadataData.write(to: metadataURL)
        }
        
        return fileURL
    }
    
    /// 恢复备份
    public func restoreBackup(from url: URL) throws -> Data {
        return try Data(contentsOf: url)
    }
    
    /// 列出所有备份
    public func listBackups() -> [URL] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey]
        ) else {
            return []
        }
        
        return files.filter { $0.pathExtension == "backup" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
    }
    
    /// 删除旧备份
    public func cleanOldBackups(keepCount: Int = 10) {
        let backups = listBackups()
        if backups.count > keepCount {
            let toDelete = backups.dropFirst(keepCount)
            for backup in toDelete {
                try? fileManager.removeItem(at: backup)
            }
        }
    }
}

