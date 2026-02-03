import SwiftUI

struct CustomerServiceView: View {
    /// 从 sheet 等模态打开时传入，用于显示「完成」并关闭；为 nil 时表示在 NavigationStack 内 push，不显示完成按钮
    var onDismiss: (() -> Void)? = nil
    
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CustomerServiceViewModel()
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @State private var messageText = ""
    @State private var lastMessageId: String?
    @State private var scrollWorkItem: DispatchWorkItem?
    @State private var showChatHistory = false // 显示对话历史
    @FocusState private var isInputFocused: Bool
    
    // 计算键盘避让的底部 padding
    private var keyboardPadding: CGFloat {
        guard keyboardObserver.keyboardHeight > 0 else { return 0 }
        return max(keyboardObserver.keyboardHeight - 60, 0)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                // 始终显示聊天界面
                VStack(spacing: 0) {
                    // 消息列表
                    if viewModel.isLoading && viewModel.messages.isEmpty && viewModel.chat != nil {
                        // 加载状态（仅在已连接时显示）
                        LoadingView(message: LocalizationKey.messagesLoadingMessages.localized)
                    } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty && viewModel.chat != nil {
                        // 使用统一的错误状态组件（仅在已连接时显示）
                        ErrorStateView(
                            message: errorMessage,
                            retryAction: {
                                if let chatId = viewModel.chat?.chatId {
                                    viewModel.loadMessages(chatId: chatId)
                                }
                            }
                        )
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    if viewModel.messages.isEmpty && viewModel.chat == nil {
                                        // 未连接状态 - 显示提示信息
                                        VStack(spacing: DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg) {
                                            Image(systemName: "message.fill")
                                                .font(.system(size: DeviceInfo.isPad ? 64 : 48))
                                                .foregroundColor(AppColors.textTertiary)
                                            
                                            Text(LocalizationKey.customerServiceWelcome.localized)
                                                .font(DeviceInfo.isPad ? AppTypography.title2 : AppTypography.title3)
                                                .foregroundColor(AppColors.textPrimary)
                                            
                                            Text(LocalizationKey.customerServiceStartConversation.localized)
                                                .font(DeviceInfo.isPad ? AppTypography.body : AppTypography.subheadline)
                                                .foregroundColor(AppColors.textSecondary)
                                                .multilineTextAlignment(.center)
                                            
                                            // 显示排队状态（如果有）
                                            if let queueStatus = viewModel.queueStatus {
                                                VStack(spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                                                    if let position = queueStatus.position {
                                                        Text(String(format: LocalizationKey.customerServiceQueuePosition.localized, position))
                                                            .font(DeviceInfo.isPad ? AppTypography.bodyBold : AppTypography.body)
                                                            .foregroundColor(AppColors.textSecondary)
                                                    }
                                                    if let waitTime = queueStatus.estimatedWaitTime {
                                                        Text(String(format: LocalizationKey.customerServiceEstimatedWait.localized, waitTime))
                                                            .font(DeviceInfo.isPad ? AppTypography.caption : AppTypography.caption)
                                                            .foregroundColor(AppColors.textTertiary)
                                                    }
                                                }
                                                .padding(DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                                                .background(AppColors.cardBackground)
                                                .cornerRadius(AppCornerRadius.medium)
                                            }
                                            
                                            // 显示错误信息（如果有）
                                            if let errorMessage = viewModel.errorMessage {
                                                Text(errorMessage)
                                                    .font(DeviceInfo.isPad ? AppTypography.body : AppTypography.subheadline)
                                                    .foregroundColor(AppColors.error)
                                                    .multilineTextAlignment(.center)
                                                    .padding(DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                                                    .background(AppColors.error.opacity(0.1))
                                                    .cornerRadius(AppCornerRadius.medium)
                                            }
                                        }
                                        .frame(maxWidth: DeviceInfo.isPad ? 600 : .infinity) // iPad上限制最大宽度
                                        .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                                        .padding(.top, DeviceInfo.isPad ? 150 : 100)
                                    } else {
                                        LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                                            // 欢迎消息
                                            if let service = viewModel.service {
                                                WelcomeMessageBubble(serviceName: service.name)
                                            }
                                            
                                            ForEach(viewModel.messages) { message in
                                                CustomerServiceMessageBubble(
                                                    message: message,
                                                    isFromCurrentUser: message.senderType == "user"
                                                )
                                                .id(message.id)
                                            }
                                        }
                                        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                                        .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                                        .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                                        .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                                    }
                                }
                                .padding(.bottom, keyboardPadding)
                            }
                            .refreshable {
                                if let chatId = viewModel.chat?.chatId {
                                    viewModel.loadMessages(chatId: chatId)
                                }
                            }
                            .onChange(of: viewModel.messages.count) { newCount in
                                if newCount > 0 {
                                    scrollToBottom(proxy: proxy, delay: 0.1)
                                }
                            }
                            .onChange(of: isInputFocused) { focused in
                                if focused && !viewModel.messages.isEmpty {
                                    scrollToBottom(proxy: proxy, delay: 0.3)
                                }
                            }
                            .onChange(of: keyboardObserver.keyboardHeight) { height in
                                if height > 0 && !viewModel.messages.isEmpty {
                                    scrollToBottom(proxy: proxy, delay: 0.1, animation: keyboardObserver.keyboardAnimation)
                                }
                            }
                        }
                    }
                    
