import SwiftUI
import Combine

struct TaskChatListView: View {
    @StateObject private var viewModel = TaskChatViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.taskChats.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.taskChats.isEmpty {
                ErrorStateView(
                    message: error,
                    retryAction: {
                        viewModel.loadTaskChats()
                    }
                )
            } else if viewModel.taskChats.isEmpty {
                EmptyStateView(
                    icon: "message.fill",
                    title: LocalizationKey.notificationNoTaskChat.localized,
                    message: LocalizationKey.notificationNoTaskChatMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.taskChats) { taskChat in
                            NavigationLink(destination: TaskChatView(taskId: taskChat.id, taskTitle: taskChat.displayTitle, taskChat: taskChat)
                                .environmentObject(appState)) {
                                TaskChatRow(taskChat: taskChat, currentUserId: getCurrentUserId())
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            viewModel.loadTaskChats()
        }
        .onAppear {
            if viewModel.taskChats.isEmpty {
                viewModel.loadTaskChats()
            }
        }
    }
    
    private func getCurrentUserId() -> String? {
        if let userId = appState.currentUser?.id {
            return String(userId)
        }
        return nil
    }
}

struct TaskChatRow: View {
    let taskChat: TaskChatItem
    let currentUserId: String?
    
    // 任务类型图标映射
    private let taskTypeIcons: [String: String] = [
        "Housekeeping": "house.fill",
        "Campus Life": "graduationcap.fill",
        "Second-hand & Rental": "bag.fill",
        "Errand Running": "figure.run",
        "Skill Service": "wrench.and.screwdriver.fill",
        "Social Help": "person.2.fill",
        "Transportation": "car.fill",
        "Pet Care": "pawprint.fill",
        "Life Convenience": "cart.fill",
        "Other": "square.grid.2x2.fill"
    ]
    
    // 按任务来源或 taskType 获取图标
    private func getTaskIcon() -> String {
        let source = taskChat.taskSource ?? "normal"
        switch source {
        case "flea_market": return "bag.fill"
        case "expert_service": return "star.circle.fill"
        case "expert_activity": return "person.3.fill"
        default:
            if let taskType = taskChat.taskType, let icon = taskTypeIcons[taskType] {
                return icon
            }
            return "message.fill"
        }
    }
    
