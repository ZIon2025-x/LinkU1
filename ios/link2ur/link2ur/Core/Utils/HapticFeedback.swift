import UIKit

/// 触觉反馈工具 - 企业级用户反馈，提供丝滑自然的交互体验
public struct HapticFeedback {
    
    // MARK: - 反馈类型
    
    public enum FeedbackType {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case notification(UINotificationFeedbackGenerator.FeedbackType)
        case selection
    }
    
    // MARK: - 预热的触觉生成器（提高响应速度）
    
    private static let lightImpactGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()
    
    private static let mediumImpactGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        return generator
    }()
    
    private static let heavyImpactGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        return generator
    }()
    
    private static let softImpactGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        return generator
    }()
    
    private static let rigidImpactGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        return generator
    }()
    
    private static let selectionGenerator: UISelectionFeedbackGenerator = {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        return generator
    }()
    
    private static let notificationGenerator: UINotificationFeedbackGenerator = {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        return generator
    }()
    
    // MARK: - 触发反馈
    
    /// 触发触觉反馈
    public static func trigger(_ type: FeedbackType) {
        switch type {
        case .impact(let style):
            switch style {
            case .light:
                lightImpactGenerator.impactOccurred()
                lightImpactGenerator.prepare()
            case .medium:
                mediumImpactGenerator.impactOccurred()
                mediumImpactGenerator.prepare()
            case .heavy:
                heavyImpactGenerator.impactOccurred()
                heavyImpactGenerator.prepare()
            case .soft:
                softImpactGenerator.impactOccurred()
                softImpactGenerator.prepare()
            case .rigid:
                rigidImpactGenerator.impactOccurred()
                rigidImpactGenerator.prepare()
            @unknown default:
                let generator = UIImpactFeedbackGenerator(style: style)
                generator.impactOccurred()
            }
            
        case .notification(let notificationType):
            notificationGenerator.notificationOccurred(notificationType)
            notificationGenerator.prepare()
            
        case .selection:
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        }
    }
    
    // MARK: - 基础反馈
    
    /// 轻触反馈 - 用于普通按钮点击
    public static func light() {
        trigger(.impact(.light))
    }
    
    /// 中等触觉反馈 - 用于重要操作
    public static func medium() {
        trigger(.impact(.medium))
    }
    
    /// 重触觉反馈 - 用于关键操作确认
    public static func heavy() {
        trigger(.impact(.heavy))
    }
    
    /// 柔和触觉反馈 - 用于滑动、拖拽等连续操作
    public static func soft() {
        trigger(.impact(.soft))
    }
    
    /// 刚性触觉反馈 - 用于碰撞、边界效果
    public static func rigid() {
        trigger(.impact(.rigid))
    }
    
    // MARK: - 通知反馈
    
    /// 成功反馈 - 用于操作成功
    public static func success() {
        trigger(.notification(.success))
    }
    
    /// 警告反馈 - 用于警告提示
    public static func warning() {
        trigger(.notification(.warning))
    }
    
    /// 错误反馈 - 用于错误提示
    public static func error() {
        trigger(.notification(.error))
    }
    
    /// 选择反馈 - 用于选项切换
    public static func selection() {
        trigger(.selection)
    }
    
    // MARK: - 场景化反馈
    
    /// 按钮点击反馈
    public static func buttonTap() {
        light()
    }
    
    /// 卡片点击反馈
    public static func cardTap() {
        selection()
    }
    
    /// 列表项选择反馈
    public static func listSelect() {
        selection()
    }
    
    /// 开关切换反馈
    public static func toggle() {
        soft()
    }
    
    /// 滑块滑动反馈
    public static func slider() {
        soft()
    }
    
    /// 滑块到达边界反馈
    public static func sliderBoundary() {
        rigid()
    }
    
    /// 下拉刷新触发反馈
    public static func pullToRefresh() {
        medium()
    }
    
    /// 删除操作反馈
    public static func delete() {
        medium()
    }
    
    /// 收藏/取消收藏反馈
    public static func favorite() {
        light()
    }
    
    /// 点赞反馈
    public static func like() {
        light()
    }
    
    /// 发送消息反馈
    public static func sendMessage() {
        light()
    }
    
    /// 页面切换反馈
    public static func pageChange() {
        selection()
    }
    
    /// Tab切换反馈
    public static func tabSwitch() {
        selection()
    }
    
    /// 弹窗出现反馈
    public static func popup() {
        light()
    }
    
    /// 弹窗关闭反馈
    public static func dismiss() {
        soft()
    }
    
    /// 长按触发反馈
    public static func longPress() {
        medium()
    }
    
    /// 拖拽开始反馈
    public static func dragStart() {
        light()
    }
    
    /// 拖拽结束/放下反馈
    public static func dragEnd() {
        soft()
    }
    
    /// 边界碰撞反馈（如ScrollView到顶/底）
    public static func boundary() {
        rigid()
    }
    
    // MARK: - 预热
    
    /// 预热所有触觉生成器（建议在App启动时调用）
    public static func prepareAll() {
        _ = lightImpactGenerator
        _ = mediumImpactGenerator
        _ = heavyImpactGenerator
        _ = softImpactGenerator
        _ = rigidImpactGenerator
        _ = selectionGenerator
        _ = notificationGenerator
    }
}

