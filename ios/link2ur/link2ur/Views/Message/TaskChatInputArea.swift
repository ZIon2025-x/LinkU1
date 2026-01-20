import SwiftUI
import UIKit

/// 任务聊天输入区域
/// 支持多行输入（1-5行）、action menu、任务关闭状态
struct TaskChatInputArea: View {
    @Binding var messageText: String
    let isSending: Bool
    
    @Binding var showActionMenu: Bool
    let isTaskClosed: Bool
    let isInputDisabled: Bool // ✅ 修复：当前未使用（保留接口兼容性）
    let closedStatusText: String
    
    var isInputFocused: FocusState<Bool>.Binding
    
    let onSend: () -> Void
    let onToggleActionMenu: () -> Void // ✅ 新增：把➕按钮的逻辑交给外层处理
    let onOpenImagePicker: () -> Void
    let onOpenTaskDetail: () -> Void
    let onViewLocationDetail: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.separator)
            
            if isTaskClosed {
                closedBar
            } else {
                inputBar
                
                if showActionMenu {
                    TaskChatActionMenu(
                        onImagePicker: onOpenImagePicker,
                        onTaskDetail: onOpenTaskDetail,
                        onViewLocationDetail: onViewLocationDetail
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            // ✅ 修复：pending_confirmation 不需要禁用输入，双方可以继续沟通
            // 移除了禁用输入提示
        }
        .background(AppColors.cardBackground)
    }
    
    private var closedBar: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16))
                .foregroundColor(AppColors.textTertiary)
            
            Text(closedStatusText)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textTertiary)
            
            Spacer()
            
            Button(action: onOpenTaskDetail) {
                Text(LocalizationKey.notificationViewDetails.localized)
                    .font(AppTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(AppColors.primaryLight)
                    .cornerRadius(AppCornerRadius.small)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
    }
    
    private var inputBar: some View {
        HStack(spacing: AppSpacing.sm) {
            // ➕ 更多功能按钮
            Button {
                // ✅ 修复：把逻辑交给外层处理，不要在这里直接 resign focus + toggle
                // ✅ 体验增强：添加触觉反馈
                HapticFeedback.buttonTap()
                onToggleActionMenu()
            } label: {
                ZStack {
                    Circle()
                        .fill(showActionMenu ? AppColors.primary : AppColors.cardBackground)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(showActionMenu ? Color.clear : AppColors.separator.opacity(0.5), lineWidth: 1)
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(showActionMenu ? .white : AppColors.textSecondary)
                        .rotationEffect(.degrees(showActionMenu ? 45 : 0))
                }
            }
            // ✅ 无障碍与可点区域：添加 contentShape 和 accessibilityLabel
            .contentShape(Rectangle())
            .accessibilityLabel(showActionMenu ? LocalizationKey.commonClose.localized : LocalizationKey.commonMore.localized)
            .accessibilityHint(showActionMenu ? "关闭功能菜单" : "打开功能菜单")
            
            // 输入框容器
            HStack(spacing: AppSpacing.sm) {
                TextField(
                    LocalizationKey.actionsEnterMessage.localized,
                    text: $messageText,
                    axis: .vertical
                )
                .font(AppTypography.body)
                .lineLimit(1...5) // ✅ 不要用 1.4 / 1.5 那种写法
                .focused(isInputFocused)
                .disabled(isSending || isInputDisabled) // ✅ 修复：当前 isInputDisabled 始终为 false
                .onSubmit {
                    onSend()
                }
                // ✅ 修复：不要在输入框内部直接收起菜单
                // 菜单的互斥控制应该交给外层 TaskChatView 做，避免"菜单收起动画"先发生，键盘动画后发生
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.pill)
                    .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
            )
            
            // 发送按钮 - 渐变设计
            Button {
                // ✅ 体验增强：添加触觉反馈
                HapticFeedback.sendMessage()
                onSend()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(
                                    colors: {
                                        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                                        return trimmed.isEmpty || isSending || isInputDisabled
                                            ? [AppColors.textTertiary, AppColors.textTertiary]
                                            : AppColors.gradientPrimary
                                    }()
                                ),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    if isSending {
                        CompactLoadingView()
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled({
                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty || isSending || isInputDisabled
            }())
            .opacity({
                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty || isSending || isInputDisabled ? 0.5 : 1.0
            }())
            // ✅ 无障碍与可点区域：添加 contentShape 和 accessibilityLabel
            .contentShape(Rectangle())
            .accessibilityLabel("发送消息")
            .accessibilityHint("点击发送当前输入的消息")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }
}
