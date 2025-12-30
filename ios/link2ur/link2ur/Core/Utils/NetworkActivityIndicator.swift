import UIKit

/// 网络活动指示器管理 - 企业级网络状态显示
public class NetworkActivityIndicator {
    public static let shared = NetworkActivityIndicator()
    
    private var activityCount: Int = 0
    private let lock = NSLock()
    
    private init() {}
    
    /// 开始网络活动
    public func start() {
        lock.lock()
        defer { lock.unlock() }
        
        activityCount += 1
        updateIndicator()
    }
    
    /// 结束网络活动
    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        
        activityCount = max(0, activityCount - 1)
        updateIndicator()
    }
    
    /// 更新指示器状态
    private func updateIndicator() {
        // 注意：isNetworkActivityIndicatorVisible 在 iOS 13+ 已弃用
        // 如果需要网络活动指示，应该使用自定义 UI 组件
        #if swift(>=5.0)
        if #available(iOS 13.0, *) {
            // iOS 13+ 不再支持系统网络活动指示器
            // 可以在这里添加自定义的网络活动指示器逻辑
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = self.activityCount > 0
            }
        }
        #else
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = self.activityCount > 0
        }
        #endif
    }
    
    /// 执行网络操作（自动管理指示器）
    public func perform<T>(_ operation: () async throws -> T) async rethrows -> T {
        start()
        defer { stop() }
        return try await operation()
    }
}

