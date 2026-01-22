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
                
                // 角色信息（始终显示）
                if let currentUserId = currentUserId {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                        
                        // 判断用户角色并显示
                        if taskChat.posterId == currentUserId {
                            Text(LocalizationKey.notificationPoster.localized)
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else if taskChat.takerId == currentUserId {
                            Text(LocalizationKey.notificationTaker.localized)
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else if let expertCreatorId = taskChat.expertCreatorId, expertCreatorId == currentUserId {
                            Text(LocalizationKey.notificationExpert.localized)
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        } else {
                            Text(LocalizationKey.notificationParticipant.localized)
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

/*
// 任务聊天视图（已迁移，保留注释作为参考）
struct TaskChatView: View {
    let taskId: Int
    let taskTitle: String
    let taskChat: TaskChatItem? // 传入任务聊天信息，包含 posterId 和 takerId
    @StateObject private var viewModel: TaskChatDetailViewModel
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
    @State private var showLocationDetail = false
    @State private var taskDetail: Task?
    @StateObject private var taskDetailViewModel = TaskDetailViewModel()
    @State private var lastAppearTime: Date? // 记录上次出现的时间，用于判断是否需要刷新
    @State private var hasLoadedFromNotification = false // 标记是否从推送通知进入
    @State private var isWebSocketConnected = false // 标记 WebSocket 是否已连接
    @State private var showNewMessageButton = false // 是否显示新消息提示按钮
    @State private var isNearBottom = true // 是否接近底部（用于判断是否显示新消息按钮）
    @State private var scrollPosition: CGFloat = 0 // 滚动位置
    @State private var markAsReadWorkItem: DispatchWorkItem? // 用于防抖标记已读
    @StateObject private var keyboardObserver = KeyboardHeightObserver() // 键盘高度观察者
    
    // 判断任务是否已完成或取消（不允许发送消息）
    // 如果 taskChat 为 nil，默认允许发送消息（输入框可见）
    private var isTaskClosed: Bool {
        // 如果 taskChat 为 nil，默认不关闭（允许发送消息）
        guard let taskChat = taskChat else {
            return false
        }
        
        // 优先使用 taskStatus，如果没有则使用 status
        guard let status = taskChat.taskStatus ?? taskChat.status else {
            return false
        }
        
        let closedStatuses = ["completed", "cancelled", "pending_confirmation"]
        return closedStatuses.contains(status.lowercased())
    }
    
    // 根据任务状态返回提示文本
    private var closedStatusText: String {
        guard let status = taskChat?.taskStatus ?? taskChat?.status else {
            return LocalizationKey.notificationTaskEnded.localized
        }
        switch status.lowercased() {
        case "completed":
            return LocalizationKey.notificationTaskCompletedCannotSend.localized
        case "cancelled":
            return LocalizationKey.notificationTaskCancelledCannotSend.localized
        case "pending_confirmation":
            return LocalizationKey.notificationTaskPendingCannotSend.localized
        default:
            return LocalizationKey.notificationTaskEnded.localized
        }
    }
    
    init(taskId: Int, taskTitle: String, taskChat: TaskChatItem? = nil) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.taskChat = taskChat
        _viewModel = StateObject(wrappedValue: TaskChatDetailViewModel(taskId: taskId, taskChat: taskChat))
    }
    
    // MARK: - Helper Functions
    
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
        
        // 避免重复连接
        guard !isWebSocketConnected else {
            return
        }
        
        WebSocketService.shared.connect(token: token, userId: String(userId))
        isWebSocketConnected = true
        
        // 监听 WebSocket 消息，只处理当前任务的消息
        let currentTaskId = taskId  // 捕获 taskId 到局部变量
        let currentUserId = String(userId)  // 捕获当前用户ID
        WebSocketService.shared.messageSubject
            .sink { [weak viewModel] message in
                guard let viewModel = viewModel else { return }
                // 检查消息是否属于当前任务
                // 1. 检查 taskId 是否匹配
                if let messageTaskId = message.taskId, messageTaskId != currentTaskId {
                    return  // 不属于当前任务，忽略
                }
                // 2. 如果没有 taskId，可能是普通消息，需要通过其他方式判断（暂时允许）
                // 3. 检查消息是否已存在（避免重复添加）
                DispatchQueue.main.async {
                    // 使用 Set 优化去重检查（如果消息量大的话）
                    if !viewModel.messages.contains(where: { $0.id == message.id }) {
                        // 优化：使用二分插入保持有序，避免每次都完整排序
                        let messageTime = message.createdAt ?? ""
                        if let insertIndex = viewModel.messages.firstIndex(where: { ($0.createdAt ?? "") > messageTime }) {
                            viewModel.messages.insert(message, at: insertIndex)
                        } else {
                            viewModel.messages.append(message)
                        }
                        
                        // 批量保存缓存（减少 I/O 操作）
                        // saveToCache 内部已经实现了防抖机制
                        viewModel.saveToCache()
                        
                        // 如果视图可见且消息不是来自当前用户，自动标记为已读（使用防抖）
                        if viewModel.isViewVisible, let senderId = message.senderId, senderId != currentUserId {
                            // 取消之前的标记已读任务
                            self.markAsReadWorkItem?.cancel()
                            
                            // 创建新的标记已读任务（防抖：延迟 0.3 秒）
                            let workItem = DispatchWorkItem { [weak viewModel] in
                                guard let viewModel = viewModel else { return }
                                // 使用最新消息的ID标记已读
                                if let lastMessage = viewModel.messages.last, let messageId = lastMessage.messageId {
                                    viewModel.markAsRead(uptoMessageId: messageId)
                                } else {
                                    viewModel.markAsRead()
                                }
                            }
                            self.markAsReadWorkItem = workItem
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
                        }
                        
                        // 如果应用在后台且消息不是来自当前用户，发送本地推送通知
                        if let senderId = message.senderId, senderId != currentUserId {
                            if LocalNotificationManager.shared.isAppInBackground() || !viewModel.isViewVisible {
                                // 获取发送者名称
                                let senderName = message.senderName ?? "有人"
                                // 获取消息内容（如果是图片消息，显示提示）
                                let messageContent = message.content ?? "[图片]"
                                let displayContent = messageContent == "[图片]" ? "发送了一张图片" : messageContent
                                
                                // 获取消息ID（可能是字符串或整数）
                                let messageIdString: String
                                if let messageId = message.messageId {
                                    messageIdString = String(messageId)
                                } else {
                                    messageIdString = message.id
                                }
                                
                                LocalNotificationManager.shared.sendMessageNotification(
                                    title: senderName,
                                    body: displayContent,
                                    messageId: messageIdString,
                                    senderId: senderId,
                                    taskId: currentTaskId
                                )
                            }
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
    
    private func loadTaskDetailAndShowLocation() {
        // 先设置 showLocationDetail 为 true，这样 onReceive 可以捕获任务加载
        showLocationDetail = true
        taskDetailViewModel.loadTask(taskId: taskId)
        // 如果任务已经加载，立即设置 taskDetail
        if let task = taskDetailViewModel.task {
            taskDetail = task
        }
    }
    
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
    
    // MARK: - Input Area View
    @ViewBuilder
    private var inputAreaView: some View {
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
                    VStack(spacing: 4) {
                        HStack(spacing: AppSpacing.sm) {
                            TextField(LocalizationKey.actionsEnterMessage.localized, text: $messageText, axis: .vertical)
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
                        
                        // 字符计数提示（仅在接近最大长度时显示）
                        if messageText.count > 200 {
                            HStack {
                                Spacer()
                                Text("\(messageText.count)/500")
                                    .font(AppTypography.caption2)
                                    .foregroundColor(messageText.count >= 500 ? AppColors.error : AppColors.textTertiary)
                                    .padding(.trailing, AppSpacing.sm)
                            }
                        }
                    }
                    
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
                                CompactLoadingView()
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
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.sm)
                .background(AppColors.cardBackground)
                
                // 功能菜单面板
                if showActionMenu {
                    ChatActionMenuView(
                        taskStatus: taskChat?.taskStatus ?? taskChat?.status,
                        onImagePicker: {
                            showActionMenu = false
                            showImagePicker = true
                        },
                        onViewTaskDetail: {
                            showActionMenu = false
                            showTaskDetail = true
                        },
                        onViewLocationDetail: {
                            showActionMenu = false
                            loadTaskDetailAndShowLocation()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
    }
    
    // MARK: - Message List View
    @ViewBuilder
    private var messageListView: some View {
        if viewModel.isLoading && viewModel.messages.isEmpty {
            // 加载状态
            LoadingView(message: LocalizationKey.commonLoading.localized)
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
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // 加载更多历史消息按钮（在顶部）
                            if viewModel.hasMoreMessages {
                                Button(action: {
                                    // 任务聊天目前不支持分页，暂时隐藏
                                }) {
                                    HStack(spacing: 8) {
                                        if viewModel.isLoadingMore {
                                            CompactLoadingView()
                                        } else {
                                            Image(systemName: "arrow.up.circle")
                                                .font(.system(size: 14))
                                        }
                                        Text(viewModel.isLoadingMore ? LocalizationKey.commonLoading.localized : LocalizationKey.commonLoadMore.localized)
                                            .font(.system(size: 13))
                                    }
                                    .foregroundColor(AppColors.textSecondary)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(viewModel.isLoadingMore)
                                .id("load_more_button")
                                .opacity(0) // 暂时隐藏，因为后端不支持分页
                            }
                            
                            if viewModel.messages.isEmpty {
                                // 空状态
                                VStack(spacing: AppSpacing.md) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(LocalizationKey.notificationNoMessages.localized)
                                        .font(AppTypography.title3)
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(LocalizationKey.notificationStartConversation.localized)
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
                                    
                                    // 底部锚点，确保 ScrollView 默认在底部
                                    Color.clear
                                        .frame(height: 1)
                                        .id("scroll_bottom_anchor")
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                            }
                        }
                        .background(
                            GeometryReader { scrollGeometry in
                                Color.clear
                                    .preference(key: ScrollOffsetPreferenceKey.self, value: scrollGeometry.frame(in: .named("scroll")).minY)
                            }
                        )
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollContentBackground(.hidden) // 隐藏背景，避免手势冲突
                    .scrollDismissesKeyboard(.never) // 禁用下滑收回键盘功能，确保键盘稳定
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // 确保 ScrollView 填充可用空间，让 safeAreaInset 能够正确调整
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // 检测是否接近底部（距离底部小于 200 像素）
                        isNearBottom = value > -200
                        showNewMessageButton = !isNearBottom && !viewModel.messages.isEmpty
                    }
                    .refreshable {
                        if let userId = appState.currentUser?.id {
                            viewModel.loadMessages(currentUserId: String(userId))
                        }
                    }
                    .onAppear {
                        // 视图出现时，立即滚动到底部（无动画）
                        if let lastMessage = viewModel.messages.last {
                            DispatchQueue.main.async {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isInitialLoadComplete) { completed in
                        // 首次加载完成后，立即滚动到底部（无动画）
                        if completed, let lastMessage = viewModel.messages.last {
                            DispatchQueue.main.async {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.messages.count) { newCount in
                        // 只有新消息添加时才滚动到底部（不是加载更多历史时）
                        if newCount > 0 {
                            // 检查是否是新增消息（通过比较最后一条消息ID）
                            if let lastMessage = viewModel.messages.last,
                               lastMessage.id != lastMessageId {
                                // 如果输入框有焦点，立即滚动到底部（无延迟，与键盘同步）
                                if isInputFocused {
                                    if let lastMsg = viewModel.messages.last {
                                        DispatchQueue.main.async {
                                            withAnimation(keyboardObserver.keyboardAnimation) {
                                                proxy.scrollTo(lastMsg.id, anchor: .bottom)
                                            }
                                        }
                                    }
                                    showNewMessageButton = false
                                } else if isNearBottom {
                                    // 如果用户接近底部，延迟滚动（避免干扰用户浏览）
                                    scrollToBottom(proxy: proxy, delay: 0.1)
                                    showNewMessageButton = false
                                } else {
                                    // 用户不在底部，显示新消息提示
                                    showNewMessageButton = true
                                }
                            }
                        }
                    }
                    .onChange(of: isInputFocused) { focused in
                        if focused && !viewModel.messages.isEmpty {
                            // 输入框获得焦点时，立即滚动到底部（无延迟）
                            // 这样在键盘弹出、视图上移时，内容已经在底部，无需额外滚动
                            // 使用键盘动画同步滚动，让滚动和键盘弹出同步进行
                            if let lastMessage = viewModel.messages.last {
                                // 立即执行，不延迟，让滚动和键盘弹出同步
                                DispatchQueue.main.async {
                                    withAnimation(keyboardObserver.keyboardAnimation) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: keyboardObserver.keyboardHeight) { height in
                        // 当键盘弹出时，如果输入框有焦点且消息不为空，确保滚动到底部
                        if height > 0 && isInputFocused && !viewModel.messages.isEmpty {
                            if let lastMessage = viewModel.messages.last {
                                DispatchQueue.main.async {
                                    withAnimation(keyboardObserver.keyboardAnimation) {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 新消息提示按钮
                    if showNewMessageButton {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                scrollToBottom(proxy: proxy, delay: 0)
                                showNewMessageButton = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("新消息")
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: AppColors.gradientPrimary),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                            .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, AppSpacing.md)
                        .padding(.bottom, 80) // 在输入框上方
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            // 使用 safeAreaInset 让消息列表和输入区域都稳定布局
            messageListView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 输入区域 - 使用 safeAreaInset 自动避让键盘，系统会自动处理间距
                    inputAreaView
                }
                .navigationTitle(taskTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppColors.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar(.hidden, for: .tabBar)
            // 确保右滑返回手势正常工作
                .enableSwipeBack()
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
                .sheet(isPresented: $showCustomerService) {
                    NavigationStack {
                        CustomerServiceView()
                            .environmentObject(appState)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(LocalizationKey.commonDone.localized) {
                                        showCustomerService = false
                                    }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showTaskDetail) {
                    NavigationStack {
                        TaskDetailView(taskId: taskId)
                            .environmentObject(appState)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(LocalizationKey.commonDone.localized) {
                                        showTaskDetail = false
                                    }
                                }
                            }
                    }
                }
                .sheet(isPresented: $showLogin) {
                    LoginView()
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(selectedImage: $selectedImage)
                }
                .sheet(isPresented: $showLocationDetail) {
                    NavigationStack {
                        if let task = taskDetail {
                            TaskLocationDetailView(
                                location: task.location,
                                latitude: task.latitude,
                                longitude: task.longitude
                            )
                        } else if let task = taskDetailViewModel.task {
                            TaskLocationDetailView(
                                location: task.location,
                                latitude: task.latitude,
                                longitude: task.longitude
                            )
                        }
                    }
                }
                .onReceive(taskDetailViewModel.$task.compactMap { $0 }) { task in
                    // 当任务加载完成时，如果 showLocationDetail 为 true，更新 taskDetail
                    if showLocationDetail && taskDetail == nil {
                        taskDetail = task
                    }
                }
                .onChange(of: selectedImage) { newImage in
                    if let image = newImage {
                        // TODO: 上传图片并发送
                        uploadAndSendImage(image)
                        selectedImage = nil
                    }
                }
                .onAppear {
                    // 标记视图为可见，用于自动标记已读
                    viewModel.isViewVisible = true
                    
                    if !appState.isAuthenticated {
                        showLogin = true
                    } else {
                        let currentTime = Date()
                        let shouldRefresh: Bool
                        
                        // 检查是否有未读消息（最重要：有未读消息必须强制刷新）
                        let hasUnreadMessages = (taskChat?.unreadCount ?? 0) > 0
                        
                        // 检查是否有刷新标记（从推送通知进入）
                        let refreshKey = "refresh_task_chat_\(taskId)"
                        let needsRefreshFromNotification = UserDefaults.standard.bool(forKey: refreshKey)
                        
                        // 判断是否需要刷新消息（优先级从高到低）：
                        // 1. 如果有未读消息，必须强制刷新（最重要）
                        // 2. 如果消息为空，需要加载
                        // 3. 如果是从推送通知进入（有刷新标记），需要刷新
                        // 4. 如果距离上次出现超过30秒，需要刷新（可能从后台恢复）
                        // 5. 如果没有 taskChat 参数（从 TaskDetailView 等进入），也刷新以确保最新
                        // 6. 首次出现，如果消息不为空，可能是从缓存加载的，也需要刷新以确保最新
                        if hasUnreadMessages {
                            shouldRefresh = true
                        } else if viewModel.messages.isEmpty {
                            shouldRefresh = true
                        } else if needsRefreshFromNotification {
                            shouldRefresh = true
                            // 清除刷新标记
                            UserDefaults.standard.removeObject(forKey: refreshKey)
                        } else if taskChat == nil {
                            // 没有 taskChat 参数（从 TaskDetailView 等进入）
                            // 如果距离上次出现超过10秒，刷新以确保最新（避免过于频繁的刷新）
                            if let lastTime = lastAppearTime {
                                let timeSinceLastAppear = currentTime.timeIntervalSince(lastTime)
                                shouldRefresh = timeSinceLastAppear > 10
                            } else {
                                // 首次出现，刷新
                                shouldRefresh = true
                            }
                        } else if let lastTime = lastAppearTime {
                            let timeSinceLastAppear = currentTime.timeIntervalSince(lastTime)
                            // 如果距离上次出现超过30秒，则刷新
                            shouldRefresh = timeSinceLastAppear > 30
                        } else {
                            // 首次出现，如果消息不为空，可能是从缓存加载的，也需要刷新以确保最新
                            shouldRefresh = true
                        }
                        
                        if shouldRefresh, let userId = appState.currentUser?.id {
                            // 防止重复加载：如果已经在加载中，跳过
                            guard !viewModel.isLoading else {
                                return
                            }
                            
                            // 只有在有未读消息或从通知进入时才清空消息，避免不必要的界面闪烁
                            if hasUnreadMessages || needsRefreshFromNotification {
                                viewModel.messages = []
                            }
                            
                            viewModel.loadMessages(currentUserId: String(userId))
                            hasLoadedFromNotification = false // 重置标记
                        }
                        
                        // 更新最后出现时间
                        lastAppearTime = currentTime
                        
                        // 延迟标记已读，等消息加载完成后再标记（只在有未读消息时）
                        if hasUnreadMessages {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                viewModel.markAsRead()
                            }
                        }
                        // 连接 WebSocket 用于接收实时消息（避免重复连接）
                        if !isWebSocketConnected {
                            connectWebSocket()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTaskChat"))) { notification in
                    // 监听刷新任务聊天的通知
                    if let taskIdFromNotification = notification.userInfo?["task_id"] as? Int,
                       taskIdFromNotification == taskId {
                        hasLoadedFromNotification = true
                        // 如果视图已经出现且不在加载中，立即刷新
                        if viewModel.isViewVisible, !viewModel.isLoading, let userId = appState.currentUser?.id {
                            viewModel.messages = [] // 清空旧消息
                            viewModel.loadMessages(currentUserId: String(userId))
                            hasLoadedFromNotification = false
                        }
                    }
                }
                .onDisappear {
                    // 标记视图为不可见
                    viewModel.isViewVisible = false
                    // 清理错误状态
                    viewModel.errorMessage = nil
                    // 取消待执行的标记已读任务
                    markAsReadWorkItem?.cancel()
                    markAsReadWorkItem = nil
                    // 注意：不在这里断开 WebSocket，因为可能还有其他聊天窗口在使用
                    // WebSocket 会在应用退出或用户登出时统一断开
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
                        
                        Text(message.displayContent ?? LocalizationKey.notificationSystemMessage.localized)
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
        let taskStatus: String?
        let onImagePicker: () -> Void
        let onViewTaskDetail: () -> Void
        let onViewLocationDetail: () -> Void
        
        // 判断是否应该显示详细地址按钮（仅在 in_progress 或 pending_confirmation 时显示）
        private var shouldShowLocationDetail: Bool {
            guard let status = taskStatus?.lowercased() else { return false }
            return status == "in_progress" || status == "pending_confirmation"
        }
        
        var body: some View {
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.separator.opacity(0.3))
                
                HStack(spacing: AppSpacing.xl) {
                    // 上传图片
                    ChatActionButton(
                        icon: "photo.fill",
                        title: LocalizationKey.notificationImage.localized,
                        color: AppColors.success,
                        action: onImagePicker
                    )
                    
                    // 查看任务详情
                    ChatActionButton(
                        icon: "doc.text.fill",
                        title: LocalizationKey.notificationTaskDetail.localized,
                        color: AppColors.primary,
                        action: onViewTaskDetail
                    )
                    
                    // 详细地址（仅在任务进行中或待确认时显示）
                    if shouldShowLocationDetail {
                        ChatActionButton(
                            icon: "mappin.circle.fill",
                            title: LocalizationKey.notificationDetailAddress.localized,
                            color: AppColors.warning,
                            action: onViewLocationDetail
                        )
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColors.cardBackground)
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
        
    }
}
*/