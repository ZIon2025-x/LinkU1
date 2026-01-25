import SwiftUI
import Combine

/// 任务聊天主视图（重构版）
/// 对标 WhatsApp/微信，使用更稳的布局模型
struct TaskChatView: View {
    @StateObject var viewModel: TaskChatDetailViewModel
    @EnvironmentObject var appState: AppState
    
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    
    // 只保留"纯 UI 状态"（你文档里也建议这么做）
    @State private var messageText = "" // 输入框文本
    @State private var showActionMenu = false
    @State private var showImagePicker = false
    @State private var showTaskDetail = false
    @State private var showLogin = false
    @State private var showCustomerService = false
    @State private var showLocationDetail = false
    @State private var selectedImage: UIImage?
    @State private var taskDetail: Task?
    
    @StateObject private var taskDetailViewModel = TaskDetailViewModel()
    @State private var lastAppearTime: Date? // 记录上次出现的时间，用于判断是否需要刷新
    @State private var hasLoadedFromNotification = false // 标记是否从推送通知进入
    @State private var isWebSocketConnected = false // 标记 WebSocket 是否已连接
    @State private var markAsReadWorkItem: DispatchWorkItem? // 用于防抖标记已读
    @State private var websocketSubscription: AnyCancellable? // ✅ 新增：保存 WebSocket 订阅，用于在 disappear 时取消
    
    @FocusState private var isInputFocused: Bool
    
    // 输入区真实高度（包含 action menu 展开）
    // ✅ 修复：给 inputAreaHeight 一个默认值（避免首次 0 → 正常高度的闪动）
    @State private var inputAreaHeight: CGFloat = 60
    
    // 是否接近底部（用于决定新消息是否自动滚动）
    @State private var isNearBottom: Bool = true
    @State private var showNewMessageButton: Bool = false
    
    // 通过"触发器"驱动列表滚动（避免把 proxy 暴露到外层）
    @State private var scrollToBottomTrigger: Int = 0
    @State private var scrollWorkItem: DispatchWorkItem? // ✅ 新增：滚动防抖
    
    let taskId: Int
    let taskTitle: String
    let taskChat: TaskChatItem?
    
    private let bottomAnchorId = TaskChatConstants.bottomAnchorId
    
    init(taskId: Int, taskTitle: String, taskChat: TaskChatItem? = nil) {
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.taskChat = taskChat
        _viewModel = StateObject(wrappedValue: TaskChatDetailViewModel(taskId: taskId, taskChat: taskChat))
    }
    
