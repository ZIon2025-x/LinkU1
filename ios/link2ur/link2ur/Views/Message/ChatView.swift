import SwiftUI

struct ChatView: View {
    let partnerId: String
    let partner: Contact?
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject var appState: AppState
    @State private var messageText = ""
    @State private var showLogin = false
    @FocusState private var isInputFocused: Bool
    
    init(partnerId: String, partner: Contact? = nil) {
        self.partnerId = partnerId
        self.partner = partner
        _viewModel = StateObject(wrappedValue: ChatViewModel(partnerId: partnerId, partner: partner))
    }
    
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    @State private var lastMessageId: String?
    @State private var scrollWorkItem: DispatchWorkItem?
    
    // 计算键盘避让的底部 padding
    private var keyboardPadding: CGFloat {
        guard keyboardObserver.keyboardHeight > 0 else { return 0 }
        // 减去输入框区域的大概高度（约 60），确保输入框和最新消息都可见
        return max(keyboardObserver.keyboardHeight - 60, 0)
    }
    
    // 性能优化：缓存消息文本是否为空的计算结果
    private var isMessageEmpty: Bool {
        messageText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 消息列表
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    // 使用骨架屏替代简单加载指示器
                    MessageListSkeleton(messageCount: 6)
                } else if let errorMessage = viewModel.errorMessage, viewModel.messages.isEmpty {
                    // 使用统一的错误状态组件
                    ErrorStateView(
                        message: errorMessage,
                        retryAction: {
                            viewModel.loadMessages()
                        }
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                // 加载更多指示器（在顶部）
                                if viewModel.hasMoreMessages {
                                    Button(action: {
                                        viewModel.loadMoreMessages()
                                    }) {
                                        HStack(spacing: 8) {
                                            if viewModel.isLoadingMore {
                                                CompactLoadingView()
                                            } else {
                                                Image(systemName: "arrow.up.circle")
                                                    .font(.system(size: 14))
                                            }
                                            Text(viewModel.isLoadingMore ? LocalizationKey.messagesLoadingMore.localized : LocalizationKey.messagesLoadMoreHistory.localized)
                                                .font(.system(size: 13))
                                        }
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity)
                                    }
                                    .disabled(viewModel.isLoadingMore)
                                    .id("load_more_button")
                                }
                                
                                if viewModel.messages.isEmpty {
                                    // 空状态
                                    VStack(spacing: AppSpacing.md) {
                                        Image(systemName: "message.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(AppColors.textTertiary)
                                        Text(LocalizationKey.messagesNoMessagesYet.localized)
                                            .font(AppTypography.title3)
                                            .foregroundColor(AppColors.textSecondary)
                                        Text(LocalizationKey.messagesStartConversation.localized)
                                            .font(AppTypography.subheadline)
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 100)
                                } else {
                                    LazyVStack(spacing: AppSpacing.sm) {
                                        ForEach(viewModel.messages, id: \.id) { message in
                                            MessageBubble(
                                                message: message,
                                                isFromCurrentUser: isMessageFromCurrentUser(message)
                                            )
                                            .id(message.id) // 确保稳定的id，优化视图复用
                                        }
                                    }
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                }
                            }
                            .padding(.bottom, keyboardPadding)
                        }
                        .refreshable {
                            viewModel.loadMessages()
                        }
                        .onAppear {
                            // 首次进入时滚动到底部
                            if !viewModel.messages.isEmpty {
                                scrollToBottom(proxy: proxy, delay: 0.2)
                            }
                        }
                        .onChange(of: viewModel.messages.count) { newCount in
                            // 只有新消息添加时才滚动到底部（不是加载更多历史时）
                            if newCount > 0 {
                                // 检查是否是新增消息（通过比较最后一条消息ID）
                                if let lastMessage = viewModel.messages.last,
                                   lastMessage.id != lastMessageId {
                                    scrollToBottom(proxy: proxy, delay: 0.1)
                                }
                            }
                        }
                        .onChange(of: viewModel.isInitialLoadComplete) { completed in
                            // 首次加载完成后滚动到底部
                            if completed && !viewModel.messages.isEmpty {
                                scrollToBottom(proxy: proxy, delay: 0.1)
                            }
                        }
                        .onChange(of: isInputFocused) { focused in
                            // 当输入框获得焦点时，延迟滚动到底部
                            if focused && !viewModel.messages.isEmpty {
                                scrollToBottom(proxy: proxy, delay: 0.3)
                            }
                        }
                        .onChange(of: keyboardObserver.keyboardHeight) { height in
                            // 键盘弹出时，自动滚动到底部
                            if height > 0 && !viewModel.messages.isEmpty {
                                scrollToBottom(proxy: proxy, delay: 0.1, animation: keyboardObserver.keyboardAnimation)
                            }
                        }
                    }
                }
                
                // 输入区域 - 更现代的设计，支持键盘避让
                VStack(spacing: 0) {
                    Divider()
                        .background(AppColors.separator)
                    
                    HStack(spacing: AppSpacing.sm) {
                        // 输入框容器
                        HStack(spacing: AppSpacing.sm) {
                            TextField(LocalizationKey.messagesEnterMessage.localized, text: $messageText, axis: .vertical)
                                .font(AppTypography.body)
                                .lineLimit(1...4)
                                .focused($isInputFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.sentences)
                                .submitLabel(.send)
                                .onSubmit {
                                    sendMessage()
                                }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                                .stroke(
                                    isInputFocused ? AppColors.primary.opacity(0.4) : AppColors.separator.opacity(0.3),
                                    lineWidth: isInputFocused ? 1.5 : 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
                        
                        // 发送按钮 - 渐变设计
                        Button(action: sendMessage) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(
                                                colors: isMessageEmpty || viewModel.isSending
                                                    ? [AppColors.textTertiary, AppColors.textTertiary]
                                                    : AppColors.gradientPrimary
                                            ),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                    .shadow(
                                        color: isMessageEmpty || viewModel.isSending
                                            ? .clear
                                            : AppColors.primary.opacity(0.3),
                                        radius: 4,
                                        x: 0,
                                        y: 2
                                    )
                                
                                if viewModel.isSending {
                                    CompactLoadingView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .disabled(isMessageEmpty || viewModel.isSending)
                        .scaleEffect(isMessageEmpty || viewModel.isSending ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isMessageEmpty)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isSending)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    // 使用手动键盘避让，避免系统约束冲突
                    // 键盘避让已通过 ScrollView 的 padding 处理（见第 107 行的 keyboardPadding）
                }
            }
        }
        .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
        .navigationTitle(partner?.name ?? partner?.email ?? LocalizationKey.actionsChat.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .enableSwipeBack()
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onAppear {
            // 标记视图为可见，用于自动标记已读
            viewModel.isViewVisible = true
            
            if !appState.isAuthenticated {
                showLogin = true
            } else {
                // 只在消息为空时加载，避免重复加载
                if viewModel.messages.isEmpty {
                    viewModel.loadMessages()
                }
                viewModel.markAsRead()
                if let userId = getCurrentUserId() {
                    viewModel.connectWebSocket(currentUserId: userId)
                }
            }
        }
        .onDisappear {
            // 标记视图为不可见
            viewModel.isViewVisible = false
            // 清理错误状态，避免下次进入时显示旧错误
            viewModel.errorMessage = nil
            // 用户体验优化：视图消失时自动收起键盘
            isInputFocused = false
        }
        // 用户体验优化：点击空白区域隐藏键盘
        .contentShape(Rectangle())
        .onTapGesture {
            isInputFocused = false
            hideKeyboard()
        }
        .scrollDismissesKeyboard(.interactively)
    }
    
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty, !viewModel.isSending else { return }
        
        if !appState.isAuthenticated {
            showLogin = true
            return
        }
        
        let content = trimmedText
        messageText = "" // 立即清空输入框，提供即时反馈
        
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
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
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
    
    /// 滚动到底部（带防抖和动画支持）
    private func scrollToBottom(proxy: ScrollViewProxy, delay: TimeInterval = 0, animation: Animation? = nil) {
        // 取消之前的滚动任务
        scrollWorkItem?.cancel()
        
        guard let lastMessage = viewModel.messages.last else { return }
        let messageId = lastMessage.id
        
        // 如果消息ID没变，不需要滚动
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

/// 用于 fullScreenCover(item:) 的图片 URL 包装，避免 isPresented+if let 导致 content 为 EmptyView 出现全白无按钮
private struct IdentifiableImageUrl: Identifiable {
    let id = UUID()
    let url: String
}

// 消息气泡组件 - 更现代的设计
struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    @State private var selectedImageItem: IdentifiableImageUrl?
    @State private var selectedImageIndex: Int = 0
    @State private var showUserProfile = false
    
    // 翻译相关状态
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var showOriginal = false
    @State private var needsTranslation = false
    @State private var hasCheckedTranslation = false // 是否已检查过是否需要翻译
    @State private var showTranslationError = false // 显示翻译错误提示
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            } else {
                // 显示发送人头像（非当前用户的消息）- 左上角对齐
                Button(action: {
                    if message.senderId != nil {
                        showUserProfile = true
                    }
                }) {
                    AvatarView(
                        urlString: message.senderAvatar,
                        size: 36,
                        placeholder: Image(systemName: "person.circle.fill")
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.separator.opacity(0.2), lineWidth: 1)
                    )
                    .onAppear {
                        Logger.debug("显示发送者头像: \(message.senderAvatar ?? "nil"), 消息ID: \(message.id), isFromCurrentUser: \(isFromCurrentUser)", category: .ui)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // 发送人名字（仅非当前用户的消息显示）
                if !isFromCurrentUser, let senderName = message.senderName, !senderName.isEmpty {
                    Text(senderName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.bottom, 2)
                        .onAppear {
                            Logger.debug("显示发送者名字: \(senderName), 消息ID: \(message.id)", category: .ui)
                        }
                }
                
                // 附件显示（所有图片和文件）
                if let attachments = message.attachments, !attachments.isEmpty {
                    VStack(spacing: AppSpacing.xs) {
                        ForEach(attachments) { attachment in
                            if attachment.attachmentType == "image", let imageUrl = attachment.url {
                                Button(action: {
                                    // 收集所有图片URL用于全屏查看
                                    let allImageUrls = attachments
                                        .filter { $0.attachmentType == "image" }
                                        .compactMap { $0.url }
                                    if let index = allImageUrls.firstIndex(of: imageUrl) {
                                        selectedImageIndex = index
                                        selectedImageItem = IdentifiableImageUrl(url: imageUrl)
                                    }
                                }) {
                                    AsyncImageView(
                                        urlString: imageUrl,
                                        placeholder: Image(systemName: "photo"),
                                        width: 200,
                                        height: 150,
                                        contentMode: .fill,
                                        cornerRadius: AppCornerRadius.medium
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                    .shadow(color: isFromCurrentUser ? AppColors.primary.opacity(0.2) : AppShadow.small.color,
                                           radius: isFromCurrentUser ? 8 : AppShadow.small.radius,
                                           x: 0,
                                           y: isFromCurrentUser ? 4 : AppShadow.small.y)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            } else if attachment.attachmentType == "file", let fileUrl = attachment.url {
                                // 文件附件
                                Link(destination: URL(string: fileUrl) ?? URL(string: "https://www.link2ur.com")!) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(isFromCurrentUser ? .white : AppColors.primary)
                                        Text(LocalizationKey.chatEvidenceFile.localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(isFromCurrentUser ? .white : AppColors.primary)
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 14))
                                            .foregroundColor(isFromCurrentUser ? .white : AppColors.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isFromCurrentUser ? AppColors.primary.opacity(0.3) : AppColors.primary.opacity(0.1))
                                    .cornerRadius(AppCornerRadius.medium)
                                }
                            }
                        }
                    }
                }
                
                // 消息内容（如果不是纯图片消息）
                if let content = message.content, !content.isEmpty, content != "[图片]" {
                    VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                        // 显示翻译后的文本或原文（支持文本选择，用户可以使用系统翻译功能）
                        Text(showOriginal && !isFromCurrentUser ? content : (translatedText ?? content))
                            .font(AppTypography.body)
                            .foregroundColor(isFromCurrentUser ? .white : AppColors.textPrimary)
                            .textSelection(.enabled) // 启用文本选择，用户可以选择文本并使用系统翻译
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, 10)
                            .background(
                                Group {
                                    if isFromCurrentUser {
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    } else {
                                        AppColors.cardBackground
                                    }
                                }
                            )
                            .cornerRadius(AppCornerRadius.large)
                            .shadow(color: isFromCurrentUser ? AppColors.primary.opacity(0.2) : AppShadow.small.color, 
                                   radius: isFromCurrentUser ? 8 : AppShadow.small.radius, 
                                   x: 0, 
                                   y: isFromCurrentUser ? 4 : AppShadow.small.y)
                            .contextMenu {
                                // 长按菜单：复制消息
                                Button(action: {
                                    UIPasteboard.general.string = content
                                    // 使用 Haptic Feedback 提供触觉反馈
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                }) {
                                    Label(LocalizationKey.commonCopy.localized, systemImage: "doc.on.doc")
                                }
                                
                                // 翻译选项（仅非当前用户的消息）
                                if !isFromCurrentUser {
                                    Divider()
                                    
                                    if isTranslating {
                                        // 正在翻译中
                                        Button(action: {}) {
                                            Label(LocalizationKey.translationTranslating.localized, systemImage: "hourglass")
                                        }
                                        .disabled(true)
                                    } else if let translated = translatedText, translated != content {
                                        // 已翻译，显示切换原文/翻译选项
                                        Button(action: {
                                            showOriginal.toggle()
                                        }) {
                                            Label(
                                                showOriginal ? LocalizationKey.translationShowTranslation.localized : LocalizationKey.translationShowOriginal.localized,
                                                systemImage: showOriginal ? "text.bubble" : "arrow.uturn.backward"
                                            )
                                        }
                                    } else {
                                        // 未翻译，总是显示翻译选项（即使自动检测失败，也允许用户手动翻译）
                                        Button(action: {
                                            translateMessage(content: content)
                                        }) {
                                            Label(LocalizationKey.translationTranslate.localized, systemImage: "text.bubble")
                                        }
                                    }
                                }
                            }
                        
                        // 翻译状态指示（仅非当前用户的消息，正在翻译时显示）
                        if !isFromCurrentUser && isTranslating {
                            HStack(spacing: 6) {
                                CompactLoadingView()
                                Text(LocalizationKey.translationTranslating.localized)
                                    .font(AppTypography.caption2)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.top, 2)
                        }
                    }
                }
                
                // 时间戳（在消息气泡下方）
                if let createdAt = message.createdAt {
                    Text(formatTime(createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .sheet(isPresented: $showUserProfile) {
            if let senderId = message.senderId, !senderId.isEmpty {
                NavigationStack {
                    UserProfileView(userId: senderId)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(LocalizationKey.commonDone.localized) {
                                    showUserProfile = false
                                }
                            }
                        }
                }
            }
        }
        .fullScreenCover(item: $selectedImageItem) { item in
            // 收集所有图片URL用于全屏查看
            let allImageUrls = (message.attachments ?? [])
                .filter { $0.attachmentType == "image" }
                .compactMap { $0.url }
            FullScreenImageView(
                images: allImageUrls.isEmpty ? [item.url] : allImageUrls,
                selectedIndex: $selectedImageIndex,
                isPresented: Binding(get: { true }, set: { if !$0 { selectedImageItem = nil } })
            )
        }
        .onAppear {
            // 检查是否需要翻译（仅对非当前用户的消息，但不自动翻译）
            if !isFromCurrentUser, !hasCheckedTranslation, let content = message.content, !content.isEmpty, content != "[图片]" {
                // 先尝试从缓存恢复翻译状态
                restoreTranslationFromCache(content: content)
                // 然后检查是否需要翻译
                checkIfNeedsTranslation(content: content)
            }
        }
        .alert(LocalizationKey.translationFailed.localized, isPresented: $showTranslationError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) { }
        } message: {
            Text(LocalizationKey.translationRetryMessage.localized)
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
    
    /// 从缓存恢复翻译状态
    private func restoreTranslationFromCache(content: String) {
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            let targetLang = TranslationService.shared.getUserSystemLanguage()
            let sourceLang = TranslationService.shared.detectLanguage(content)
            
            // 尝试从缓存获取翻译
            if let cached = TranslationCacheManager.shared.getCachedTranslation(
                text: content,
                targetLanguage: targetLang,
                sourceLanguage: sourceLang
            ) {
                // 如果缓存中有翻译，恢复翻译状态
                translatedText = cached
                showOriginal = false // 默认显示翻译后的文本
                Logger.debug("从缓存恢复翻译: \(content.prefix(20))...", category: .cache)
            }
        }
    }
    
    /// 检查是否需要翻译（不自动翻译，延迟检测以优化性能）
    private func checkIfNeedsTranslation(content: String) {
        hasCheckedTranslation = true
        // 延迟检测，避免阻塞UI（如果已经有翻译，就不需要检测了）
        if translatedText != nil {
            return // 已经有翻译，跳过检测
        }
        
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            // 延迟检测，避免阻塞UI（优化性能：不在消息出现时立即检测）
            // 延迟500ms，让用户先看到消息，然后再在后台检测
            try? await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 延迟500ms
            
            // 如果在这期间用户已经翻译了，跳过检测
            guard translatedText == nil else { return }
            
            // 检查是否需要翻译
            let needs = TranslationService.shared.needsTranslation(content)
            needsTranslation = needs
        }
    }
    
    /// 手动翻译消息内容
    private func translateMessage(content: String) {
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            // 执行翻译
            isTranslating = true
            do {
                let translated = try await TranslationService.shared.translate(content)
                translatedText = translated
                // 默认显示翻译后的文本
                showOriginal = false
            } catch {
                Logger.error("翻译失败: \(error.localizedDescription)", category: .ui)
                // 翻译失败时显示原文
                translatedText = nil
                // 显示错误提示
                showTranslationError = true
            }
            isTranslating = false
        }
    }
}

// FullScreenImageView 定义在 Views/Shared/FullScreenImageView.swift

