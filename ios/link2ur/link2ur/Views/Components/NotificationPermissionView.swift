import SwiftUI
import UserNotifications

/// 美化的通知权限请求视图 - 使用毛玻璃效果
struct NotificationPermissionView: View {
    @Binding var isPresented: Bool
    let onAllow: () -> Void
    let onNotNow: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景关闭
                    dismiss()
                }
            
            // 毛玻璃卡片
            VStack(spacing: 0) {
                // 图标区域
                ZStack {
                    // 渐变背景圆圈
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 12, x: 0, y: 4)
                    
                    // 通知图标
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.md)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
                
                // 标题
                Text(LocalizationKey.notificationEnableNotificationTitle.localized)
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.bottom, AppSpacing.sm)
                    .opacity(isAnimating ? 1.0 : 0.0)
                
                // 描述文字
                VStack(spacing: AppSpacing.sm) {
                    Text(LocalizationKey.notificationEnableNotificationMessage.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text(LocalizationKey.notificationEnableNotificationDescription.localized)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
                .opacity(isAnimating ? 1.0 : 0.0)
                
                // 按钮区域
                VStack(spacing: AppSpacing.md) {
                    // 允许按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isAnimating = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onAllow()
                            dismiss()
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text(LocalizationKey.notificationAllowNotification.localized)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppCornerRadius.medium)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .opacity(isAnimating ? 1.0 : 0.0)
                    
                    // 稍后按钮
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isAnimating = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onNotNow()
                            dismiss()
                        }
                    }) {
                        Text(LocalizationKey.notificationNotNow.localized)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(height: 50)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .opacity(isAnimating ? 1.0 : 0.0)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.large)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.large)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                AppColors.primary.opacity(0.2),
                                AppColors.primary.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            .scaleEffect(isAnimating ? 1.0 : 0.9)
            .opacity(isAnimating ? 1.0 : 0.0)
        }
        .transition(.opacity.combined(with: .scale))
        .onAppear {
            // 入场动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAnimating = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isPresented = false
        }
    }
}

// MARK: - 预览
struct NotificationPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationPermissionView(
            isPresented: .constant(true),
            onAllow: { },
            onNotNow: { }
        )
    }
}
