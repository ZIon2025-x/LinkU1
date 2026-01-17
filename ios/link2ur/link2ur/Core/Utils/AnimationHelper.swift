import SwiftUI

/// 动画辅助工具 - 企业级动画管理，提供丝滑流畅的用户体验
public struct AnimationHelper {
    
    // MARK: - 基础动画
    
    /// 默认动画
    public static let `default` = Animation.default
    
    /// 标准弹性动画 - 用于大多数UI交互
    public static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
    
    /// 弹性动画（自定义）
    public static func spring(
        response: Double = 0.4,
        dampingFraction: Double = 0.75,
        blendDuration: Double = 0
    ) -> Animation {
        return Animation.spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }
    
    // MARK: - 预设弹性动画
    
    /// 丝滑弹性 - 用于按钮点击、卡片交互（最自然的感觉）
    public static let silkySpring = Animation.spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0)
    
    /// 轻快弹性 - 用于快速反馈（如开关、选项切换）
    public static let snappySpring = Animation.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0)
    
    /// 柔和弹性 - 用于页面过渡、模态展示
    public static let gentleSpring = Animation.spring(response: 0.5, dampingFraction: 0.85, blendDuration: 0)
    
    /// 弹跳弹性 - 用于强调动画、成功提示
    public static let bouncySpring = Animation.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0)
    
    /// 交互弹性 - 专为触摸反馈设计
    public static let interactiveSpring = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    
    // MARK: - 基础动画曲线
    
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
        return Animation.easeInOut(duration: seconds)
    }
    
    // MARK: - 速度预设
    
    /// 瞬间 - 用于即时反馈（0.1s）
    public static let instant = Animation.easeOut(duration: 0.1)
    
    /// 快速动画（0.2s）
    public static let fast = Animation.easeInOut(duration: 0.2)
    
    /// 中等动画（0.3s）
    public static let medium = Animation.easeInOut(duration: 0.3)
    
    /// 慢速动画（0.5s）
    public static let slow = Animation.easeInOut(duration: 0.5)
    
    // MARK: - 特殊效果动画
    
    /// 淡入动画
    public static let fadeIn = Animation.easeOut(duration: 0.25)
    
    /// 淡出动画
    public static let fadeOut = Animation.easeIn(duration: 0.2)
    
    /// 滑入动画
    public static let slideIn = Animation.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0)
    
    /// 缩放动画
    public static let scale = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    
    /// 脉冲动画（用于吸引注意力）
    public static let pulse = Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)
    
    /// 呼吸动画（用于加载状态）
    public static let breathing = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    
    // MARK: - 列表动画
    
    /// 列表项入场动画（带延迟）
    public static func listItemAppear(index: Int, baseDelay: Double = 0.03) -> Animation {
        return Animation
            .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)
            .delay(Double(index) * baseDelay)
    }
    
    /// 错落入场动画（更有层次感）
    public static func staggeredAppear(index: Int, totalItems: Int = 10) -> Animation {
        let maxDelay: Double = 0.3
        let delay = min(Double(index) * 0.05, maxDelay)
        return Animation
            .spring(response: 0.45, dampingFraction: 0.7, blendDuration: 0)
            .delay(delay)
    }
}

// MARK: - 视图动画修饰符
extension View {
    /// 应用动画
    public func animated(_ animation: Animation = .default) -> some View {
        self.animation(animation, value: UUID())
    }
    
    /// 应用弹性动画
    public func springAnimated() -> some View {
        self.animation(AnimationHelper.spring, value: UUID())
    }
    
    /// 应用丝滑弹性动画
    public func silkyAnimated() -> some View {
        self.animation(AnimationHelper.silkySpring, value: UUID())
    }
    
    /// 应用快速动画
    public func fastAnimated() -> some View {
        self.animation(AnimationHelper.fast, value: UUID())
    }
    
    /// 应用列表项入场动画
    public func listItemAnimation(index: Int) -> some View {
        self.animation(AnimationHelper.listItemAppear(index: index), value: UUID())
    }
}

// MARK: - 过渡效果
extension AnyTransition {
    /// 丝滑滑入过渡（从底部）
    public static var silkySlideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
    
    /// 丝滑滑入过渡（从右侧）
    public static var silkySlideRight: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// 缩放淡入过渡
    public static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
    }
    
    /// 弹出过渡（用于模态、弹窗）
    public static var popup: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.85).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }
    
    /// 卡片入场过渡
    public static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.95)),
            removal: .opacity
        )
    }
}

// MARK: - 动画状态包装器
/// 用于管理入场动画状态
@propertyWrapper
public struct AnimatedAppear<Value: Equatable>: DynamicProperty {
    @State private var hasAppeared = false
    private let from: Value
    private let to: Value
    private let animation: Animation
    
    public init(from: Value, to: Value, animation: Animation = AnimationHelper.silkySpring) {
        self.from = from
        self.to = to
        self.animation = animation
    }
    
    public var wrappedValue: Value {
        hasAppeared ? to : from
    }
    
    public var projectedValue: Binding<Bool> {
        Binding(
            get: { hasAppeared },
            set: { newValue in
                withAnimation(animation) {
                    hasAppeared = newValue
                }
            }
        )
    }
}

// MARK: - 入场动画视图修饰符
struct AppearAnimationModifier: ViewModifier {
    let animation: Animation
    let delay: Double
    
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(animation) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    /// 添加入场动画效果
    public func appearAnimation(
        animation: Animation = AnimationHelper.silkySpring,
        delay: Double = 0
    ) -> some View {
        modifier(AppearAnimationModifier(animation: animation, delay: delay))
    }
    
    /// 添加列表入场动画（基于索引）
    public func listAppearAnimation(index: Int) -> some View {
        modifier(AppearAnimationModifier(
            animation: AnimationHelper.listItemAppear(index: index),
            delay: Double(index) * 0.03
        ))
    }
}

