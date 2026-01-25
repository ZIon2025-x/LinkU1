import SwiftUI
import UIKit

/// 任务聊天输入区域
/// 支持多行输入（1-5行）、action menu、任务关闭状态、字数上限 500
struct TaskChatInputArea: View {
    @Binding var messageText: String
    let isSending: Bool
    
    @Binding var showActionMenu: Bool
    let isTaskClosed: Bool
    let isInputDisabled: Bool
    let closedStatusText: String
    
    var isInputFocused: FocusState<Bool>.Binding
    
    let onSend: () -> Void
    let onToggleActionMenu: () -> Void
    let onOpenImagePicker: () -> Void
    let onOpenTaskDetail: () -> Void
    let onViewLocationDetail: (() -> Void)?
    
    private let maxMessageLength = 500
    private let showCharCountThreshold = 400
    
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
        VStack(alignment: .leading, spacing: 4) {
            if isSending {
                Text(LocalizationKey.notificationSending.localized)
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.textTertiary)
            }
            HStack(spacing: AppSpacing.sm) {
                Button {
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
                .contentShape(Rectangle())
                .accessibilityLabel(showActionMenu ? LocalizationKey.commonClose.localized : LocalizationKey.commonMore.localized)
                .accessibilityHint(showActionMenu ? "关闭功能菜单" : "打开功能菜单")
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: AppSpacing.sm) {
                        TextField(
                            LocalizationKey.actionsEnterMessage.localized,
                            text: $messageText,
                            axis: .vertical
                        )
                        .font(AppTypography.body)
                        .lineLimit(1...5)
                        .focused(isInputFocused)
                        .disabled(isSending || isInputDisabled)
                        .onSubmit { onSend() }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, 10)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.pill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.pill)
                            .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                    )
                    if messageText.count > showCharCountThreshold {
                        Text("\(messageText.count)/\(maxMessageLength)")
                            .font(AppTypography.caption2)
                            .foregroundColor(messageText.count >= maxMessageLength ? AppColors.error : AppColors.textTertiary)
                            .padding(.trailing, AppSpacing.xs)
                    }
                }
                
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
            .onChange(of: messageText) { newValue in
                if newValue.count > maxMessageLength {
                    messageText = String(newValue.prefix(maxMessageLength))
                }
            }
        }
    }
}
