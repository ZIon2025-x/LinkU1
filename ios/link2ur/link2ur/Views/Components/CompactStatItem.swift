import SwiftUI

/// 紧凑统计项组件 - 用于卡片底部显示浏览量、回复数等
struct CompactStatItem: View {
    let icon: String
    let count: Int
    var color: Color = AppColors.textTertiary
    
    var body: some View {
        HStack(spacing: 4) {
            IconStyle.icon(icon, size: 12)
            Text(count.formatCount())
                .font(AppTypography.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
    }
}

