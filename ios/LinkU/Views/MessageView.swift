//
//  MessageView.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

struct MessageView: View {
    @StateObject private var viewModel = MessageViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationView {
            Group {
                if let conversation = selectedConversation {
                    ChatDetailView(conversation: conversation, viewModel: viewModel)
                } else {
                    ConversationListView(viewModel: viewModel, selectedConversation: $selectedConversation)
                }
            }
            .navigationTitle("消息")
            .onAppear {
                viewModel.loadConversations()
            }
        }
    }
}

struct ConversationListView: View {
    @ObservedObject var viewModel: MessageViewModel
    @Binding var selectedConversation: Conversation?
    
    var body: some View {
        List(viewModel.conversations) { conversation in
            ConversationRowView(conversation: conversation)
                .onTapGesture {
                    selectedConversation = conversation
                    viewModel.loadMessages(conversationId: conversation.id)
                }
        }
        .refreshable {
            viewModel.loadConversations()
        }
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            AsyncImage(url: URL(string: conversation.otherUser.avatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.gray)
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.otherUser.username)
                        .font(.headline)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ChatDetailView: View {
    let conversation: Conversation
    @ObservedObject var viewModel: MessageViewModel
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(message: message, isCurrentUser: message.senderId == authViewModel.currentUser?.id)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 输入框
            HStack(spacing: 12) {
                TextField("输入消息...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(messageText.isEmpty ? Color.gray : Color.blue)
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle(conversation.otherUser.username)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private func sendMessage() {
        guard !messageText.isEmpty,
              let currentUser = authViewModel.currentUser else {
            return
        }
        
        viewModel.sendMessage(
            content: messageText,
            receiverId: conversation.otherUser.id,
            taskId: conversation.id
        )
        messageText = ""
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isCurrentUser ? .trailing : .leading)
            
            if !isCurrentUser {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timeString) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timeString
    }
}

#Preview {
    MessageView()
        .environmentObject(AuthViewModel())
}
