import SwiftUI

/// 通用统计项组件 - 用于个人主页、任务详情等展示数值统计
struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(value)
                .font(AppTypography.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

