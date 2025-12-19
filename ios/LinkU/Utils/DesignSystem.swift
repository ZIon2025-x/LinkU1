import SwiftUI

// 设计系统 - 颜色定义
struct AppColors {
    // 主色调
    static let primary = Color(red: 0.0, green: 0.48, blue: 1.0) // #007AFF
    static let primaryLight = Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1)
    
    // 辅助色
    static let secondary = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
    static let background = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.systemBackground)
    
    // 语义化颜色
    static let success = Color(red: 0.20, green: 0.78, blue: 0.35) // #34C759
    static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500
    static let error = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
    
    // 文字颜色
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
}

// 设计系统 - 间距
struct AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

// 设计系统 - 圆角
struct AppCornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xlarge: CGFloat = 24
}

// 设计系统 - 阴影
struct AppShadow {
    static let small = Shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    static let medium = Shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    static let large = Shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// ViewModifier - 卡片样式
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

