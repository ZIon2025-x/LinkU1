import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 图标 - 分层系统蓝风格设计
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 70, height: 70)
                    .scaleEffect(isAnimating ? 0.9 : 1.0)
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.primary)
                    .offset(y: isAnimating ? -5 : 0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}

