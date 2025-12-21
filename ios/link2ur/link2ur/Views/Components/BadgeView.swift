import SwiftUI

/// 通用标签组件 - 用于展示置顶、精选、分类等小标签
struct BadgeView: View {
    let text: String
    let icon: String?
    let color: Color
    
    init(text: String, icon: String? = nil, color: Color) {
        self.text = text
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: icon != nil ? 3 : 0) {
            if let icon = icon {
                IconStyle.icon(icon, size: 9, weight: .semibold)
            }
            Text(text)
                .font(icon != nil ? .system(size: 10, weight: .semibold) : AppTypography.caption2)
                .fontWeight(icon != nil ? .semibold : .medium)
        }
        .foregroundColor(icon != nil ? .white : color)
        .padding(.horizontal, icon != nil ? 6 : AppSpacing.sm)
        .padding(.vertical, icon != nil ? 3 : AppSpacing.xs)
        .background(icon != nil ? color : color.opacity(0.15))
        .cornerRadius(icon != nil ? AppCornerRadius.tiny : AppCornerRadius.small)
    }
}

