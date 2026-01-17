import SwiftUI

// MARK: - 核心调色板 (Modern Brand Palette)
struct AppColors {
    // 主品牌色 - 更加深邃且有活力的蓝色
    static let primary = Color(red: 0.15, green: 0.35, blue: 0.95) // #2659F2
    static let primaryGradient = LinearGradient(
        colors: [primary, Color(red: 0.25, green: 0.55, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let primaryLight = primary.opacity(0.12)
    
    // 品牌辅助色
    static let secondary = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let accentPurple = Color(red: 0.45, green: 0.35, blue: 0.95)
    static let accentOrange = Color(red: 1.0, green: 0.5, blue: 0.2)
    static let accentPink = Color(red: 1.0, green: 0.3, blue: 0.5)
    
    // 背景色系统
    static let background = Color(UIColor.systemGroupedBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemGroupedBackground)
    static let cardBackground = Color(UIColor.systemBackground)
    
    // 语义化颜色
    static let success = Color(red: 0.15, green: 0.75, blue: 0.45)
    static let warning = Color(red: 1.0, green: 0.65, blue: 0.0)
    static let error = Color(red: 0.95, green: 0.3, blue: 0.3)
    
    // 文字颜色
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.6)
}

// MARK: - 布局规范 (Layout Constants)
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

struct AppCornerRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32
    static let round: CGFloat = 999
}

// MARK: - 阴影系统 (Shadow System)
struct AppShadow {
    // 小阴影
    static let small = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
    
    // 中等阴影
    static let medium = Shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    
    // 弥散阴影 (Colored Soft Shadows)
    static func soft(color: Color = Color.black.opacity(0.06)) -> Shadow {
        Shadow(color: color, radius: 10, x: 0, y: 5)
    }
    
    static let card = Shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: 8)
    static let floating = Shadow(color: Color.black.opacity(0.15), radius: 25, x: 0, y: 12)
    
    // 品牌色投影
    static func primary(opacity: Double = 0.25) -> Shadow {
        Shadow(color: AppColors.primary.opacity(opacity), radius: 12, x: 0, y: 6)
    }
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - 视图修饰符 (View Modifiers)

/// 现代卡片样式
struct CardStyle: ViewModifier {
    var radius: CGFloat = AppCornerRadius.medium
    var shadow: Shadow = AppShadow.card
    
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .cornerRadius(radius)
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

/// 玻璃拟态样式
struct GlassStyle: ViewModifier {
    var cornerRadius: CGFloat = AppCornerRadius.medium
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

/// 呼吸感缩放点击效果
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func cardStyle(radius: CGFloat = AppCornerRadius.medium, shadow: Shadow = AppShadow.card) -> some View {
        modifier(CardStyle(radius: radius, shadow: shadow))
    }
    
    func glassStyle(cornerRadius: CGFloat = AppCornerRadius.medium) -> some View {
        modifier(GlassStyle(cornerRadius: cornerRadius))
    }
    
    func bouncyButton() -> some View {
        buttonStyle(BouncyButtonStyle())
    }
}

// MARK: - Color 扩展
extension Color {
    /// 从十六进制字符串创建颜色
    /// - Parameter hex: 十六进制颜色字符串，支持 "FF6B6B" 或 "#FF6B6B" 格式
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
