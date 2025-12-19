import SwiftUI

// 错误状态视图组件 - 更现代的设计
struct ErrorStateView: View {
    let message: String
    let retryAction: (() -> Void)?
    
    init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // 错误图标 - 简洁设计
            ZStack {
                Circle()
                    .fill(AppColors.errorLight)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(AppColors.error)
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("出错了")
                    .font(AppTypography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("重试")
                            .font(AppTypography.bodyBold)
                    }
                }
                .buttonStyle(PrimaryButtonStyle(useGradient: true))
                .padding(.top, AppSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
    }
}

