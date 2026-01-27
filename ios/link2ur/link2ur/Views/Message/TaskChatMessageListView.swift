import SwiftUI

/// 任务聊天消息列表视图
/// 关键：永远用输入区真实高度作为 bottom inset，保证消息不被输入区盖住
struct TaskChatMessageListView: View {
    let messages: [Message]
    let currentUserId: String?
    
    /// 关键：永远用输入区真实高度作为 bottom inset，保证消息不被输入区盖住
    let bottomInset: CGFloat
    
    @Binding var scrollToBottomTrigger: Int
    @Binding var isNearBottom: Bool
    @Binding var showNewMessageButton: Bool
    
    /// 滚动动画（用于同步滚动动画，可以是键盘动画或面板动画）
    let scrollAnimation: Animation?
    
    /// 是否正在加载（首次加载时在消息区显示 Loading，避免「暂无消息」的误导）
    let isLoading: Bool
    
    /// 下拉刷新回调（聊天内支持下拉重拉消息）
    let onRefresh: () -> Void
    
    private let bottomAnchorId = TaskChatConstants.bottomAnchorId
    
    var body: some View {
        GeometryReader { viewportGeo in
            if isLoading && messages.isEmpty {
                LoadingView(message: LocalizationKey.commonLoading.localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.sm) {
                                if messages.isEmpty {
                                    emptyState
                                } else {
                                // 使用分组渲染逻辑
                                ForEach(renderItems, id: \.id) { item in
                                    switch item {
                                    case .systemMessage(let message):
                                        TaskChatSystemMessageBubble(message: message)
                                            .id(message.id)
                                    case .groupBubble(let group):
                                        MessageGroupBubbleView(group: group)
                                            .id("group_\(group.messages.first?.id ?? "")")
                                    case .singleMessage(let message):
                                        MessageBubble(
                                            message: message,
                                            isFromCurrentUser: isFromCurrentUser(message)
                                        )
                                        .id(message.id)
                                    }
                                }
                                
                                // ✅ 永久底部锚点：WhatsApp 风格"贴底"就靠它
                                Color.clear
                                    .frame(height: 1)
                                    .id(bottomAnchorId)
                                    // ✅ 修复：测量 bottomAnchor 的 maxY 位置
                                    .background(
                                        GeometryReader { anchorGeo in
                                            Color.clear.preference(
                                                key: BottomAnchorMaxYPreferenceKey.self,
                                                value: anchorGeo.frame(in: .named("task_chat_scroll")).maxY
                                            )
                                        }
                                    )
                            }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    }
                    .refreshable { onRefresh() }
                    .coordinateSpace(name: "task_chat_scroll")
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively) // ✅ 对标 WhatsApp：拖动列表收起键盘
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // ✅ 确保 ScrollView 填充可用空间
                    
                    // 触发滚到底部：只滚 bottom anchor，不滚 lastMessage.id
                    .onChange(of: scrollToBottomTrigger) { _ in
                        DispatchQueue.main.async {
                            // ✅ 修复：如果有滚动动画，使用滚动动画；否则使用默认动画
                            // 这样面板展开时的滚动动画也能和面板动画同频
                            if let animation = scrollAnimation {
                                withAnimation(animation) {
                                    proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                                }
                            }
                            showNewMessageButton = false
                        }
                    }
                    
                    // 新消息提示按钮
                    if showNewMessageButton {
                        Button {
                            // ✅ 修复：用户主动点击新消息按钮，立即响应，不使用防抖
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                            }
                            showNewMessageButton = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(LocalizationKey.notificationNewMessage.localized)
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
                        .padding(.bottom, bottomInset + 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                // ✅ 修复：nearBottom 检测 - 直接测量 bottomAnchor 的 maxY 位置
                .onPreferenceChange(BottomAnchorMaxYPreferenceKey.self) { bottomMaxY in
                    let threshold: CGFloat = 200
                    let viewportHeight = viewportGeo.size.height
                    isNearBottom = bottomMaxY <= (viewportHeight + threshold)
                }
            }
            }
        }
    }
    
    private var emptyState: some View {
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
    }
    
    private func isFromCurrentUser(_ message: Message) -> Bool {
        guard let senderId = message.senderId, let currentUserId = currentUserId else {
            return false
        }
        return senderId == currentUserId
    }
    
    private func isSystemMessage(_ message: Message) -> Bool {
        // 系统消息的特征：msgType 为 system，或者 senderId 为 nil
        return message.msgType == .system || message.senderId == nil
    }
    
    /// 判断消息是否应该参与分组（只有纯文本消息才参与分组）
    private func shouldGroupMessage(_ message: Message) -> Bool {
        // 系统消息不参与分组
        if isSystemMessage(message) {
            return false
        }
        
        // 有图片附件的消息不参与分组
        if message.hasImageAttachment {
            return false
        }
        
        // 内容为空或为"[图片]"的消息不参与分组
        if let content = message.content, !content.isEmpty, content != "[图片]" {
            return true
        }
        
        return false
    }
    
