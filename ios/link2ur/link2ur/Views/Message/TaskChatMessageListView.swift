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
    /// ✅ 修复：改名为更通用的 scrollAnimation，由外层决定传什么动画
    let scrollAnimation: Animation?
    
    private let bottomAnchorId = TaskChatConstants.bottomAnchorId
    
    var body: some View {
        // ✅ 修复：用外层 GeometryReader 拿到 ScrollView 可视高度
        GeometryReader { viewportGeo in
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
                    
                    // ✅ 修复：移除列表内容的 bottom padding
                    // 消息列表的可视区域只由 TaskChatView 的 .safeAreaInset(edge: .bottom) 决定
                    // 这样点击输入框时不会再出现"先到键盘上方、再到输入框上方"的第二步
                    }
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
                        .padding(.bottom, bottomInset + 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                // ✅ 修复：nearBottom 检测 - 直接测量 bottomAnchor 的 maxY 位置
                .onPreferenceChange(BottomAnchorMaxYPreferenceKey.self) { bottomMaxY in
                    let threshold: CGFloat = 200
                    let viewportHeight = viewportGeo.size.height
                    // bottomMaxY <= viewportHeight 代表底部锚点已经进入可视区域底部
                    // +threshold 代表"接近底部"的缓冲区
                    isNearBottom = bottomMaxY <= (viewportHeight + threshold)
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
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}
