import Foundation
import StoreKit

/// 应用评价管理器 - 企业级评价管理
public class AppReview {
    public static let shared = AppReview()
    
    private let minLaunchCount = 5
    private let minDaysSinceInstall = 7
    private let reviewRequestKey = "review_request_count"
    private let lastReviewRequestKey = "last_review_request_date"
    private let installDateKey = "app_install_date"
    
    private init() {
        setupInstallDate()
    }
    
    /// 设置安装日期
    private func setupInstallDate() {
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
    }
    
    /// 检查是否可以请求评价
    public var canRequestReview: Bool {
        let launchCount = UserDefaults.standard.integer(forKey: reviewRequestKey)
        let lastRequestDate = UserDefaults.standard.date(forKey: lastReviewRequestKey)
        let installDate = UserDefaults.standard.date(forKey: installDateKey) ?? Date()
        let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
        
        // 检查是否满足条件
        guard launchCount >= minLaunchCount else { return false }
        guard daysSinceInstall >= minDaysSinceInstall else { return false }
        
        // 检查距离上次请求是否超过30天
        if let lastRequest = lastRequestDate {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSinceLastRequest >= 30 else { return false }
        }
        
        return true
    }
    
    /// 请求评价
    public func requestReview() {
        guard canRequestReview else { return }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
            
            // 更新请求记录
            let currentCount = UserDefaults.standard.integer(forKey: reviewRequestKey)
            UserDefaults.standard.set(currentCount + 1, forKey: reviewRequestKey)
            UserDefaults.standard.set(Date(), forKey: lastReviewRequestKey)
        }
    }
    
    /// 增加启动计数
    public func incrementLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: reviewRequestKey)
        UserDefaults.standard.set(currentCount + 1, forKey: reviewRequestKey)
    }
    
    /// 重置评价请求记录
    public func reset() {
        UserDefaults.standard.removeObject(forKey: reviewRequestKey)
        UserDefaults.standard.removeObject(forKey: lastReviewRequestKey)
    }
}