    /// 按任务来源与用户身份返回角色称谓
    private func roleLabel(currentUserId: String) -> String {
        let source = taskChat.taskSource ?? "normal"
        if taskChat.posterId == currentUserId {
            switch source {
            case "flea_market": return LocalizationKey.taskDetailBuyer.localized
            case "expert_service": return LocalizationKey.myTasksRoleUser.localized
            case "expert_activity": return LocalizationKey.myTasksRoleParticipant.localized
            default: return LocalizationKey.notificationPoster.localized
            }
        }
        if taskChat.takerId == currentUserId {
            switch source {
            case "flea_market": return LocalizationKey.taskDetailSeller.localized
            case "expert_service": return LocalizationKey.myTasksRoleExpert.localized
            case "expert_activity": return LocalizationKey.myTasksRoleOrganizer.localized
            default: return LocalizationKey.notificationTaker.localized
            }
        }
        if let expertCreatorId = taskChat.expertCreatorId, expertCreatorId == currentUserId {
            switch source {
            case "expert_activity": return LocalizationKey.myTasksRoleOrganizer.localized
            case "expert_service": return LocalizationKey.myTasksRoleExpert.localized
            default: return LocalizationKey.notificationExpert.localized
            }
        }
        return LocalizationKey.notificationParticipant.localized
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
            // 任务图标/头像 - 如果有图片则显示图片，否则显示图标
            ZStack {
                let imageSize: CGFloat = DeviceInfo.isPad ? 72 : 56
                // 如果有任务图片，显示第一张图片
                if let images = taskChat.images, !images.isEmpty, let firstImageUrl = images.first {
                    AsyncImageView(
                        urlString: firstImageUrl,
                        placeholder: Image(systemName: getTaskIcon()),
                        width: imageSize,
                        height: imageSize,
                        contentMode: .fill,
                        cornerRadius: AppCornerRadius.medium
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                    .shadow(color: AppColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                } else {
                    // 如果没有图片，显示图标
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: imageSize, height: imageSize)
                        .shadow(color: AppColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                        .overlay(
                            Image(systemName: getTaskIcon())
                                .foregroundColor(.white)
                                .font(.system(size: DeviceInfo.isPad ? 32 : 24, weight: .semibold))
                        )
                }
                
                // 未读红点标记
                if let unreadCount = taskChat.unreadCount, unreadCount > 0 {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: DeviceInfo.isPad ? 16 : 12, height: DeviceInfo.isPad ? 16 : 12)
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBackground, lineWidth: 2)
                        )
                        .offset(x: DeviceInfo.isPad ? 26 : 20, y: DeviceInfo.isPad ? -26 : -20)
                }
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.sm : AppSpacing.xs) {
                // 标题和时间
                HStack(alignment: .center, spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                    Text(taskChat.displayTitle)
                        .font(DeviceInfo.isPad ? AppTypography.bodyBold : AppTypography.body)
                        .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .bold : .semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 时间和未读数在同一行
                    HStack(spacing: DeviceInfo.isPad ? 12 : 8) {
                        // 优先使用 lastMessageTime，如果没有则使用 lastMessage.createdAt
                        if let lastTime = taskChat.lastMessageTime ?? taskChat.lastMessage?.createdAt {
                            Text(formatTime(lastTime))
                                .font(DeviceInfo.isPad ? AppTypography.caption : AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        
                        // 未读数 - 渐变背景
                        if let unreadCount = taskChat.unreadCount, unreadCount > 0 {
                            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                .font(DeviceInfo.isPad ? AppTypography.caption : AppTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, unreadCount > 9 ? (DeviceInfo.isPad ? 10 : 8) : (DeviceInfo.isPad ? 8 : 6))
                                .padding(.vertical, DeviceInfo.isPad ? 5 : 3)
                                .background(
                                    Capsule()
                                        .fill(AppColors.error)
                                )
                        }
                    }
                }
                
                // 角色信息（按任务来源显示称谓）
                if let currentUserId = currentUserId {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                        Text(roleLabel(currentUserId: currentUserId))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                // 最新消息预览（如果有，显示在角色信息下面）
                if let lastMessage = taskChat.lastMessage {
                    HStack(spacing: 4) {
                        // 如果有发送者名称，显示发送者名称
                        if let senderName = lastMessage.senderName, !senderName.isEmpty {
                            Text("\(senderName): ")
                                .font(AppTypography.caption)
                                .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .medium : .regular)
                                .foregroundColor(taskChat.unreadCount ?? 0 > 0 ? AppColors.textSecondary : AppColors.textTertiary)
                        } else {
                            // 如果没有发送者名称（系统消息），显示"系统: "
                            Text("\(LocalizationKey.notificationSystem.localized): ")
                                .font(AppTypography.caption)
                                .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .medium : .regular)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        
                        // 显示消息内容（只显示一行，超过的截断）
                        if let content = lastMessage.content, !content.isEmpty {
                            Text(content)
                                .font(AppTypography.caption)
                                .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .medium : .regular)
                                .foregroundColor(taskChat.unreadCount ?? 0 > 0 ? AppColors.textSecondary : AppColors.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            // 如果内容为空，显示默认提示
                            Text(LocalizationKey.notificationSystemMessage.localized)
                                .font(AppTypography.caption)
                                .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .medium : .regular)
                                .foregroundColor(AppColors.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// MARK: - 注意：TaskChatView 已迁移到 Views/Message/TaskChatView.swift
// 旧的 TaskChatView 定义已删除，请使用新的实现
// 如果需要查看旧实现，请查看 git 历史记录