    /// 渲染项枚举
    private enum RenderItem: Identifiable {
        case systemMessage(Message)
        case groupBubble(MessageGroup)
        case singleMessage(Message)
        
        var id: String {
            switch self {
            case .systemMessage(let msg):
                return "system_\(msg.id)"
            case .groupBubble(let group):
                return "group_\(group.messages.first?.id ?? "")"
            case .singleMessage(let msg):
                return "single_\(msg.id)"
            }
        }
    }
    
    /// 生成渲染项列表（混合系统消息、分组消息和单独消息）
    private var renderItems: [RenderItem] {
        var items: [RenderItem] = []
        var textMessages: [Message] = []
        
        for message in messages {
            if isSystemMessage(message) {
                // 如果当前有文本消息组，先保存
                if !textMessages.isEmpty {
                    let groups = groupMessages(textMessages, currentUserId: currentUserId)
                    for group in groups {
                        items.append(.groupBubble(group))
                    }
                    textMessages = []
                }
                // 系统消息单独渲染
                items.append(.systemMessage(message))
            } else if shouldGroupMessage(message) {
                // 可以分组的文本消息，先收集
                textMessages.append(message)
            } else {
                // 不能分组的消息（如图片消息），先保存当前文本消息组
                if !textMessages.isEmpty {
                    let groups = groupMessages(textMessages, currentUserId: currentUserId)
                    for group in groups {
                        items.append(.groupBubble(group))
                    }
                    textMessages = []
                }
                // 单独渲染
                items.append(.singleMessage(message))
            }
        }
        
        // 处理剩余的文本消息组
        if !textMessages.isEmpty {
            let groups = groupMessages(textMessages, currentUserId: currentUserId)
            for group in groups {
                items.append(.groupBubble(group))
            }
        }
        
        return items
    }
}

// MARK: - PreferenceKey for Bottom Anchor Detection

/// ✅ 修复：用于检测底部锚点位置的 PreferenceKey
private struct BottomAnchorMaxYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - System Message Bubble

/// 系统消息气泡组件 - 居中显示，样式与普通消息区分
struct TaskChatSystemMessageBubble: View {
    let message: Message
    @State private var selectedImageItem: IdentifiableImageUrl?
    @State private var selectedImageIndex: Int = 0
    
    // 检查是否是退款申请系统消息
    private var isRefundMessage: Bool {
        guard let content = message.content else { return false }
        return content.contains("申请退款") || content.contains("退款") || content.contains("refund")
    }
    
    private var isRefundCompleted: Bool {
        guard let content = message.content else { return false }
        return content.contains("退款已完成") || content.contains("退款完成") || content.contains("refund completed")
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: AppSpacing.sm) {
                // 如果是退款申请消息，使用卡片式布局
                if isRefundMessage {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        // 标题和图标
                        HStack(spacing: 8) {
                            Image(systemName: isRefundCompleted ? "checkmark.circle.fill" : "dollarsign.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(isRefundCompleted ? AppColors.success : AppColors.warning)
                            
                            Text(isRefundCompleted ? "退款已完成" : "退款申请")
                                .font(AppTypography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(isRefundCompleted ? AppColors.success : AppColors.warning)
                        }
                        
                        // 消息内容
                        Text(message.displayContent ?? LocalizationKey.notificationSystemMessage.localized)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: 300)
                    .background(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(isRefundCompleted ? AppColors.success.opacity(0.1) : AppColors.warning.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .stroke(isRefundCompleted ? AppColors.success.opacity(0.3) : AppColors.warning.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    // 普通系统消息
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
                }
                
                // 附件显示（证据图片/文件）
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
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            } else if attachment.attachmentType == "file", let fileUrl = attachment.url {
                                // 文件附件
                                if let url = URL(string: fileUrl) {
                                    Link(destination: url) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "doc.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(AppColors.primary)
                                            Text("证据文件")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.primary)
                                            Image(systemName: "arrow.down.circle")
                                                .font(.system(size: 14))
                                                .foregroundColor(AppColors.primary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(AppColors.primary.opacity(0.1))
                                        .cornerRadius(AppCornerRadius.medium)
                                    }
                                } else {
                                    // 如果URL无效，显示文件图标
                                    HStack(spacing: 8) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.textSecondary)
                                        Text("证据文件")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColors.cardBackground)
                                    .cornerRadius(AppCornerRadius.medium)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                
                // 时间戳（可选）
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
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

/// 用于 fullScreenCover(item:) 的图片 URL 包装
private struct IdentifiableImageUrl: Identifiable {
    let id = UUID()
    let url: String
}
