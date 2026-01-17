import SwiftUI

/// 空状态视图 - 优雅的空内容展示
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    @State private var isAnimating = false
    @State private var iconScale: CGFloat = 1.0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    
    var body: some View {
        VStack(spacing: 28) {
            // 图标 - 分层系统蓝风格设计 + 丝滑动画
            ZStack {
                // 外层脉冲圈
                Circle()
                    .fill(AppColors.primary.opacity(0.04))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                    .opacity(isAnimating ? 0.5 : 0.8)
                
                // 中层圈
                Circle()
                    .fill(AppColors.primary.opacity(0.06))
                    .frame(width: 90, height: 90)
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                
                // 内层圈
                Circle()
                    .fill(AppColors.primary.opacity(0.08))
                    .frame(width: 70, height: 70)
                
                // 图标
                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppColors.primary)
                    .scaleEffect(iconScale)
                    .offset(y: isAnimating ? -3 : 3)
            }
            
            // 文字内容
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(5)
                
                // 可选的操作按钮
                if let actionTitle = actionTitle, let action = action {
                    Button(action: {
                        HapticFeedback.light()
                        action()
                    }) {
                        Text(actionTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(AppColors.primary)
                            )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.top, 8)
                }
            }
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.xl)
        .onAppear {
            // 图标浮动动画
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            
            // 图标呼吸动画
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3)) {
                iconScale = 1.08
            }
            
            // 内容入场动画
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0).delay(0.15)) {
                contentOpacity = 1
                contentOffset = 0
            }
        }
    }
}

/// 带动作的空状态视图快捷初始化
extension EmptyStateView {
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
}

// MARK: - 预览

#Preview("Empty State Views") {
    VStack(spacing: 40) {
        EmptyStateView(
            icon: "doc.text.fill",
            title: "暂无内容",
            message: "这里还没有任何内容，试试刷新或稍后再来"
        )
        .frame(height: 300)
        
        Divider()
        
        EmptyStateView(
            icon: "magnifyingglass",
            title: "未找到结果",
            message: "没有找到匹配的搜索结果，请尝试其他关键词",
            actionTitle: "重新搜索"
        ) {
            print("重新搜索")
        }
        .frame(height: 300)
    }
    .background(AppColors.background)
}

