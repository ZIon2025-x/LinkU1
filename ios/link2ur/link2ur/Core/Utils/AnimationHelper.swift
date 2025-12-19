import SwiftUI

/// 动画辅助工具 - 企业级动画管理
public struct AnimationHelper {
    
    /// 默认动画
    public static let `default` = Animation.default
    
    /// 弹性动画
    public static let spring = Animation.spring()
    
    /// 弹性动画（自定义）
    public static func spring(
        response: Double = 0.5,
        dampingFraction: Double = 0.8,
        blendDuration: Double = 0
    ) -> Animation {
        return Animation.spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }
    
    /// 缓入动画
    public static let easeIn = Animation.easeIn
    
    /// 缓出动画
    public static let easeOut = Animation.easeOut
    
    /// 缓入缓出动画
    public static let easeInOut = Animation.easeInOut
    
    /// 线性动画
    public static let linear = Animation.linear
    
    /// 自定义时长动画
    public static func duration(_ seconds: Double) -> Animation {
        return Animation.linear(duration: seconds)
    }
    
    /// 快速动画
    public static let fast = Animation.easeInOut(duration: 0.2)
    
    /// 中等动画
    public static let medium = Animation.easeInOut(duration: 0.3)
    
    /// 慢速动画
    public static let slow = Animation.easeInOut(duration: 0.5)
}

/// 动画修饰符
extension View {
    /// 应用动画
    public func animated(_ animation: Animation = .default) -> some View {
        self.animation(animation, value: UUID())
    }
    
    /// 应用弹性动画
    public func springAnimated() -> some View {
        self.animation(AnimationHelper.spring, value: UUID())
    }
    
    /// 应用快速动画
    public func fastAnimated() -> some View {
        self.animation(AnimationHelper.fast, value: UUID())
    }
}

