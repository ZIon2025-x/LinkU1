import SwiftUI

// MARK: - 设计系统 - 现代简洁风格，符合 Apple Human Interface Guidelines

// MARK: 颜色系统（完全符合 Apple HIG，使用系统颜色）
struct AppColors {
    // 主色调 - 采用标准系统蓝色 (Apple System Blue)
    // 这种蓝色最符合 iOS 原生审美，且具有极高的辨识度与专业感
    static let primary = Color.blue
    static let primaryLight = Color.blue.opacity(0.1)
    
    // 渐变配色 - 采用系统蓝到深蓝色调的专业渐变
    static let gradientPrimary = [
        Color.blue,
        Color(red: 0.0, green: 0.35, blue: 0.85) // 稍微深一点的蓝色
    ]
    static let primaryGradient = LinearGradient(
        colors: gradientPrimary,
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // 品牌辅助色 - 采用与系统蓝完美契合的活力配色
    static let accent = Color.orange // 充满活力的强调色
    static let gold = Color(red: 1.0, green: 0.8, blue: 0.0) // 阳光金
    static let accentPink = Color.pink.opacity(0.05) // 极淡粉紫，用于柔和背景
    
    static let gradientSuccess = [
        Color.green,
        Color.green.opacity(0.8)
    ]
    static let gradientWarning = [
        Color.orange,
        Color.orange.opacity(0.8)
    ]
    
    // 背景色 - 采用更细腻的分层
    static let background = Color(UIColor.systemGroupedBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let cardBackground = Color(UIColor.systemBackground)
    static let elevatedBackground = Color(UIColor.tertiarySystemGroupedBackground)
    static let surface = Color(UIColor.systemBackground)
    
    // 文字颜色 - 降低对比度，减少视觉疲劳，提升高级感
    static let textPrimary = Color.primary.opacity(0.9)
    static let textSecondary = Color.secondary.opacity(0.7)
    static let textTertiary = Color.secondary.opacity(0.5)
    static let textQuaternary = Color(UIColor.quaternaryLabel)
    
    // 语义化颜色 - 使用系统颜色
    static let success = Color.green
    static let successLight = Color.green.opacity(0.1)
    static let warning = Color.orange
    static let warningLight = Color.orange.opacity(0.1)
    static let error = Color.red
    static let errorLight = Color.red.opacity(0.1)
    
    // 分隔线颜色 - 使用系统分隔线
    static let separator = Color(UIColor.separator)
    static let divider = Color(UIColor.separator).opacity(0.5)
    
    // 填充颜色 - 使用系统填充
    static let fill = Color(UIColor.systemFill)
    static let secondaryFill = Color(UIColor.secondarySystemFill)
    static let tertiaryFill = Color(UIColor.tertiarySystemFill)
}

// MARK: 间距系统（符合 Apple HIG 的 8pt 网格系统）
struct AppSpacing {
    static let xs: CGFloat = 4   // 极小间距
    static let sm: CGFloat = 8   // 小间距
    static let md: CGFloat = 16  // 标准间距（主要使用，符合 HIG）
    static let lg: CGFloat = 20  // 大间距（符合 HIG）
    static let xl: CGFloat = 24  // 超大间距（符合 HIG）
    static let xxl: CGFloat = 32 // 极大间距
    static let section: CGFloat = 40 // 区块间距
}

// MARK: 圆角系统（符合 Apple HIG，10-16px 范围）
struct AppCornerRadius {
    static let tiny: CGFloat = 4    // 极小圆角
    static let small: CGFloat = 8   // 小圆角
    static let medium: CGFloat = 12 // 标准圆角（主要使用，符合 HIG）
    static let large: CGFloat = 16  // 大圆角（符合 HIG）
    static let xlarge: CGFloat = 20 // 超大圆角
    static let pill: CGFloat = 999  // 胶囊形状
}

// MARK: 阴影系统（符合 Apple HIG，轻量阴影）
struct AppShadow {
    static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
    static let tiny = Shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    static let small = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    static let medium = Shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    static let large = Shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 8)
    
    // 弥散阴影 (Colored Soft Shadows)
    static func primary(opacity: Double = 0.25) -> Shadow {
        Shadow(color: AppColors.primary.opacity(opacity), radius: 15, x: 0, y: 8)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: 文本样式系统（符合 Apple HIG）
struct AppTypography {
    // 标题 - 使用系统字体大小
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.bold)
    static let title2 = Font.title2.weight(.semibold) // 主要标题
    static let title3 = Font.title3.weight(.semibold)
    
    // 正文 - 使用系统 body 字体
    static let body = Font.body // 主要正文
    static let bodyBold = Font.body.weight(.semibold)
    static let callout = Font.callout
    static let subheadline = Font.subheadline
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2
}

// MARK: - View Modifiers

// 卡片样式 - 符合 Apple HIG，使用材质效果
struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = AppCornerRadius.medium
    var shadow: Shadow = AppShadow.small
    var useMaterial: Bool = true // 默认使用材质
    var padding: CGFloat = AppSpacing.md
    var backgroundColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                Group {
                    if useMaterial {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor ?? AppColors.cardBackground)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .compositingGroup() // 组合渲染，确保圆角边缘干净
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = AppCornerRadius.medium, shadow: Shadow = AppShadow.small, useMaterial: Bool = false, padding: CGFloat = 0, backgroundColor: Color? = nil) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius, shadow: shadow, useMaterial: useMaterial, padding: padding, backgroundColor: backgroundColor))
    }
    
    /// 优化的卡片背景 - 确保圆角边缘干净，无灰色泄露，无容器感
    func cardBackground(cornerRadius: CGFloat = AppCornerRadius.medium, style: RoundedCornerStyle = .continuous) -> some View {
        self.background(AppColors.cardBackground) // 内容区域背景
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: style)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: style)
                            .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: style)) // 优化：确保圆角边缘干净
            .compositingGroup() // 组合渲染，确保圆角边缘干净
    }
    
    // 玻璃态效果
    func glassEffect(opacity: Double = 0.7) -> some View {
        self.background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .fill(.ultraThinMaterial)
        )
    }
    
    // 渐变背景
    func gradientBackground(_ colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> some View {
        self.background(
            LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: startPoint,
                endPoint: endPoint
            )
        )
    }
}

