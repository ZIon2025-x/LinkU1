import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 图标 - 简洁设计，带微动画
            ZStack {
                Circle()
                    .fill(AppColors.primaryLight)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .offset(y: isAnimating ? -4 : 0)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }
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
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }
}

