import SwiftUI

struct ChatView: View {
    let partnerId: String
    let partner: Contact?
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    init(partnerId: String, partner: Contact? = nil) {
        self.partnerId = partnerId
        self.partner = partner
        _viewModel = StateObject(wrappedValue: ChatViewModel(partnerId: partnerId, partner: partner))
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isFromCurrentUser: isMessageFromCurrentUser(message)
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        // 新消息时滚动到底部
                        if let lastMessage = viewModel.messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // 输入区域
                HStack(spacing: AppSpacing.sm) {
                    TextField("输入消息...", text: $messageText, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? AppColors.textSecondary : AppColors.primary)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.cardBackground)
            }
        }
        .navigationTitle(partner?.name ?? partner?.email ?? "聊天")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadMessages()
            viewModel.markAsRead()
            if let userId = getCurrentUserId() {
                viewModel.connectWebSocket(currentUserId: userId)
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let content = messageText
        messageText = ""
        
        viewModel.sendMessage(content: content) { success in
            if !success {
                messageText = content // 失败时恢复文本
            }
        }
    }
    
    private func getCurrentUserId() -> String? {
        // 从AppState获取当前用户ID
        if let userId = appState.currentUser?.id {
            return String(userId)
        }
        return nil
    }
    
    private func isMessageFromCurrentUser(_ message: Message) -> Bool {
        guard let senderId = message.senderId,
              let currentUserId = appState.currentUser?.id else {
            return false
        }
        return senderId == String(currentUserId)
    }
}

// 消息气泡组件
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        isFromCurrentUser
                        ? AppColors.primary
                        : AppColors.cardBackground
                    )
                    .cornerRadius(AppCornerRadius.medium)
                
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

