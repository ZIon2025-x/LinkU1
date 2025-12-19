import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 图标 - 简洁设计
            ZStack {
                Circle()
                    .fill(AppColors.primaryLight)
                    .frame(width: 80, height: 80)
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}