// 安全区填充
struct SafeAreaPadding: ViewModifier {
    var edges: Edge.Set = .all
    var padding: CGFloat = AppSpacing.md
    
    func body(content: Content) -> some View {
        content
            .padding(edges, padding)
    }
}

extension View {
    func safeAreaPadding(_ edges: Edge.Set = .all, _ padding: CGFloat = AppSpacing.md) -> some View {
        modifier(SafeAreaPadding(edges: edges, padding: padding))
    }
}

// 分隔线样式
struct SeparatorStyle: ViewModifier {
    var color: Color = AppColors.separator
    var height: CGFloat = 0.5
    
    func body(content: Content) -> some View {
        content
            .frame(height: height)
            .background(color)
    }
}

extension View {
    func separatorStyle(color: Color = AppColors.separator, height: CGFloat = 0.5) -> some View {
        modifier(SeparatorStyle(color: color, height: height))
    }
}

// MARK: - 按钮样式系统 - 丝滑流畅的交互体验

// 按钮样式 - 主要按钮（现代简洁设计 + 丝滑弹性动画）
struct PrimaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = AppCornerRadius.medium
    var padding: CGFloat = AppSpacing.md
    var useGradient: Bool = true
    var height: CGFloat = 50 // 标准按钮高度
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.bodyBold)
            .foregroundColor(.white)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if useGradient {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppColors.primary)
                    }
                }
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            // 使用丝滑的弹性动画
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

// 按钮样式 - 次要按钮（现代简洁设计 + 丝滑弹性动画）
struct SecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = AppCornerRadius.medium
    var height: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTypography.body)
            .fontWeight(.semibold)
            .foregroundColor(AppColors.primary)
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(configuration.isPressed ? AppColors.primary.opacity(0.15) : AppColors.primaryLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(AppColors.primary.opacity(configuration.isPressed ? 0.4 : 0.2), lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            // 使用丝滑的弹性动画
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

// 缩放按钮样式 - 用于卡片等点击效果（丝滑弹性动画）
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97  // 按下时的缩放比例
    var enableHaptic: Bool = true  // 是否启用触觉反馈
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            // 使用丝滑的弹性动画 - 更快的响应，更自然的回弹
            .animation(.spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed && enableHaptic {
                    HapticFeedback.selection()
                }
            }
    }
}

// 弹跳按钮样式 - 用于强调性操作（如收藏、点赞）
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            // 使用更有弹性的动画
            .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.light()
                }
            }
    }
}

// 轻触按钮样式 - 用于列表项、导航按钮（极轻量反馈）
struct LightTouchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            // 使用快速响应的弹性动画
            .animation(.spring(response: 0.2, dampingFraction: 0.8, blendDuration: 0), value: configuration.isPressed)
    }
}

// 图标按钮样式 - 用于工具栏图标按钮
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 44  // 符合HIG的最小触摸目标
    var backgroundColor: Color = .clear
    var pressedBackgroundColor: Color = AppColors.fill
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(configuration.isPressed ? pressedBackgroundColor : backgroundColor)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            // 使用弹性动画
            .animation(.spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.selection()
                }
            }
    }
}

// 浮动操作按钮样式
struct FloatingButtonStyle: ButtonStyle {
    var size: CGFloat = 56
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: AppColors.primary.opacity(configuration.isPressed ? 0.2 : 0.35),
                        radius: configuration.isPressed ? 8 : 12,
                        x: 0,
                        y: configuration.isPressed ? 4 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            // 使用丝滑弹性动画
            .animation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    HapticFeedback.medium()
                }
            }
    }
}

// 图标样式 - 统一 SF Symbols，符合 Apple HIG
struct IconStyle {
    static let small: CGFloat = 16
    static let medium: CGFloat = 20
    static let large: CGFloat = 24
    static let xlarge: CGFloat = 32
    
    // 统一使用 medium 线宽（符合 HIG）
    static func icon(_ name: String, size: CGFloat = medium, weight: Font.Weight = .medium) -> some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
            .symbolRenderingMode(.monochrome)
    }
}

// 列表行样式
struct ListRowStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.cardBackground)
    }
}

extension View {
    func listRowStyle() -> some View {
        modifier(ListRowStyle())
    }
}

// 圆角指定角
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
