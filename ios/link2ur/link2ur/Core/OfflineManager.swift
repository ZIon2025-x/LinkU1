import Foundation
import Combine
import Network

// MARK: - 离线操作类型

/// 离线操作类型
public enum OfflineOperationType: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case custom = "custom"
}

/// 离线操作状态
public enum OfflineOperationStatus: String, Codable {
    case pending = "pending"       // 待同步
    case syncing = "syncing"       // 同步中
    case completed = "completed"   // 已完成
    case failed = "failed"         // 失败
    case cancelled = "cancelled"   // 已取消
}

/// 离线操作记录
public struct OfflineOperation: Codable, Identifiable {
    public let id: UUID
    public let type: OfflineOperationType
    public let endpoint: String
    public let method: String
    public let body: Data?
    public let headers: [String: String]?
    public let createdAt: Date
    public var status: OfflineOperationStatus
    public var retryCount: Int
    public var lastError: String?
    public var syncedAt: Date?
    public let resourceType: String? // 资源类型，如 "task", "message" 等
    public let resourceId: String?   // 资源 ID
    
    public init(
        type: OfflineOperationType,
        endpoint: String,
        method: String,
        body: Data? = nil,
        headers: [String: String]? = nil,
        resourceType: String? = nil,
        resourceId: String? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.endpoint = endpoint
        self.method = method
        self.body = body
        self.headers = headers
        self.createdAt = Date()
        self.status = .pending
        self.retryCount = 0
        self.resourceType = resourceType
        self.resourceId = resourceId
    }
}

// MARK: - 同步冲突

/// 同步冲突类型
public enum SyncConflictType {
    case localNewer      // 本地数据较新
    case serverNewer     // 服务器数据较新
    case bothModified    // 两边都修改了
}

/// 同步冲突
public struct SyncConflict {
    public let operation: OfflineOperation
    public let conflictType: SyncConflictType
    public let localData: Data?
    public let serverData: Data?
}

/// 冲突解决策略
public enum ConflictResolutionStrategy {
    case useLocal        // 使用本地数据
    case useServer       // 使用服务器数据
    case merge           // 合并（需要自定义逻辑）
    case askUser         // 询问用户
}

// MARK: - 离线管理器

/// 离线管理器 - 企业级离线支持
public final class OfflineManager: ObservableObject {
    public static let shared = OfflineManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isOfflineMode: Bool = false
    @Published public private(set) var pendingOperations: [OfflineOperation] = []
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncTime: Date?
    @Published public private(set) var syncProgress: Double = 0
    
    // MARK: - Private Properties
    
    private let operationsFile: URL
    private let queue = DispatchQueue(label: "com.link2ur.offlinemanager", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    private let maxRetryCount = 3
    private let maxPendingOperations = 100
    
    /// 冲突解决策略
    public var conflictResolutionStrategy: ConflictResolutionStrategy = .useServer
    
    /// 同步冲突回调
    public var onConflict: ((SyncConflict) -> ConflictResolutionStrategy)?
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        operationsFile = documentsDir.appendingPathComponent("offline_operations.json")
        
        loadPendingOperations()
        setupNetworkObserver()
        
        Logger.debug("OfflineManager 初始化，待同步操作: \(pendingOperations.count)", category: .network)
    }
    
    // MARK: - Public Methods
    
    /// 添加离线操作
    public func addOperation(_ operation: OfflineOperation) {
        guard isEnabled else { return }
        guard pendingOperations.count < maxPendingOperations else {
            Logger.warning("离线操作队列已满，丢弃操作: \(operation.endpoint)", category: .network)
            return
        }
        
        queue.async { [weak self] in
            self?.pendingOperations.append(operation)
            self?.savePendingOperations()
            
            Logger.debug("添加离线操作: \(operation.method) \(operation.endpoint)", category: .network)
        }
    }
    
    /// 创建离线操作（便捷方法）
    public func queueOperation(
        type: OfflineOperationType,
        endpoint: String,
        method: String,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil,
        resourceType: String? = nil,
        resourceId: String? = nil
    ) {
        var bodyData: Data?
        if let body = body {
            bodyData = try? JSONSerialization.data(withJSONObject: body)
        }
        
        let operation = OfflineOperation(
            type: type,
            endpoint: endpoint,
            method: method,
            body: bodyData,
            headers: headers,
            resourceType: resourceType,
            resourceId: resourceId
        )
        
        addOperation(operation)
    }
    
    /// 取消离线操作
    public func cancelOperation(_ operationId: UUID) {
        queue.async { [weak self] in
            if let index = self?.pendingOperations.firstIndex(where: { $0.id == operationId }) {
                self?.pendingOperations[index].status = .cancelled
                self?.savePendingOperations()
            }
        }
    }
    
