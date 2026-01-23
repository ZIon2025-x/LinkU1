import SwiftUI

// MARK: - 方向枚举

enum BubbleDirection {
    case incoming   // 对方（靠左）
    case outgoing   // 自己（靠右）
}

// MARK: - 位置枚举

enum BubblePiecePosition {
    case single
    case top
    case middle
    case bottom
}

// MARK: - 四角半径结构

struct CornerRadii: Equatable {
    var tl: CGFloat  // top leading (左上)
    var tr: CGFloat  // top trailing (右上)
    var bl: CGFloat  // bottom leading (左下)
    var br: CGFloat  // bottom trailing (右下)
}

// MARK: - 圆角计算函数

/// 根据位置和方向计算四角半径
func radii(for position: BubblePiecePosition, direction: BubbleDirection) -> CornerRadii {
    let R: CGFloat = 18  // 主圆角
    let S: CGFloat = 4   // 拼接处/外侧矩形感（想更"矩形"就改成 0）

    let isIncoming = (direction == .incoming)

    switch position {
    case .single:
        return CornerRadii(tl: R, tr: R, bl: R, br: R)

    case .top:
        // 顶部两角保持圆；底部外侧收直以拼接；底部内侧仍圆（更柔和）
        if isIncoming {
            return CornerRadii(tl: R, tr: R, bl: S, br: R)
        } else {
            return CornerRadii(tl: R, tr: R, bl: R, br: S)
        }

    case .middle:
        // 上下外侧都收直，形成"侧边直线"；内侧上下保持圆
        if isIncoming {
            return CornerRadii(tl: S, tr: R, bl: S, br: R)
        } else {
            return CornerRadii(tl: R, tr: S, bl: R, br: S)
        }

    case .bottom:
        // 顶部外侧收直拼接；底部两角圆（但外侧更强调"朝外圆"）
        if isIncoming {
            return CornerRadii(tl: S, tr: R, bl: R, br: R)
        } else {
            return CornerRadii(tl: R, tr: S, bl: R, br: R)
        }
    }
}

// MARK: - 四角圆角 Shape

/// iOS 16 及以下兜底 Shape（支持四角分别设置圆角）
struct RoundedCornerShape: Shape {
    let radii: CornerRadii

    func path(in rect: CGRect) -> Path {
        let tl = min(min(radii.tl, rect.width/2), rect.height/2)
        let tr = min(min(radii.tr, rect.width/2), rect.height/2)
        let bl = min(min(radii.bl, rect.width/2), rect.height/2)
        let br = min(min(radii.br, rect.width/2), rect.height/2)

        var p = Path()

        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))

        // top edge -> top right
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                 radius: tr,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(0),
                 clockwise: false)

        // right edge -> bottom right
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                 radius: br,
                 startAngle: .degrees(0),
                 endAngle: .degrees(90),
                 clockwise: false)

        // bottom edge -> bottom left
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                 radius: bl,
                 startAngle: .degrees(90),
                 endAngle: .degrees(180),
                 clockwise: false)

        // left edge -> top left
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                 radius: tl,
                 startAngle: .degrees(180),
                 endAngle: .degrees(270),
                 clockwise: false)

        p.closeSubpath()
        return p
    }
}

// MARK: - Bubble Shape（类型擦除包装器）

/// 自适应圆角 Shape，iOS 17+ 使用 UnevenRoundedRectangle，低版本使用自定义 Shape
struct AdaptiveRoundedShape: Shape {
    let radii: CornerRadii
    
    func path(in rect: CGRect) -> Path {
        if #available(iOS 17.0, *) {
            // iOS 17+ 使用系统原生实现
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: radii.tl,
                bottomLeadingRadius: radii.bl,
                bottomTrailingRadius: radii.br,
                topTrailingRadius: radii.tr
            )
            return shape.path(in: rect)
        } else {
            // iOS 16 及以下使用自定义实现
            return RoundedCornerShape(radii: radii).path(in: rect)
        }
    }
}

/// 创建自适应圆角 Shape 的辅助函数
func bubbleShape(_ r: CornerRadii) -> AdaptiveRoundedShape {
    AdaptiveRoundedShape(radii: r)
}

