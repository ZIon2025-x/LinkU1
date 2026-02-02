import SwiftUI

struct NotificationMenuView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appState: AppState
    @State private var showNotifications = false
    @State private var showCustomerService = false
    @State private var showTaskChats = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 菜单项
            VStack(spacing: 0) {
                // 通知
                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showNotifications = true
                    }
                }) {
                    NotificationMenuItem(
                        icon: "bell.fill",
                        title: LocalizationKey.notificationNotifications.localized,
                        subtitle: LocalizationKey.notificationSystemMessage.localized,
                        color: AppColors.primary
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 60)
                
                // 客服中心
                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showCustomerService = true
                    }
                }) {
                    NotificationMenuItem(
                        icon: "headphones",
                        title: LocalizationKey.notificationCustomerService.localized,
                        subtitle: LocalizationKey.notificationContactService.localized,
                        color: AppColors.success
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Divider()
                    .padding(.leading, 60)
                
                // 任务聊天
                Button(action: {
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showTaskChats = true
                    }
                }) {
                    NotificationMenuItem(
                        icon: "message.fill",
                        title: LocalizationKey.notificationTaskChat.localized,
                        subtitle: LocalizationKey.notificationTaskChatList.localized,
                        color: AppColors.warning
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppShadow.medium.color, radius: AppShadow.medium.radius, x: AppShadow.medium.x, y: AppShadow.medium.y)
        .sheet(isPresented: $showNotifications) {
            NotificationListView()
        }
        .sheet(isPresented: $showCustomerService) {
            CustomerServiceView(onDismiss: { showCustomerService = false })
                .environmentObject(appState)
        }
        .sheet(isPresented: $showTaskChats) {
            TaskChatListView()
                .environmentObject(appState)
        }
    }
}

struct NotificationMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .contentShape(Rectangle())
    }
}

