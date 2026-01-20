import SwiftUI
import UIKit

/// 任务聊天功能菜单
/// 可以复用现有的 ChatActionMenuView 逻辑
struct TaskChatActionMenu: View {
    let onImagePicker: () -> Void
    let onTaskDetail: () -> Void
    let onViewLocationDetail: (() -> Void)?
    
    init(
        onImagePicker: @escaping () -> Void,
        onTaskDetail: @escaping () -> Void,
        onViewLocationDetail: (() -> Void)? = nil
    ) {
        self.onImagePicker = onImagePicker
        self.onTaskDetail = onTaskDetail
        self.onViewLocationDetail = onViewLocationDetail
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.separator.opacity(0.3))
            
            HStack(spacing: AppSpacing.xl) {
                // 上传图片
                ChatActionButton(
                    icon: "photo.fill",
                    title: LocalizationKey.notificationImage.localized,
                    color: AppColors.success,
                    action: onImagePicker
                )
                
                // 查看任务详情
                ChatActionButton(
                    icon: "doc.text.fill",
                    title: LocalizationKey.notificationTaskDetail.localized,
                    color: AppColors.primary,
                    action: onTaskDetail
                )
                
                // 详细地址（如果有）
                if let onViewLocationDetail = onViewLocationDetail {
                    ChatActionButton(
                        icon: "mappin.circle.fill",
                        title: LocalizationKey.notificationDetailAddress.localized,
                        color: AppColors.warning,
                        action: onViewLocationDetail
                    )
                }
                
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.cardBackground)
    }
    
    // 聊天功能按钮
    struct ChatActionButton: View {
        let icon: String
        let title: String
        let color: Color
        let action: () -> Void
        
        var body: some View {
            Button {
                // ✅ 体验增强：添加触觉反馈
                HapticFeedback.buttonTap()
                action()
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(color.opacity(0.15))
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(color)
                    }
                    
                    Text(title)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .buttonStyle(ScaleButtonStyle())
            // ✅ 无障碍与可点区域：添加 contentShape 和 accessibilityLabel
            .contentShape(Rectangle())
            .accessibilityLabel(title)
            .accessibilityHint("点击\(title)")
        }
    }
}