// MARK: - 消息组结构

struct MessageGroup {
    let messages: [Message]
    let direction: BubbleDirection
    let senderId: String?
    let senderName: String?
    let senderAvatar: String?
    
    init(messages: [Message], direction: BubbleDirection, senderId: String?, senderName: String?, senderAvatar: String?) {
        self.messages = messages
        self.direction = direction
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatar = senderAvatar
    }
}

// MARK: - 消息分组函数

/// 将消息列表按发送者和时间间隔分组
func groupMessages(_ messages: [Message], currentUserId: String?) -> [MessageGroup] {
    guard !messages.isEmpty else { return [] }
    
    var groups: [MessageGroup] = []
    var currentGroup: [Message] = []
    var currentSenderId: String? = nil
    var currentDirection: BubbleDirection? = nil
    var currentSenderName: String? = nil
    var currentSenderAvatar: String? = nil
    var lastMessageTime: Date? = nil
    
    // 时间间隔阈值（秒）：超过此时间间隔，即使同一发送者也会分组
    let timeThreshold: TimeInterval = 180 // 3分钟
    
    for message in messages {
        // 跳过系统消息（系统消息不参与分组）
        if message.msgType == .system || message.senderId == nil {
            // 如果当前组不为空，先保存当前组
            if !currentGroup.isEmpty {
                if let direction = currentDirection {
                    groups.append(MessageGroup(
                        messages: currentGroup,
                        direction: direction,
                        senderId: currentSenderId,
                        senderName: currentSenderName,
                        senderAvatar: currentSenderAvatar
                    ))
                }
                currentGroup = []
            }
            continue
        }
        
        let isFromCurrentUser = message.senderId == currentUserId
        let direction: BubbleDirection = isFromCurrentUser ? .outgoing : .incoming
        
        // 解析消息时间
        let messageTime: Date?
        if let createdAt = message.createdAt {
            messageTime = DateFormatterHelper.shared.parseDatePublic(createdAt)
        } else {
            messageTime = nil
        }
        
        // 判断是否应该开始新组
        let shouldStartNewGroup: Bool
        
        if currentGroup.isEmpty {
            // 当前组为空，直接开始新组
            shouldStartNewGroup = true
        } else if message.senderId != currentSenderId {
            // 发送者不同，开始新组
            shouldStartNewGroup = true
        } else if let msgTime = messageTime, let lastTime = lastMessageTime {
            // 检查时间间隔
            let timeDiff = msgTime.timeIntervalSince(lastTime)
            if timeDiff > timeThreshold {
                // 时间间隔超过阈值，开始新组
                shouldStartNewGroup = true
            } else {
                // 同一发送者且时间间隔较短，继续当前组
                shouldStartNewGroup = false
            }
        } else {
            // 无法确定时间，但发送者相同，继续当前组
            shouldStartNewGroup = false
        }
        
        if shouldStartNewGroup {
            // 保存当前组（如果非空）
            if !currentGroup.isEmpty, let direction = currentDirection {
                groups.append(MessageGroup(
                    messages: currentGroup,
                    direction: direction,
                    senderId: currentSenderId,
                    senderName: currentSenderName,
                    senderAvatar: currentSenderAvatar
                ))
            }
            
            // 开始新组
            currentGroup = [message]
            currentSenderId = message.senderId
            currentDirection = direction
            currentSenderName = message.senderName
            currentSenderAvatar = message.senderAvatar
            lastMessageTime = messageTime
        } else {
            // 继续当前组
            currentGroup.append(message)
            lastMessageTime = messageTime
        }
    }
    
    // 保存最后一组
    if !currentGroup.isEmpty, let direction = currentDirection {
        groups.append(MessageGroup(
            messages: currentGroup,
            direction: direction,
            senderId: currentSenderId,
            senderName: currentSenderName,
            senderAvatar: currentSenderAvatar
        ))
    }
    
    return groups
}

// MARK: - 分组气泡视图

struct MessageGroupBubbleView: View {
    let group: MessageGroup
    @State private var showUserProfile = false
    
