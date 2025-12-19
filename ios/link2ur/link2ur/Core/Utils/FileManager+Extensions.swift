import Foundation

/// FileManager 扩展 - 企业级文件管理工具
extension FileManager {
    
    /// 文档目录 URL
    public var documentsDirectory: URL {
        return urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// 缓存目录 URL
    public var cachesDirectory: URL {
        return urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
    
    /// 应用支持目录 URL
    public var applicationSupportDirectory: URL {
        return urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - 文件操作
    
    /// 安全创建目录
    @discardableResult
    public func createDirectoryIfNeeded(at url: URL) -> Bool {
        guard !fileExists(atPath: url.path) else { return true }
        do {
            try createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            Logger.error("创建目录失败: \(error)", category: .general)
            return false
        }
    }
    
    /// 安全删除文件或目录
    @discardableResult
    public func safeRemoveItem(at url: URL) -> Bool {
        guard fileExists(atPath: url.path) else { return true }
        do {
            try removeItem(at: url)
            return true
        } catch {
            Logger.error("删除文件失败: \(error)", category: .general)
            return false
        }
    }
    
    /// 安全复制文件
    @discardableResult
    public func safeCopyItem(from sourceURL: URL, to destinationURL: URL) -> Bool {
        do {
            // 确保目标目录存在
            let destinationDir = destinationURL.deletingLastPathComponent()
            createDirectoryIfNeeded(at: destinationDir)
            
            // 如果目标文件存在，先删除
            if fileExists(atPath: destinationURL.path) {
                try removeItem(at: destinationURL)
            }
            
            try copyItem(at: sourceURL, to: destinationURL)
            return true
        } catch {
            Logger.error("复制文件失败: \(error)", category: .general)
            return false
        }
    }
    
    // MARK: - 文件信息
    
    /// 获取文件大小
    public func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// 获取目录大小（递归计算）
    public func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [],
            errorHandler: nil
        ) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = fileSize(at: fileURL) {
                totalSize += size
            }
        }
        return totalSize
    }
    
    /// 格式化文件大小
    public func formattedFileSize(at url: URL) -> String {
        let size = fileSize(at: url) ?? 0
        return formatBytes(size)
    }
    
    /// 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - 清理操作
    
    /// 清理临时文件
    public func clearTemporaryFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        guard let files = try? contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) else {
            return
        }
        
        for file in files {
            safeRemoveItem(at: file)
        }
    }
    
    /// 清理过期缓存文件
    public func clearExpiredCacheFiles(maxAge: TimeInterval = 7 * 24 * 3600) {
        let cacheDir = cachesDirectory
        guard let files = try? contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return
        }
        
        let now = Date()
        for file in files {
            if let attributes = try? attributesOfItem(atPath: file.path),
               let modificationDate = attributes[.modificationDate] as? Date,
               now.timeIntervalSince(modificationDate) > maxAge {
                safeRemoveItem(at: file)
            }
        }
    }
}

