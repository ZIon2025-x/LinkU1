import SwiftUI

struct NotificationListView: View {
    @StateObject private var viewModel = NotificationViewModel()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ErrorStateView(
                    message: error,
                    retryAction: {
                        viewModel.loadNotifications()
                    }
                )
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(
                    icon: "bell.fill",
                    title: "暂无通知",
                    message: "还没有收到任何通知消息"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.notifications) { notification in
                            // 判断是否是任务相关的通知，并提取任务ID
                            if isTaskRelated(notification: notification), let taskId = extractTaskId(from: notification) {
                                NavigationLink(destination: TaskDetailView(taskId: taskId)) {
                                    NotificationRow(notification: notification)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        // 点击时立即标记为已读
                                        print("🔔 [NotificationListView] 点击任务通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                        if notification.isRead == 0 {
                                            print("🔔 [NotificationListView] 标记为已读，ID: \(notification.id)")
                                            viewModel.markAsRead(notificationId: notification.id)
                                        }
                                    }
                                )
                            } else {
                                NotificationRow(notification: notification)
                                    .onTapGesture {
                                        // 标记为已读
                                        print("🔔 [NotificationListView] 点击普通通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                        if notification.isRead == 0 {
                                            print("🔔 [NotificationListView] 标记为已读，ID: \(notification.id)")
                                            viewModel.markAsRead(notificationId: notification.id)
                                        }
                                        // 如果有链接，可以跳转
                                        if let link = notification.link, !link.isEmpty {
                                            // 处理链接跳转
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            viewModel.loadNotifications()
        }
        .onAppear {
            if viewModel.notifications.isEmpty {
                viewModel.loadNotifications()
            }
        }
    }
    
    /// 判断通知是否是任务相关的
    private func isTaskRelated(notification: SystemNotification) -> Bool {
        guard let type = notification.type else { return false }
        
        let lowercasedType = type.lowercased()
        
        // 检查是否是任务相关的通知类型
        // 后端任务通知类型包括：task_application, task_approved, task_completed, task_confirmation, task_cancelled 等
        if lowercasedType.contains("task") {
            return true
        }
        
        return false
    }
    
    /// 从通知中提取任务ID
    private func extractTaskId(from notification: SystemNotification) -> Int? {
        guard let type = notification.type else { return notification.relatedId }
        
        let lowercasedType = type.lowercased()
        
        // 对于 task_application 类型，related_id 可能是 application_id 或 task_id
        // 但根据后端代码，如果没有 application_id，会使用 task.id
        // 对于其他任务通知类型，related_id 就是 task_id
        if lowercasedType == "task_application" {
            // task_application 的 related_id 可能是 application_id，需要特殊处理
            // 但为了简化，我们假设如果有 related_id，就尝试跳转
            // 如果后端返回的是 application_id，可能需要额外处理
            return notification.relatedId
        } else if lowercasedType.contains("task") {
            // 其他任务相关通知，related_id 就是 task_id
            return notification.relatedId
        }
        
        return nil
    }
}

struct NotificationRow: View {
    let notification: SystemNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 头像/图标
            ZStack {
                Circle()
                    .fill(AppColors.primaryLight)
                    .frame(width: 50, height: 50)
                Image(systemName: "bell.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 20))
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: 6) {
                // 标题和时间
                HStack(alignment: .top) {
                    Text(notification.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatTime(notification.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if notification.isRead == 0 {
                            Circle()
                                .fill(AppColors.error)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // 内容预览
                Text(notification.content)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: AppCornerRadius.medium)
        .opacity(notification.isRead == 1 ? 0.7 : 1.0)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