    // 翻译相关状态（为每条消息维护独立的翻译状态）
    @State private var translatedTexts: [String: String] = [:] // message.id -> translatedText
    @State private var isTranslatingMessages: [String: Bool] = [:] // message.id -> isTranslating
    @State private var showOriginalMessages: [String: Bool] = [:] // message.id -> showOriginal
    @State private var showTranslationError = false // 显示翻译错误提示
    @State private var failedMessageId: String? // 翻译失败的消息ID
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            if group.direction == .outgoing {
                Spacer(minLength: 50)
            } else {
                // 显示发送人头像（仅第一组的第一条消息显示）
                Button(action: {
                    if group.senderId != nil {
                        showUserProfile = true
                    }
                }) {
                    AvatarView(
                        urlString: group.senderAvatar,
                        size: 36,
                        placeholder: Image(systemName: "person.circle.fill")
                    )
                    .overlay(
                        Circle()
                            .stroke(AppColors.separator.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            VStack(alignment: group.direction == .incoming ? .leading : .trailing, spacing: 4) {
                // 发送人名字（仅非当前用户的消息显示，且仅第一组显示）
                if group.direction == .incoming, let senderName = group.senderName, !senderName.isEmpty {
                    Text(senderName)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.bottom, 2)
                }
                
                // 分组气泡内容
                VStack(alignment: group.direction == .incoming ? .leading : .trailing, spacing: 2) {
                    ForEach(Array(group.messages), id: \.id) { message in
                        GroupMessageBubbleItem(
                            message: message,
                            index: group.messages.firstIndex(where: { $0.id == message.id }) ?? 0,
                            totalCount: group.messages.count,
                            direction: group.direction,
                            translatedTexts: $translatedTexts,
                            isTranslatingMessages: $isTranslatingMessages,
                            showOriginalMessages: $showOriginalMessages,
                            showTranslationError: $showTranslationError,
                            onRestoreTranslation: { messageId, content in
                                restoreTranslationFromCache(messageId: messageId, content: content)
                            },
                            onTranslate: { messageId, content in
                                translateMessage(messageId: messageId, content: content)
                            }
                        )
                    }
                }
                
                // 时间戳（仅最后一条消息显示）
                if let lastMessage = group.messages.last, let createdAt = lastMessage.createdAt {
                    Text(formatTime(createdAt))
                        .font(AppTypography.caption2)
                        .foregroundColor(AppColors.textTertiary)
                        .padding(.horizontal, AppSpacing.xs)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: group.direction == .incoming ? .leading : .trailing)
            
            if group.direction == .incoming {
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.xs)
        .sheet(isPresented: $showUserProfile) {
            if let senderId = group.senderId, !senderId.isEmpty {
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
        .alert("翻译失败", isPresented: $showTranslationError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("无法翻译此消息，请检查网络连接后重试")
        }
    }
    
    private func piecePosition(index: Int, count: Int) -> BubblePiecePosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
    
    /// 从缓存恢复翻译状态
    private func restoreTranslationFromCache(messageId: String, content: String) {
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            // 如果已经有翻译状态，跳过
            if translatedTexts[messageId] != nil {
                return
            }
            
            let targetLang = TranslationService.shared.getUserSystemLanguage()
            let sourceLang = TranslationService.shared.detectLanguage(content)
            
            // 尝试从缓存获取翻译
            if let cached = TranslationCacheManager.shared.getCachedTranslation(
                text: content,
                targetLanguage: targetLang,
                sourceLanguage: sourceLang
            ) {
                // 如果缓存中有翻译，恢复翻译状态
                translatedTexts[messageId] = cached
                showOriginalMessages[messageId] = false // 默认显示翻译后的文本
                Logger.debug("从缓存恢复翻译: \(content.prefix(20))...", category: .cache)
            }
        }
    }
    
    /// 翻译消息内容
    private func translateMessage(messageId: String, content: String) {
        isTranslatingMessages[messageId] = true
        // 使用 _Concurrency.Task 避免与项目中的 Task 模型冲突
        _Concurrency.Task { @MainActor in
            do {
                let translated = try await TranslationService.shared.translate(content)
                translatedTexts[messageId] = translated
                showOriginalMessages[messageId] = false
            } catch {
                Logger.error("翻译失败: \(error.localizedDescription)", category: .ui)
                failedMessageId = messageId
                showTranslationError = true
            }
            isTranslatingMessages[messageId] = false
        }
    }
}

// MARK: - Context Menu Preview Shape Modifier (iOS 17+)

/// iOS 17+ 优化：指定 context menu 预览形状，避免预览边缘漏底色
struct ContextMenuPreviewShapeModifier: ViewModifier {
    let shape: any Shape
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentShape(.contextMenuPreview, AnyShape(shape))
        } else {
            content
        }
    }
}

/// 类型擦除的 Shape 包装器
struct AnyShape: Shape {
    private let _path: @Sendable (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        _path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

// MARK: - 分组消息气泡项（用于简化类型检查）

struct GroupMessageBubbleItem: View {
    let message: Message
    let index: Int
    let totalCount: Int
    let direction: BubbleDirection
    @Binding var translatedTexts: [String: String]
    @Binding var isTranslatingMessages: [String: Bool]
    @Binding var showOriginalMessages: [String: Bool]
    @Binding var showTranslationError: Bool
    let onRestoreTranslation: (String, String) -> Void
    let onTranslate: (String, String) -> Void
    
    var body: some View {
        let pos = piecePosition(index: index, count: totalCount)
        let r = radii(for: pos, direction: direction)
        
        // 只渲染文本消息（图片消息等仍用单独的 MessageBubble）
        if let content = message.content, !content.isEmpty, content != "[图片]" {
            let messageId = message.id
            let isTranslating = isTranslatingMessages[messageId] ?? false
            let translatedText = translatedTexts[messageId]
            let showOriginal = showOriginalMessages[messageId] ?? false
            let isFromCurrentUser = direction == .outgoing
            
            // 显示翻译后的文本或原文
            let displayText = (showOriginal && !isFromCurrentUser) ? content : (translatedText ?? content)
            
            // 在消息出现时，尝试从缓存恢复翻译状态（仅非当前用户的消息）
            if !isFromCurrentUser && translatedText == nil {
                let _ = onRestoreTranslation(messageId, content)
            }
            
            // 关键：先构建完整的气泡（包括背景、clip、shadow），再把 contextMenu 加在最外层
            Text(displayText)
                .font(AppTypography.body)
                .foregroundColor(direction == .outgoing ? .white : AppColors.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if direction == .outgoing {
                            bubbleShape(r)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: AppColors.gradientPrimary),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        } else {
                            bubbleShape(r)
                                .fill(AppColors.cardBackground)
                        }
                    }
                )
                .clipShape(bubbleShape(r))
                .compositingGroup()
                .shadow(color: AppColors.primary.opacity(0.08), radius: 12, x: 0, y: 4)
                .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
                .contentShape(bubbleShape(r))
                .contentShape(.interaction, bubbleShape(r))
                .contextMenu {
                    // 长按菜单：复制消息
                    Button(action: {
                        UIPasteboard.general.string = content
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }) {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                    
                    // 翻译选项（仅非当前用户的消息）
                    if !isFromCurrentUser {
                        Divider()
                        
                        if isTranslating {
                            Button(action: {}) {
                                Label(LocalizationKey.translationTranslating.localized, systemImage: "hourglass")
                            }
                            .disabled(true)
                        } else if let translated = translatedText, translated != content {
                            Button(action: {
                                showOriginalMessages[messageId] = !showOriginal
                            }) {
                                Label(
                                    showOriginal ? LocalizationKey.translationShowTranslation.localized : LocalizationKey.translationShowOriginal.localized,
                                    systemImage: showOriginal ? "text.bubble" : "arrow.uturn.backward"
                                )
                            }
                        } else {
                            Button(action: {
                                onTranslate(messageId, content)
                            }) {
                                Label(LocalizationKey.translationTranslate.localized, systemImage: "text.bubble")
                            }
                        }
                    }
                }
                .modifier(ContextMenuPreviewShapeModifier(shape: bubbleShape(r)))
        }
    }
    
    private func piecePosition(index: Int, count: Int) -> BubblePiecePosition {
        if count <= 1 { return .single }
        if index == 0 { return .top }
        if index == count - 1 { return .bottom }
        return .middle
    }
}
