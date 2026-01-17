import SwiftUI

/// 紧凑统计项组件 - 用于卡片底部显示浏览量、回复数等
struct CompactStatItem: View {
    let icon: String
    let count: Int
    var color: Color = AppColors.textTertiary
    var isActive: Bool = false
    var activeColor: Color = AppColors.primary
    
    var body: some View {
        HStack(spacing: 4) {
            IconStyle.icon(isActive ? "\(icon).fill" : icon, size: 12)
            Text(count.formatCount())
                .font(AppTypography.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(isActive ? activeColor : color)
    }
}