    var body: some View {
        mainContent
            .navigationTitle(taskTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .enableSwipeBack()
            .onChange(of: viewModel.isInitialLoadComplete) { done in
                if done {
                    requestScrollToBottom()
                }
            }
            .onChange(of: viewModel.messages.count) { _ in
                if isNearBottom || isInputFocused {
                    requestScrollToBottom()
                } else {
                    showNewMessageButton = true
                }
            }
            .onChange(of: isInputFocused) { focused in
                // ✅ 修复：WhatsApp 风格 - 聚焦输入框只做"面板互斥"，不额外滚动，避免"两段动作"
                if focused, showActionMenu {
                    withAnimation(keyboardObserver.keyboardAnimation) {
                        showActionMenu = false
                    }
                }
            }
            .onChange(of: keyboardObserver.keyboardHeight) { height in
                // ✅ 修复：唯一的"键盘场景贴底触发源"
                // 不延迟、并且只在"用户本来就在底部"时贴底；否则尊重用户当前阅读位置
                guard height > 0 else { return }
                guard isInputFocused else { return }
                guard isNearBottom else { return } // 不抢用户滚动位置
                guard !viewModel.messages.isEmpty else { return }
                
                requestScrollToBottom(animatedWithKeyboard: true)
            }
            .onChange(of: showActionMenu) { isShown in
                // ✅ 修复：面板展开/收起时，如果用户本来就在底部，就手动滚一次到底部锚点
                // 原因：safeAreaInset 只会缩小 ScrollView 的可视高度，但不会自动保持"底部锚点仍然贴在可视底部"
                // 只在展开时触发（收起时可视高度变大，滚到底部通常没必要，偶尔会造成"内容轻微漂移"的主观感受）
                guard isShown else { return }
                guard isNearBottom else { return }
                guard !viewModel.messages.isEmpty else { return }
                
                // ✅ 修复：面板展开时，使用与面板相同的动画曲线，实现"完全同频"
                // 注意：这里需要等待下一帧，因为 scrollAnimation 的计算依赖于 showActionMenu 的状态
                // 使用立即响应版本，因为这是用户主动操作（点击➕按钮）
                DispatchQueue.main.async {
                    requestScrollToBottomImmediate()
                }
            }
            .onAppear {
                setupOnAppear()
            }
            .onDisappear {
                setupOnDisappear()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshTaskChat"))) { notification in
                handleRefreshNotification(notification)
            }
            .onReceive(taskDetailViewModel.$task.compactMap { $0 }) { task in
                // 当任务加载完成时，如果 showLocationDetail 为 true，更新 taskDetail
                if showLocationDetail && taskDetail == nil {
                    taskDetail = task
                }
            }
            .onChange(of: selectedImage) { newImage in
                if let image = newImage {
                    uploadAndSendImage(image)
                    selectedImage = nil
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage)
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showTaskDetail = true
                        } label: {
                            Label(LocalizationKey.notificationTaskDetail.localized, systemImage: "doc.text")
                        }
                        
                        Divider()
                        
                        Button {
                            showCustomerService = true
                        } label: {
                            Label(LocalizationKey.infoNeedHelp.localized, systemImage: "questionmark.circle")
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
            .alert(LocalizationKey.commonNotice.localized, isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button(LocalizationKey.commonOk.localized) { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage { Text(msg) }
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // ✅ 修复：不要用无参数的 ignoresSafeArea()，避免影响 keyboard safe area
            AppColors.background
                .ignoresSafeArea(.container, edges: .all)
            
            messageListView
        }
        // ✅ 修复：使用 safeAreaInset 让系统处理键盘避让（更稳）
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputAreaView
        }
        // ✅ 修复：移除外层对 showActionMenu / inputAreaHeight 的全局 animation
        // Action Menu 的动画应该只由 withAnimation + transition 控制
        // inputAreaHeight 是测量值，最不适合被全局动画驱动
        // 键盘动画已经在消息滚动里用了 keyboardAnimation 去同步滚动动画，这才是正确位置
    }
    
    @ViewBuilder
    private var messageListView: some View {
        TaskChatMessageListView(
            messages: viewModel.messages,
            currentUserId: getCurrentUserId(),
            bottomInset: inputAreaHeight,
            scrollToBottomTrigger: $scrollToBottomTrigger,
            isNearBottom: $isNearBottom,
            showNewMessageButton: $showNewMessageButton,
            scrollAnimation: {
                if keyboardObserver.keyboardHeight > 0 {
                    return keyboardObserver.keyboardAnimation
                } else if showActionMenu {
                    return Animation.spring(response: 0.28, dampingFraction: 0.86)
                } else {
                    return nil
                }
            }(),
            isLoading: viewModel.isLoading,
            onRefresh: {
                if let uid = getCurrentUserId() {
                    viewModel.loadMessages(currentUserId: uid)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // ✅ 修复：点击空白时统一退出输入态（键盘/面板二选一），体验更像 WhatsApp
            if showActionMenu {
                withAnimation(keyboardObserver.keyboardAnimation) {
                    showActionMenu = false
                }
            }
            isInputFocused = false
            hideKeyboard()
        }
    }
    
    @ViewBuilder
    private var inputAreaView: some View {
                TaskChatInputArea(
                    messageText: $messageText,
                    isSending: viewModel.isSending,
                    showActionMenu: $showActionMenu,
                    isTaskClosed: isTaskClosed,
                    isInputDisabled: isInputDisabled, // ✅ 修复：pending_confirmation 不需要禁用输入
                    closedStatusText: closedStatusText,
                    isInputFocused: $isInputFocused,
                    onSend: sendMessage,
                    onToggleActionMenu: toggleActionMenuSmoothly, // ✅ 修复：使用分段切换方法
                    onOpenImagePicker: { showImagePicker = true },
                    onOpenTaskDetail: { showTaskDetail = true },
                    onViewLocationDetail: shouldShowLocationDetail ? { loadTaskDetailAndShowLocation() } : nil
                )
        .readHeight(into: $inputAreaHeight)
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentUserId() -> String? {
        if let userId = appState.currentUser?.id {
            return String(userId)
        }
        return nil
    }
    
    private var isTaskClosed: Bool {
        guard let taskChat = taskChat else {
            return false
        }
        guard let status = taskChat.taskStatus ?? taskChat.status else {
            return false
        }
        // ✅ 修复：pending_confirmation 仍允许发消息和查看地址，只禁用输入
        // 如果 pending_confirmation 需要禁用输入，应该在 UI 层面处理，而不是完全关闭聊天
        let closedStatuses = ["completed", "cancelled"]
        return closedStatuses.contains(status.lowercased())
    }
    
    // ✅ 修复：pending_confirmation 不需要禁用输入，双方可以继续沟通
    // 只有在任务真正关闭（completed/cancelled）时才禁用输入
    private var isInputDisabled: Bool {
        // 不再禁用 pending_confirmation 状态的输入
        // 因为这是接受者标记完成后的等待确认状态，双方需要继续沟通
        return false
    }
    
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
    
    // 判断是否应该显示详细地址按钮（仅在 in_progress 或 pending_confirmation 时显示）
    private var shouldShowLocationDetail: Bool {
        guard let status = taskChat?.taskStatus ?? taskChat?.status else { return false }
        let statusLower = status.lowercased()
        return statusLower == "in_progress" || statusLower == "pending_confirmation"
    }
    
    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !viewModel.isSending else { return }
        
        if !appState.isAuthenticated {
            showLogin = true
            return
        }
        
        isInputFocused = false
        messageText = "" // 清空输入框
        
        viewModel.sendMessage(content: trimmed) { success in
            if success {
                HapticFeedback.success()
                requestScrollToBottom()
            } else {
                // 失败时恢复文本
                messageText = trimmed
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
        let filename = "chat_image_\(Int(Date().timeIntervalSince1970)).jpg"
        
        // 任务聊天图片使用私密图片上传API（需要token验证，24小时有效期，但任务进行中可访问）
        APIService.shared.uploadImage(imageData, filename: filename, taskId: taskId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak viewModel] completion in
                    viewModel?.isSending = false
                    if case .failure(let error) = completion {
                        viewModel?.errorMessage = "图片上传失败: \(error.userFriendlyMessage)"
                    }
                },
                receiveValue: { [weak viewModel] imageUrl in
                    guard let viewModel = viewModel else { return }
                    viewModel.sendMessageWithAttachment(
                        content: "[图片]",
                        attachmentType: "image",
                        attachmentUrl: imageUrl
                    ) { success in
                        // ✅ 修复：struct 是值类型，不会有循环引用，可以直接捕获
                        // 如果成功，viewModel 会更新 messages，触发 onChange(of: viewModel.messages.count)
                        // 从而自动滚动到底部（如果用户在底部或正在输入）
                    }
                }
            )
            .store(in: &viewModel.cancellables)
    }
    
    private func requestScrollToBottom(animatedWithKeyboard: Bool = false) {
        // ✅ 修复：滚动防抖 - 同一帧/同一小段时间内的多次触发只执行一次滚动
        scrollWorkItem?.cancel()
        let work = DispatchWorkItem {
            // ✅ 按照文档：递增触发器，列表内部收到变化后滚到底部 anchor
            // 如果 animatedWithKeyboard 为 true，会在 TaskChatMessageListView 中使用 keyboardAnimation
            scrollToBottomTrigger += 1
        }
        scrollWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
    
    // ✅ 修复：提供立即响应版本，用于用户主动操作（点击新消息按钮、点击➕展开面板等）
    private func requestScrollToBottomImmediate() {
        // 取消待执行的防抖任务
        scrollWorkItem?.cancel()
        scrollWorkItem = nil
        // 立即触发滚动
        scrollToBottomTrigger += 1
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
    
    // MARK: - Action Menu Toggle
    
    /// ✅ 修复：统一状态机与动画曲线 - WhatsApp 风格同步感
    /// 不要"先收键盘 -> 等待 -> 再开菜单"，否则会出现中间态（内容先下坠到底部，再被菜单上推）
    /// 正确做法：先开菜单（用同一条曲线），同时结束输入焦点，让键盘按系统曲线下沉
    private func toggleActionMenuSmoothly() {
        // ✅ 修复：如果正在发送/输入被禁用，就不要打开"会引导发送"的功能项
        // 减少状态复杂度，避免用户在禁用状态下误操作
        if viewModel.isSending || isInputDisabled {
            return
        }
        
        // 统一动画：如果键盘正在显示，使用键盘同款动画参数实现"完全同步"
        let fallback = Animation.spring(response: 0.28, dampingFraction: 0.86)
        // ✅ 修复：keyboardAnimation 不是 Optional，直接使用
        let unifiedAnim = keyboardObserver.keyboardHeight > 0 ? keyboardObserver.keyboardAnimation : fallback
        
        if showActionMenu {
            // 已展开：直接收起
            withAnimation(unifiedAnim) {
                showActionMenu = false
            }
            return
        }
        
        // ✅ 修复：opening - 先结束输入焦点（触发键盘下沉），同帧开启面板
        // 保持同一 runloop，不要加 delay
        if isInputFocused {
            isInputFocused = false
        }
        withAnimation(unifiedAnim) {
            showActionMenu = true
        }
    }
    
    // MARK: - WebSocket & Message Loading
    
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
        let currentTaskId = taskId
        let currentUserId = String(userId)
        // ✅ 修复：保存订阅到 view 的 state，而不是 viewModel 的 cancellables
        // 这样可以在 setupOnDisappear() 中取消订阅，避免多聊天页来回切导致订阅累积
        websocketSubscription = WebSocketService.shared.messageSubject
            .sink { [weak viewModel] message in
                guard let viewModel = viewModel else { return }
                // 检查消息是否属于当前任务
                if let messageTaskId = message.taskId, messageTaskId != currentTaskId {
                    return // 不属于当前任务，忽略
                }
                
                // 检查消息是否已存在（避免重复添加）
                DispatchQueue.main.async {
                    if !viewModel.messages.contains(where: { $0.id == message.id }) {
                        // 使用二分插入保持有序
                        let messageTime = message.createdAt ?? ""
                        if let insertIndex = viewModel.messages.firstIndex(where: { ($0.createdAt ?? "") > messageTime }) {
                            viewModel.messages.insert(message, at: insertIndex)
                        } else {
                            viewModel.messages.append(message)
                        }
                        
                        // ✅ 修复：saveToCache() 已经在 ViewModel 中做了防抖（0.5秒），
                        // 这里直接调用即可，不需要额外处理
                        viewModel.saveToCache()
                        
                        // 如果视图可见且消息不是来自当前用户，自动标记为已读（使用防抖）
                        if viewModel.isViewVisible, let senderId = message.senderId, senderId != currentUserId {
                            // ✅ 修复：struct 是值类型，不会有循环引用
                            // 在 SwiftUI 中，@State 属性可以在闭包中访问，但需要通过 DispatchQueue.main.async 来安全地修改
                            // 这里我们直接访问 markAsReadWorkItem，因为 struct 是值类型，不会有循环引用问题
                            markAsReadWorkItem?.cancel()
                            
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
                            markAsReadWorkItem = workItem
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
        // ✅ 修复：不再存储到 viewModel.cancellables，而是保存到 view 的 state
        // 这样可以在 setupOnDisappear() 中取消订阅，避免多聊天页来回切导致订阅累积
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
    
    // MARK: - Lifecycle
    
    private func setupOnAppear() {
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
    
    private func setupOnDisappear() {
        // 标记视图为不可见
        viewModel.isViewVisible = false
        // 清理错误状态
        viewModel.errorMessage = nil
        // 取消待执行的标记已读任务
        markAsReadWorkItem?.cancel()
        markAsReadWorkItem = nil
        // ✅ 修复：取消待执行的滚动任务
        scrollWorkItem?.cancel()
        scrollWorkItem = nil
        // ✅ 修复：取消当前 view 的 WebSocket 订阅（保留连接不断开）
        // 避免多聊天页来回切导致订阅累积的风险
        websocketSubscription?.cancel()
        websocketSubscription = nil
        // 重置连接标记，下次进入时可以重新订阅
        isWebSocketConnected = false
        // 注意：不在这里断开 WebSocket 连接，因为可能还有其他聊天窗口在使用
        // WebSocket 连接会在应用退出或用户登出时统一断开
    }
    
    private func handleRefreshNotification(_ notification: Notification) {
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
}

enum TaskChatConstants {
    static let bottomAnchorId = "task_chat_bottom_anchor"
}
