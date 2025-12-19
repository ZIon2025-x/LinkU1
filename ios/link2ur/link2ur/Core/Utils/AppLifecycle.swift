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
    }
    
    private func handleDidBecomeActive() {
        state = .foreground
    }
    
    private func handleWillResignActive() {
        state = .inactive
    }
}