    /// 获取特定资源的待同步操作
    public func getPendingOperations(for resourceType: String, resourceId: String) -> [OfflineOperation] {
        return pendingOperations.filter { 
            $0.resourceType == resourceType && 
            $0.resourceId == resourceId && 
            $0.status == .pending 
        }
    }
    
    /// 手动触发同步
    public func syncNow() {
        guard !isSyncing else { return }
        guard Reachability.shared.isConnected else {
            Logger.warning("无网络连接，无法同步", category: .network)
            return
        }
        
        performSync()
    }
    
    /// 清除已完成的操作
    public func clearCompletedOperations() {
        queue.async { [weak self] in
            self?.pendingOperations.removeAll { $0.status == .completed || $0.status == .cancelled }
            self?.savePendingOperations()
        }
    }
    
    /// 清除所有操作
    public func clearAllOperations() {
        queue.async { [weak self] in
            self?.pendingOperations.removeAll()
            self?.savePendingOperations()
        }
    }
    
    /// 获取同步状态摘要
    public func getSyncStatus() -> [String: Any] {
        return [
            "is_offline": isOfflineMode,
            "is_syncing": isSyncing,
            "pending_count": pendingOperations.filter { $0.status == .pending }.count,
            "failed_count": pendingOperations.filter { $0.status == .failed }.count,
            "last_sync": lastSyncTime?.description ?? "never"
        ]
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkObserver() {
        // 监听网络状态变化
        Reachability.shared.$isConnected
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleNetworkStateChange(isConnected: isConnected)
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkStateChange(isConnected: Bool) {
        isOfflineMode = !isConnected
        
        if isConnected && !pendingOperations.isEmpty {
            // 网络恢复，延迟一秒后开始同步（等待网络稳定）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.syncNow()
            }
        }
    }
    
    private func performSync() {
        isSyncing = true
        syncProgress = 0
        
        let operationsToSync = pendingOperations.filter { $0.status == .pending || ($0.status == .failed && $0.retryCount < maxRetryCount) }
        
        guard !operationsToSync.isEmpty else {
            isSyncing = false
            lastSyncTime = Date()
            Logger.debug("没有待同步的操作", category: .network)
            return
        }
        
        Logger.info("开始同步 \(operationsToSync.count) 个离线操作", category: .network)
        
        AsyncTask {
            var syncedCount = 0
            let total = Double(operationsToSync.count)
            
            for operation in operationsToSync {
                // 检查网络状态
                guard Reachability.shared.isConnected else {
                    Logger.warning("网络断开，暂停同步", category: .network)
                    break
                }
                
                await syncOperation(operation)
                
                syncedCount += 1
                await MainActor.run {
                    self.syncProgress = Double(syncedCount) / total
                }
            }
            
            await MainActor.run {
                self.isSyncing = false
                self.lastSyncTime = Date()
                self.clearCompletedOperations()
                
                let successCount = self.pendingOperations.filter { $0.status == .completed }.count
                let failedCount = self.pendingOperations.filter { $0.status == .failed }.count
                Logger.info("同步完成 - 成功: \(successCount), 失败: \(failedCount)", category: .network)
            }
        }
    }
    
    private func syncOperation(_ operation: OfflineOperation) async {
        // 更新状态为同步中
        updateOperationStatus(operation.id, status: .syncing)
        
        do {
            // 执行同步请求
            try await executeOperation(operation)
            
            // 更新状态为完成
            updateOperationStatus(operation.id, status: .completed)
            Logger.debug("同步成功: \(operation.method) \(operation.endpoint)", category: .network)
            
        } catch {
            // 增加重试次数
            incrementRetryCount(operation.id)
            
            // 更新状态为失败
            updateOperationStatus(operation.id, status: .failed, error: error.localizedDescription)
            Logger.warning("同步失败: \(operation.method) \(operation.endpoint) - \(error.localizedDescription)", category: .network)
        }
    }
    
    private func executeOperation(_ operation: OfflineOperation) async throws {
        guard let url = URL(string: "\(Constants.API.baseURL)\(operation.endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = operation.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加 headers
        if let headers = operation.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加认证
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            AppSignature.signRequest(&request, sessionId: sessionId)
        }
        
        // 设置 body
        if let body = operation.body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            // 检查是否是冲突
            if httpResponse.statusCode == 409 {
                // 处理冲突
                try await handleConflict(operation: operation, serverData: data)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
    
    private func handleConflict(operation: OfflineOperation, serverData: Data) async throws {
        let conflict = SyncConflict(
            operation: operation,
            conflictType: .bothModified,
            localData: operation.body,
            serverData: serverData
        )
        
        let resolution = onConflict?(conflict) ?? conflictResolutionStrategy
        
        switch resolution {
        case .useLocal:
            // 强制使用本地数据，重新发送请求
            Logger.debug("冲突解决：使用本地数据", category: .network)
            // 可以在这里添加强制更新的逻辑
            
        case .useServer:
            // 使用服务器数据，标记操作为完成
            Logger.debug("冲突解决：使用服务器数据", category: .network)
            updateOperationStatus(operation.id, status: .completed)
            
        case .merge:
            // 合并逻辑需要根据具体业务实现
            Logger.debug("冲突解决：合并数据", category: .network)
            
        case .askUser:
            // 发送通知让 UI 处理
            Logger.debug("冲突解决：需要用户决定", category: .network)
            NotificationCenter.default.post(
                name: .syncConflictDetected,
                object: nil,
                userInfo: ["conflict": conflict]
            )
        }
    }
    
    private func updateOperationStatus(_ operationId: UUID, status: OfflineOperationStatus, error: String? = nil) {
        queue.async { [weak self] in
            guard let self = self,
                  let index = self.pendingOperations.firstIndex(where: { $0.id == operationId }) else {
                return
            }
            
            self.pendingOperations[index].status = status
            self.pendingOperations[index].lastError = error
            
            if status == .completed {
                self.pendingOperations[index].syncedAt = Date()
            }
            
            self.savePendingOperations()
        }
    }
    
    private func incrementRetryCount(_ operationId: UUID) {
        queue.async { [weak self] in
            guard let self = self,
                  let index = self.pendingOperations.firstIndex(where: { $0.id == operationId }) else {
                return
            }
            
            self.pendingOperations[index].retryCount += 1
            self.savePendingOperations()
        }
    }
    
    private func loadPendingOperations() {
        guard let data = try? Data(contentsOf: operationsFile),
              let operations = try? JSONDecoder().decode([OfflineOperation].self, from: data) else {
            return
        }
        
        pendingOperations = operations
    }
    
    private func savePendingOperations() {
        guard let data = try? JSONEncoder().encode(pendingOperations) else { return }
        try? data.write(to: operationsFile, options: .atomic)
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    /// 检测到同步冲突
    static let syncConflictDetected = Notification.Name("syncConflictDetected")
    /// 同步完成
    static let syncCompleted = Notification.Name("syncCompleted")
}

// MARK: - 离线数据存储

/// 离线数据存储（用于存储关键数据的本地副本）
public final class OfflineDataStore {
    public static let shared = OfflineDataStore()
    
    private let storeDirectory: URL
    private let queue = DispatchQueue(label: "com.link2ur.offlinestore", qos: .utility)
    
    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        storeDirectory = documentsDir.appendingPathComponent("OfflineData", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
    }
    
    /// 保存数据
    public func save<T: Codable>(_ data: T, key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.storeDirectory.appendingPathComponent("\(key).json")
            
            do {
                let encodedData = try JSONEncoder().encode(data)
                try encodedData.write(to: fileURL, options: .atomic)
                Logger.debug("离线数据已保存: \(key)", category: .cache)
            } catch {
                Logger.error("保存离线数据失败: \(error.localizedDescription)", category: .cache)
            }
        }
    }
    
    /// 加载数据
    public func load<T: Codable>(_ type: T.Type, key: String) -> T? {
        let fileURL = storeDirectory.appendingPathComponent("\(key).json")
        
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        
        return decoded
    }
    
    /// 删除数据
    public func remove(key: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.storeDirectory.appendingPathComponent("\(key).json")
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    /// 检查数据是否存在
    public func exists(key: String) -> Bool {
        let fileURL = storeDirectory.appendingPathComponent("\(key).json")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// 清除所有离线数据
    public func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.storeDirectory)
            try? FileManager.default.createDirectory(at: self.storeDirectory, withIntermediateDirectories: true)
            Logger.info("所有离线数据已清除", category: .cache)
        }
    }
}

// MARK: - View 修饰符

import SwiftUI

/// 离线模式指示器修饰符
public struct OfflineModeIndicatorModifier: ViewModifier {
    @ObservedObject private var offlineManager = OfflineManager.shared
    
    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if offlineManager.isOfflineMode {
                    offlineIndicator
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: offlineManager.isOfflineMode)
    }
    
    private var offlineIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .semibold))
            
            Text(LocalizationKey.offlineMode.localized)
                .font(.system(size: 14, weight: .medium))
            
            if !offlineManager.pendingOperations.isEmpty {
                Text(LocalizationKey.offlinePendingSync.localized(offlineManager.pendingOperations.filter { $0.status == .pending }.count))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .padding(.bottom, 16)
    }
}

extension View {
    /// 添加离线模式指示器
    public func withOfflineModeIndicator() -> some View {
        modifier(OfflineModeIndicatorModifier())
    }
}
