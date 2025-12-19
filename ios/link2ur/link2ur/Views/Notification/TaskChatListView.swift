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
                    title: "暂无任务聊天",
                    message: "还没有任务相关的聊天记录"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.taskChats) { taskChat in
                            NavigationLink(destination: TaskChatView(taskId: taskChat.id, taskTitle: taskChat.title, taskChat: taskChat)
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
    
    // 获取任务图标
    private func getTaskIcon() -> String {
        if let taskType = taskChat.taskType, let icon = taskTypeIcons[taskType] {
            return icon
        }
        // 默认使用消息图标
        return "message.fill"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // 任务图标/头像 - 如果有图片则显示图片，否则显示图标
            ZStack {
                // 如果有任务图片，显示第一张图片
                if let images = taskChat.images, !images.isEmpty, let firstImageUrl = images.first {
                    AsyncImageView(
                        urlString: firstImageUrl,
                        placeholder: Image(systemName: getTaskIcon()),
                        width: 56,
                        height: 56,
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
                        .frame(width: 56, height: 56)
                        .shadow(color: AppColors.primary.opacity(0.2), radius: 8, x: 0, y: 4)
                        .overlay(
                            Image(systemName: getTaskIcon())
                                .foregroundColor(.white)
                                .font(.system(size: 24, weight: .semibold))
                        )
                }
                
                // 未读红点标记
                if let unreadCount = taskChat.unreadCount, unreadCount > 0 {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(AppColors.cardBackground, lineWidth: 2)
                        )
                        .offset(x: 20, y: -20)
                }
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                // 标题和时间
                HStack(alignment: .top) {
                    Text(taskChat.title)
                        .font(AppTypography.body)
                        .fontWeight(taskChat.unreadCount ?? 0 > 0 ? .bold : .semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 6) {
                        // 优先使用 lastMessageTime，如果没有则使用 lastMessage.createdAt
                        if let lastTime = taskChat.lastMessageTime ?? taskChat.lastMessage?.createdAt {
                            Text(formatTime(lastTime))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textTertiary)
                        }
                        
                        // 未读数 - 渐变背景
                        if let unreadCount = taskChat.unreadCount, unreadCount > 0 {
                            ZStack {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [AppColors.error, AppColors.error.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: unreadCount > 9 ? 28 : 20, height: 20)
                                
                                Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                    .font(AppTypography.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, unreadCount > 9 ? 6 : 0)
                            }
                        }
                    }
                }
                
                // 角色信息（始终显示）
                if let currentUserId = currentUserId {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                        
                        // 判断用户角色并显示
                        if taskChat.posterId == currentUserId {
                            Text("发布者")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else if taskChat.takerId == currentUserId {
                            Text("承接者")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else if let expertCreatorId = taskChat.expertCreatorId, expertCreatorId == currentUserId {
                            Text("专家")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else {
                            Text("参与者")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
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
                            Text("系统: ")
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
                            Text("系统消息")
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
        .padding(AppSpacing.md)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 任务聊天视图
struct TaskChatView: View {
    let taskId: Int
    let taskTitle: String
    let taskChat: TaskChatItem? // 传入任务聊天信息，包含 posterId 和 takerId
    @StateObject private var viewModel: TaskChatDetailViewModel
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var lastMessageId: String?
    @State private var scrollWorkItem: DispatchWorkItem?
    @FocusState private var isInputFocused: Bool
    @State private var showLogin = false
    @State private var showActionMenu = false
    @State private var showImagePicker = false
    @State private var showTaskDetail = false
    @State private var selectedImage: UIImage?
    @State private var showCustomerService = false
    
    // 计算键盘避让的底部 padding
    private var keyboardPadding: CGFloat {
        guard keyboardObserver.keyboardHeight > 0 else { return 0 }
        return max(keyboardObserver.keyboardHeight - 60, 0)
    }
    
    // 判断任务是否已完成或取消（不允许发送消息）
    private var isTaskClosed: Bool {
        guard let status = taskChat?.taskStatus ?? taskChat?.status else {
            return false
        }
        let closedStatuses = ["completed", "cancelled", "pending_confirmation"]
        return closedStatuses.contains(status.lowercased())
    }
    
    // 根据任务状态返回提示文本
    private var closedStatusText: String {
        guard let status = taskChat?.taskStatus ?? taskChat?.status else {
            return "任务已结束"
        }
        switch status.lowercased() {
        case "completed":
            return "任务已完成，无法发送消息"
        case "cancelled":
            return "任务已取消，无法发送消息"
        case "pending_confirmation":
            return "任务待确认，暂停发送消息"
        default:
            return "任务已结束"
        }
    }
    
    init(taskId: Int, taskTitle: String, taskChat: TaskChatItem? = nil) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.taskChat = taskChat
        _viewModel = StateObject(wrappedValue: TaskChatDetailViewModel(taskId: taskId, taskChat: taskChat))
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 消息列表
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    // 加载状态
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppColors.primary)
                        Text("加载消息中...")
                            .font(AppTypography.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                    // 使用统一的错误状态组件
                    ErrorStateView(
                        message: errorMessage,
                        retryAction: {
                            if let userId = appState.currentUser?.id {
                                viewModel.loadMessages(currentUserId: String(userId))
                            }
                        }
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                if viewModel.messages.isEmpty {
                                    // 空状态
                                    VStack(spacing: AppSpacing.md) {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(AppColors.textTertiary)
                                        Text("还没有消息")
                                            .font(AppTypography.title3)
                                            .foregroundColor(AppColors.textSecondary)
                                        Text("开始对话吧！")
                                            .font(AppTypography.subheadline)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 100)
                                } else {
                                    LazyVStack(spacing: AppSpacing.sm) {
                                        ForEach(viewModel.messages) { message in
                                            // 判断是否为系统消息
                                            if isSystemMessage(message) {
                                                SystemMessageBubble(message: message)
                                                    .id(message.id)
                                            } else {
                                                MessageBubble(
                                                    message: message,
                                                    isFromCurrentUser: isMessageFromCurrentUser(message)
                                                )
                                                .id(message.id)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                }
                            }
                            .padding(.bottom, keyboardPadding)
                        }
                        .refreshable {
                            if let userId = appState.currentUser?.id {
                                viewModel.loadMessages(currentUserId: String(userId))
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
                
                // 输入区域 - 更现代的设计
                VStack(spacing: 0) {
                    Divider()
                        .background(AppColors.separator)
                    
                    // 根据任务状态显示不同的输入区域
                    if isTaskClosed {
                        // 任务已结束，显示提示
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text(closedStatusText)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textTertiary)
                            
                            Spacer()
                            
                            // 查看任务详情按钮
                            Button(action: { showTaskDetail = true }) {
                                Text("查看详情")
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
                        .background(AppColors.cardBackground)
                    } else {
                        // 正常输入区域
                        HStack(spacing: AppSpacing.sm) {
                            // ➕ 更多功能按钮
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    showActionMenu.toggle()
                                    // 收起键盘
                                    if showActionMenu {
                                        isInputFocused = false
                                    }
                                }
                            }) {
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
                            
                            // 输入框
                            HStack(spacing: AppSpacing.sm) {
                                TextField("输入消息...", text: $messageText, axis: .vertical)
                                    .font(AppTypography.body)
                                    .lineLimit(1...4)
                                    .focused($isInputFocused)
                                    .disabled(viewModel.isSending)
                                    .onSubmit {
                                        sendMessage()
                                    }
                                    .onChange(of: isInputFocused) { focused in
                                        if focused && showActionMenu {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                showActionMenu = false
                                            }
                                        }
                                    }
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
                            Button(action: sendMessage) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: messageText.isEmpty || viewModel.isSending ? [AppColors.textTertiary, AppColors.textTertiary] : AppColors.gradientPrimary),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    if viewModel.isSending {
                                        ProgressView()
                                            .tint(.white)
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.up")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                            .disabled(messageText.isEmpty || viewModel.isSending)
                            .opacity(messageText.isEmpty || viewModel.isSending ? 0.5 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: messageText.isEmpty)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isSending)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.cardBackground)
                        
                        // 功能菜单面板
                        if showActionMenu {
                            ChatActionMenuView(
                                onImagePicker: {
                                    showActionMenu = false
                                    showImagePicker = true
                                },
                                onViewTaskDetail: {
                                    showActionMenu = false
                                    showTaskDetail = true
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                // 使用系统级键盘处理，避免约束冲突
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
        .navigationTitle(taskTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showTaskDetail = true
                    } label: {
                        Label("任务详情", systemImage: "doc.text")
                    }
                    
                    Divider()
                    
                    Button {
                        showCustomerService = true
                    } label: {
                        Label("需要帮助", systemImage: "questionmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .menuStyle(.automatic)
                .menuIndicator(.hidden)
            }
        }
        .background {
            // 使用隐藏的 NavigationLink 实现导航
            NavigationLink(destination: CustomerServiceView().environmentObject(appState), isActive: $showCustomerService) {
                EmptyView()
            }
            .hidden()
            
            NavigationLink(destination: TaskDetailView(taskId: taskId).environmentObject(appState), isActive: $showTaskDetail) {
                EmptyView()
            }
            .hidden()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                // TODO: 上传图片并发送
                uploadAndSendImage(image)
                selectedImage = nil
            }
        }
        .onAppear {
            if !appState.isAuthenticated {
                showLogin = true
            } else {
                // 只在消息为空时加载，避免重复加载
                if viewModel.messages.isEmpty, let userId = appState.currentUser?.id {
                    viewModel.loadMessages(currentUserId: String(userId))
                }
                // 延迟标记已读，等消息加载完成后再标记
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.markAsRead()
                }
                // 连接 WebSocket 用于接收实时消息
                connectWebSocket()
            }
        }
        .onDisappear {
            // 清理错误状态
            viewModel.errorMessage = nil
        }
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty, !viewModel.isSending else { return }
        
        if !appState.isAuthenticated {
            showLogin = true
            return
        }
        
        let content = trimmedText
        messageText = "" // 立即清空输入框
        
        viewModel.sendMessage(content: content) { success in
            if !success {
                // 失败时恢复文本
                DispatchQueue.main.async {
                    messageText = content
                }
            }
        }
    }
    
    private func uploadAndSendImage(_ image: UIImage) {
        // 1. 压缩图片
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            viewModel.errorMessage = "图片处理失败"
            return
        }
        
        // 检查图片大小（限制 5MB）
        let maxSize = 5 * 1024 * 1024 // 5MB
        if imageData.count > maxSize {
            viewModel.errorMessage = "图片太大，请选择小于 5MB 的图片"
            return
        }
        
        // 设置上传状态
        viewModel.isSending = true
        
        // 2. 上传到服务器
        let filename = "chat_image_\(Int(Date().timeIntervalSince1970)).jpg"
        APIService.shared.uploadImage(imageData, filename: filename)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak viewModel] completion in
                viewModel?.isSending = false
                if case .failure(let error) = completion {
                    viewModel?.errorMessage = "图片上传失败: \(error.userFriendlyMessage)"
                }
            }, receiveValue: { [weak viewModel] imageUrl in
                guard let viewModel = viewModel else { return }
                
                // 3. 发送包含图片的消息
                viewModel.sendMessageWithAttachment(
                    content: "[图片]",
                    attachmentType: "image",
                    attachmentUrl: imageUrl
                ) { success in
                    if !success {
                        viewModel.errorMessage = "发送图片消息失败"
                    }
                }
            })
            .store(in: &viewModel.cancellables)
    }
    
    private func connectWebSocket() {
        guard let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey),
              let userId = appState.currentUser?.id else {
            return
        }
        
        WebSocketService.shared.connect(token: token, userId: String(userId))
        
        // 监听 WebSocket 消息，只处理当前任务的消息
        WebSocketService.shared.messageSubject
            .sink { [weak viewModel] message in
                guard let viewModel = viewModel else { return }
                // 检查消息是否属于当前任务（通过消息内容或其他标识）
                // 这里可能需要根据实际 WebSocket 消息格式调整
                // 使用 id 来比较（id 是 String 类型，由 messageId 或其他字段生成）
                DispatchQueue.main.async {
                    if !viewModel.messages.contains(where: { $0.id == message.id }) {
                        viewModel.messages.append(message)
                        viewModel.messages.sort { msg1, msg2 in
                            let time1 = msg1.createdAt ?? ""
                            let time2 = msg2.createdAt ?? ""
                            return time1 < time2
                        }
                    }
                }
            }
            .store(in: &viewModel.cancellables)
    }
    
    private func isMessageFromCurrentUser(_ message: Message) -> Bool {
        if let userId = appState.currentUser?.id, let senderId = message.senderId {
            return String(userId) == senderId
        }
        return false
    }
    
    // 判断是否为系统消息
    private func isSystemMessage(_ message: Message) -> Bool {
        // 系统消息的特征：msgType 为 system，或者 senderId 为 nil
        return message.msgType == .system || message.senderId == nil
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
                    withAnimation(.easeInOut(duration: 0.3)) {
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

// 系统消息气泡组件 - 居中显示，样式与普通消息区分
struct SystemMessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 4) {
                // 系统消息内容
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textTertiary)
                    
                    Text(message.content ?? "系统消息")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                        .fill(AppColors.cardBackground.opacity(0.6))
                )
                
                // 时间戳（可选，系统消息可能不需要显示时间）
                if let createdAt = message.createdAt {
                    Text(formatTime(createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 聊天功能菜单组件
struct ChatActionMenuView: View {
    let onImagePicker: () -> Void
    let onViewTaskDetail: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.separator.opacity(0.3))
            
            HStack(spacing: AppSpacing.xl) {
                // 上传图片
                ChatActionButton(
                    icon: "photo.fill",
                    title: "图片",
                    color: AppColors.success,
                    action: onImagePicker
                )
                
                // 查看任务详情
                ChatActionButton(
                    icon: "doc.text.fill",
                    title: "任务详情",
                    color: AppColors.primary,
                    action: onViewTaskDetail
                )
                
                Spacer()
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
        }
        .background(AppColors.cardBackground)
    }
}

// 聊天功能按钮
struct ChatActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
    }
}

