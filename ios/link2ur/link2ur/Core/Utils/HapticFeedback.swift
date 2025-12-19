import UIKit

/// 触觉反馈工具 - 企业级用户反馈
public struct HapticFeedback {
    
    public enum FeedbackType {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case notification(UINotificationFeedbackGenerator.FeedbackType)
        case selection
    }
    
    /// 触发触觉反馈
    public static func trigger(_ type: FeedbackType) {
        switch type {
        case .impact(let style):
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
            
        case .notification(let notificationType):
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(notificationType)
            
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    /// 轻触反馈
    public static func light() {
        trigger(.impact(.light))
    }
    
    /// 中等触觉反馈
    public static func medium() {
        trigger(.impact(.medium))
    }
    
    /// 重触觉反馈
    public static func heavy() {
        trigger(.impact(.heavy))
    }
    
    /// 成功反馈
    public static func success() {
        trigger(.notification(.success))
    }
    
    /// 警告反馈
    public static func warning() {
        trigger(.notification(.warning))
    }
    
    /// 错误反馈
    public static func error() {
        trigger(.notification(.error))
    }
    
    /// 选择反馈
    public static func selection() {
        trigger(.selection)
    }
}

