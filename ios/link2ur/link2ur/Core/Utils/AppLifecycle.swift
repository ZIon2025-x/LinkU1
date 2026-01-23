import Foundation
import UIKit
import Combine

/// 应用生命周期管理 - 企业级生命周期监控
public class AppLifecycle: ObservableObject {
    public static let shared = AppLifecycle()
    
    @Published public var state: AppState = .background
    @Published public var timeInBackground: TimeInterval = 0
    
    public enum AppState {
        case foreground
        case background
        case inactive
    }
    
    private var backgroundTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // 应用进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)
        
        // 应用进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)
        
        // 应用变为活跃
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleDidBecomeActive()
            }
            .store(in: &cancellables)
        
        // 应用变为非活跃
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleWillResignActive()
            }
            .store(in: &cancellables)
    }
    
    private func handleWillEnterForeground() {
        if let backgroundTime = backgroundTime {
            timeInBackground = Date().timeIntervalSince(backgroundTime)
            self.backgroundTime = nil
        }
        state = .foreground
    }
    
    private func handleDidEnterBackground() {
        backgroundTime = Date()
        state = .background
        
        // 应用进入后台时，清理部分缓存以释放内存
        // 在后台线程执行，避免阻塞主线程
        DispatchQueue.global(qos: .utility).async {
            // 清理过期的数据缓存
            CacheManager.shared.clearExpiredCache()
            
            // 清理过期的图片缓存（保留最近7天的）
            ImageCache.shared.clearExpiredCache(maxAge: 7 * 24 * 3600)
            
            Logger.debug("应用进入后台，已清理过期缓存", category: .cache)
        }
    }
    
    private func handleDidBecomeActive() {
        state = .foreground
    }
    
    private func handleWillResignActive() {
        state = .inactive
    }
}

