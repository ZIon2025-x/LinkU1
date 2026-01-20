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
                    ForEach(Array(group.messages.enumerated()), id: \.element.id) { idx, message in
                        let pos = piecePosition(index: idx, count: group.messages.count)
                        let r = radii(for: pos, direction: group.direction)
                        
                        // 只渲染文本消息（图片消息等仍用单独的 MessageBubble）
                        if let content = message.content, !content.isEmpty, content != "[图片]" {
                            // 关键：先构建完整的气泡（包括背景、clip、shadow），再把 contextMenu 加在最外层
                            Text(content)
                                .font(AppTypography.body)
                                .foregroundColor(group.direction == .outgoing ? .white : AppColors.textPrimary)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    Group {
                                        if group.direction == .outgoing {
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
                                .clipShape(bubbleShape(r)) // 确保圆角边缘干净，不露出底层
                                .compositingGroup() // 组合渲染，确保圆角边缘干净
                                // 使用非常柔和的阴影，减少容器边界感（借鉴钱包余额视图的做法）
                                .shadow(color: group.direction == .outgoing 
                                    ? AppColors.primary.opacity(0.08) 
                                    : AppColors.primary.opacity(0.08), 
                                    radius: 12, x: 0, y: 4)
                                .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
                                .contentShape(bubbleShape(r)) // 使用相同的形状作为点击区域
                                // 关键：使用 .interaction 和 .contextMenuPreview 精确控制交互和预览区域（iOS 16+）
                                .contentShape(.interaction, bubbleShape(r)) // 精确控制交互区域
                                // 关键：contextMenu 必须加在已经 clip 过的气泡上，而不是外层容器
                                .contextMenu {
                                    // 长按菜单：复制消息
                                    Button(action: {
                                        UIPasteboard.general.string = content
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.success)
                                    }) {
                                        Label("复制", systemImage: "doc.on.doc")
                                    }
                                }
                                // iOS 17+ 优化：指定 context menu 预览形状，避免预览边缘漏底色
                                .modifier(ContextMenuPreviewShapeModifier(shape: bubbleShape(r)))
                        }
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

