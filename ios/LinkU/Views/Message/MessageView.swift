import SwiftUI

struct MessageView: View {
    @StateObject private var viewModel = MessageViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    ProgressView()
                } else if viewModel.conversations.isEmpty {
                    EmptyStateView(
                        icon: "message.fill",
                        title: "暂无消息",
                        message: "还没有对话，快去和用户聊天吧！"
                    )
                } else {
                    List {
                        ForEach(viewModel.conversations) { contact in
                            NavigationLink(destination: ChatView(partnerId: contact.id, partner: contact)) {
                                ConversationRow(contact: contact)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("消息")
            .refreshable {
                viewModel.loadConversations()
            }
            .onAppear {
                if viewModel.conversations.isEmpty {
                    viewModel.loadConversations()
                }
            }
        }
    }
}

// 对话行组件
struct ConversationRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            AsyncImage(url: URL(string: contact.avatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryLight)
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.primary)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            // 信息
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name ?? contact.email ?? "用户")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                // 这里可以显示最后一条消息预览
                // 暂时显示时间
                if let lastTime = contact.lastMessageTime {
                    Text(formatTime(lastTime))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            // 未读数
            if let unreadCount = contact.unreadCount, unreadCount > 0 {
                ZStack {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 20, height: 20)
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}