                    // 输入区域 - 使用系统级键盘处理
                    if viewModel.chat?.isEnded == 1 {
                        // 对话已结束，显示提示信息
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text(LocalizationKey.customerServiceConversationEndedMessage.localized)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textTertiary)
                            
                            Spacer()
                            
                            // 重新连接按钮
                            Button(action: {
                                // 清空当前对话，重新连接
                                viewModel.chat = nil
                                viewModel.messages = []
                                viewModel.service = nil
                            }) {
                                Text(LocalizationKey.customerServiceNewConversation.localized)
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 6)
                                    .background(AppColors.primary)
                                    .cornerRadius(AppCornerRadius.small)
                            }
                        }
                        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .padding(.vertical, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                        .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                    } else {
                        // 正常输入区域
                        HStack(spacing: DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm) {
                            // 连接按钮（仅在未连接时显示）
                            if viewModel.chat == nil {
                                Button(action: {
                                    viewModel.connectToService { success in
                                        if success {
                                            // 连接成功，消息会自动加载
                                        }
                                    }
                                }) {
                                    if viewModel.isConnecting {
                                        CompactLoadingView()
                                    } else {
                                        Image(systemName: "phone.fill")
                                            .font(.title3)
                                            .foregroundColor(AppColors.primary)
                                    }
                                }
                                .disabled(viewModel.isConnecting)
                                .frame(width: 44, height: 44)
                            }
                            
                            TextField(LocalizationKey.customerServiceEnterMessage.localized, text: $messageText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(1...4)
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.send)
                                .disabled(viewModel.isSending || viewModel.chat == nil)
                                .onSubmit {
                                    sendMessage()
                                }
                            
                            Button(action: sendMessage) {
                                if viewModel.isSending {
                                    CompactLoadingView()
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(messageText.isEmpty ? AppColors.textSecondary : AppColors.primary)
                                }
                            }
                            .disabled(messageText.isEmpty || viewModel.isSending || viewModel.chat == nil)
                        }
                        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                        .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground)
                    }
                    // 使用系统级键盘处理，避免约束冲突
                    // .ignoresSafeArea(.keyboard, edges: .bottom)
                }
                
                // 连接中覆盖层
                if viewModel.isConnecting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: AppSpacing.md) {
                        CompactLoadingView()
                        Text(LocalizationKey.customerServiceConnecting.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.large)
                }
            }
            .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
            .navigationTitle(LocalizationKey.customerServiceCustomerService.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onDismiss = onDismiss {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(LocalizationKey.commonDone.localized) {
                            onDismiss()
                        }
                        .foregroundColor(AppColors.primary)
                    }
                }
                if viewModel.chat != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showChatHistory = true
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                    
                    // 仅当对话未结束时显示「结束对话」按钮（图标保持导航栏单行紧凑）
                    if viewModel.chat?.isEnded != 1 {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                viewModel.endChat { success in
                                    if success {
                                        messageText = ""
                                    }
                                }
                            }) {
                                Image(systemName: "phone.down.fill")
                                    .foregroundColor(AppColors.error)
                            }
                            .accessibilityLabel(LocalizationKey.customerServiceEndConversation.localized)
                        }
                    }
                } else if !viewModel.chats.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showChatHistory = true
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
            .enableSwipeBack()
            .sheet(isPresented: $showChatHistory) {
                ChatHistoryView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showRatingSheet) {
                RatingSheetView(viewModel: viewModel)
            }
            // 用户体验优化：点击空白区域隐藏键盘（使用 contentShape 确保点击区域覆盖整个视图）
            .contentShape(Rectangle())
            .onTapGesture {
                if isInputFocused {
                    isInputFocused = false
                    hideKeyboard()
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // 检查用户是否已登录（需要验证用户会话）
            let hasSessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil
            
            if !hasSessionId {
                viewModel.errorMessage = "请先登录后再使用客服功能"
                return
            }
            
            // 加载对话历史（已登录用户）
            viewModel.loadChats()
            
            // 不自动连接客服，让用户手动选择
            // 如果已有活动对话，则加载消息（不需要验证客服会话ID）
            if viewModel.chat != nil {
                // 只在消息为空时加载，避免重复加载
                if viewModel.messages.isEmpty, let chatId = viewModel.chat?.chatId {
                    viewModel.loadMessages(chatId: chatId)
                    viewModel.startMessagePolling()
                }
            }
        }
        .onDisappear {
            // 用户体验优化：视图消失时自动收起键盘
            isInputFocused = false
            // 清理错误状态
            viewModel.errorMessage = nil
            // 停止轮询
            viewModel.stopPolling()
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty, !viewModel.isSending else { return }
        guard viewModel.chat?.isEnded != 1 else {
            viewModel.errorMessage = LocalizationKey.customerServiceConversationEnded.localized
            return
        }
        
        let content = trimmedText
        messageText = "" // 立即清空输入框
        
        // 用户体验优化：发送消息后自动收起键盘
        isInputFocused = false
        
        viewModel.sendMessage(content: content) { success in
            if !success {
                // 失败时恢复文本
                DispatchQueue.main.async {
                    messageText = content
                }
            }
        }
    }
    
    /// 滚动到底部（带防抖和动画支持）
    private func scrollToBottom(proxy: ScrollViewProxy, delay: TimeInterval = 0, animation: Animation? = nil) {
        scrollWorkItem?.cancel()
        
        guard let lastMessage = viewModel.messages.last else { return }
        let messageId = lastMessage.id
        
        if messageId == lastMessageId && delay == 0 {
            return
        }
        
        lastMessageId = messageId
        
        let workItem = DispatchWorkItem {
            if let lastMessage = viewModel.messages.last {
                if let animation = animation {
                    withAnimation(animation) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        
        scrollWorkItem = workItem
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        } else {
            workItem.perform()
        }
    }
}

// 欢迎消息气泡
struct WelcomeMessageBubble: View {
    let serviceName: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(String(format: LocalizationKey.customerServiceConnected.localized, serviceName))
                    .font(AppTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(LocalizationKey.customerServiceWhatCanHelp.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.primaryLight)
            .cornerRadius(AppCornerRadius.medium)
            
            Spacer()
        }
    }
}

// 客服消息气泡
struct CustomerServiceMessageBubble: View {
    let message: CustomerServiceMessage
    let isFromCurrentUser: Bool
    
    // 判断是否是系统消息
    private var isSystemMessage: Bool {
        // 系统消息：senderType 为空或为 "system"，或者 messageType 为 "system"
        let senderType = message.senderType?.lowercased()
        let messageType = message.messageType?.lowercased()
        return senderType == nil || senderType == "system" || messageType == "system"
    }
    
    var body: some View {
        if isSystemMessage {
            // 系统消息样式 - 居中显示
            HStack {
                Spacer()
                
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(message.content)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.separator.opacity(0.3))
                .cornerRadius(AppCornerRadius.pill)
                
                Spacer()
            }
            .padding(.vertical, AppSpacing.xs)
        } else {
            // 普通消息样式
            HStack {
                if isFromCurrentUser {
                    Spacer()
                }
                
                VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: AppSpacing.xs) {
                    Group {
                        if isFromCurrentUser {
                            Text(message.content)
                                .font(AppTypography.body)
                                .foregroundColor(.white)
                                .padding(AppSpacing.sm)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(AppCornerRadius.medium)
                        } else {
                            Text(message.content)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                                .padding(AppSpacing.sm)
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppCornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                        .stroke(AppColors.divider, lineWidth: 0.5)
                                )
                        }
                    }
                    
                    if let createdAt = message.createdAt {
                        Text(formatTime(createdAt))
                            .font(AppTypography.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromCurrentUser ? .trailing : .leading)
                
                if !isFromCurrentUser {
                    Spacer()
                }
            }
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// MARK: - 对话历史视图
struct ChatHistoryView: View {
    @ObservedObject var viewModel: CustomerServiceViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoadingChats && viewModel.chats.isEmpty {
                    ScrollView {
                        ListSkeleton(itemCount: 5, itemHeight: 72, spacing: AppSpacing.sm)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                    }
                } else if viewModel.chats.isEmpty {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.textTertiary)
                        Text(LocalizationKey.customerServiceNoChatHistory.localized)
                            .font(AppTypography.title3)
                            .foregroundColor(AppColors.textSecondary)
                        Text(LocalizationKey.customerServiceStartNewConversation.localized)
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textTertiary)
                    }
                } else {
                    List {
                        ForEach(viewModel.chats) { chat in
                            ChatHistoryRow(chat: chat)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectChat(chat)
                                    dismiss()
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle(LocalizationKey.customerServiceChatHistory.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.commonDone.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 对话历史行
struct ChatHistoryRow: View {
    let chat: CustomerServiceChat
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像
            Circle()
                .fill(AppColors.primaryLight)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.primary)
                )
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(LocalizationKey.customerServiceServiceChat.localized)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    if let createdAt = chat.createdAt {
                        Text(formatTime(createdAt))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                HStack {
                    if chat.isEnded == 1 {
                        Text(LocalizationKey.customerServiceEnded.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(4)
                    } else {
                        Text(LocalizationKey.customerServiceInProgress.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.success)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(AppColors.success.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let totalMessages = chat.totalMessages {
                        Text(String(format: LocalizationKey.customerServiceTotalMessages.localized, totalMessages))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// MARK: - 评分界面
struct RatingSheetView: View {
    @ObservedObject var viewModel: CustomerServiceViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedRating = 5
    @State private var comment = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.xl) {
                // 标题
                VStack(spacing: AppSpacing.sm) {
                    Text(LocalizationKey.customerServiceRateService.localized)
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if let serviceName = viewModel.service?.name {
                        Text(LocalizationKey.customerServiceSatisfactionQuestion.localized(argument: serviceName))
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, AppSpacing.xl)
                
                // 评分选择
                VStack(spacing: AppSpacing.md) {
                    Text(LocalizationKey.customerServiceSelectRating.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    HStack(spacing: AppSpacing.lg) {
                        ForEach(1...5, id: \.self) { rating in
                            Button(action: {
                                selectedRating = rating
                            }) {
                                Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                                    .font(.system(size: 40))
                                    .foregroundColor(rating <= selectedRating ? .yellow : AppColors.textTertiary)
                            }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.lg)
                
                // 评论输入
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(LocalizationKey.customerServiceRatingContent.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    TextEditor(text: $comment)
                        .frame(height: 100)
                        .padding(AppSpacing.sm)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.divider, lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
                
                // 提交按钮
                Button(action: submitRating) {
                    if isSubmitting {
                        CompactLoadingView()
                    } else {
                        Text(LocalizationKey.customerServiceSubmitRating.localized)
                            .font(AppTypography.bodyBold)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: AppColors.gradientPrimary),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppCornerRadius.medium)
                .disabled(isSubmitting)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle(LocalizationKey.customerServiceRateService.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizationKey.customerServiceSkip.localized) {
                        viewModel.hasRated = true
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func submitRating() {
        guard !isSubmitting else { return }
        
        isSubmitting = true
        let commentText = comment.trimmingCharacters(in: .whitespaces).isEmpty ? nil : comment
        
        viewModel.rateService(rating: selectedRating, comment: commentText) { success in
            isSubmitting = false
            if success {
                viewModel.hasRated = true
                dismiss()
            }
        }
    }
}

