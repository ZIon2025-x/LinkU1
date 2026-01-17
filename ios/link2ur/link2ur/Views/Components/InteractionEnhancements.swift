import SwiftUI

// MARK: - 交互增强组件
// 提供丝滑流畅的用户交互体验

// MARK: - 列表入场动画

/// 列表项入场动画修饰符
struct ListItemAppearModifier: ViewModifier {
    let index: Int
    let totalItems: Int
    @State private var isVisible = false
    
    private var delay: Double {
        min(Double(index) * 0.04, 0.4) // 最大延迟0.4秒
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .scaleEffect(isVisible ? 1 : 0.97)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    /// 为列表项添加错落入场动画
    func listItemAppear(index: Int, totalItems: Int = 10) -> some View {
        modifier(ListItemAppearModifier(index: index, totalItems: totalItems))
    }
}

/// 带入场动画的LazyVStack
struct AnimatedLazyVStack<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    init(spacing: CGFloat = AppSpacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVStack(spacing: spacing) {
            content()
        }
    }
}

// MARK: - 卡片交互效果

/// 卡片按压效果修饰符
struct CardPressModifier: ViewModifier {
    @State private var isPressed = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            HapticFeedback.selection()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

extension View {
    /// 为卡片添加按压交互效果
    func cardPress(action: @escaping () -> Void) -> some View {
        modifier(CardPressModifier(action: action))
    }
}

// MARK: - 拉伸回弹效果

/// 拉伸回弹效果（用于下拉刷新区域）
struct StretchyHeader<Content: View>: View {
    let minHeight: CGFloat
    let content: () -> Content
    
    init(minHeight: CGFloat = 200, @ViewBuilder content: @escaping () -> Content) {
        self.minHeight = minHeight
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let offset = geometry.frame(in: .global).minY
            let height = max(minHeight, minHeight + offset)
            
            content()
                .frame(width: geometry.size.width, height: height)
                .clipped()
                .offset(y: offset > 0 ? -offset : 0)
        }
        .frame(minHeight: minHeight)
    }
}

// MARK: - 滑动删除效果

/// 滑动操作视图
struct SwipeActionView<Content: View>: View {
    let content: () -> Content
    let onDelete: (() -> Void)?
    let onEdit: (() -> Void)?
    
    @State private var offset: CGFloat = 0
    @State private var previousOffset: CGFloat = 0
    
    private let actionWidth: CGFloat = 80
    
    init(
        onDelete: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.onDelete = onDelete
        self.onEdit = onEdit
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // 背景操作按钮
            HStack(spacing: 0) {
                Spacer()
                
                if let onEdit = onEdit {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                        HapticFeedback.light()
                        onEdit()
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .frame(width: actionWidth, height: .infinity)
                            .background(AppColors.primary)
                    }
                }
                
                if let onDelete = onDelete {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = 0
                        }
                        HapticFeedback.delete()
                        onDelete()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .frame(width: actionWidth, height: .infinity)
                            .background(AppColors.error)
                    }
                }
            }
            
            // 主内容
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            let newOffset = previousOffset + translation
                            
                            // 限制滑动范围
                            let maxOffset = -CGFloat([onDelete, onEdit].compactMap { $0 }.count) * actionWidth
                            offset = min(0, max(maxOffset, newOffset))
                        }
                        .onEnded { value in
                            let threshold = actionWidth / 2
                            let maxOffset = -CGFloat([onDelete, onEdit].compactMap { $0 }.count) * actionWidth
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if offset < -threshold {
                                    offset = maxOffset
                                    HapticFeedback.soft()
                                } else {
                                    offset = 0
                                }
                            }
                            previousOffset = offset
                        }
                )
        }
    }
}

// MARK: - 页面过渡效果

/// 页面入场动画修饰符
struct PageAppearModifier: ViewModifier {
    @State private var isVisible = false
    let fromEdge: Edge
    let delay: Double
    
    init(fromEdge: Edge = .bottom, delay: Double = 0) {
        self.fromEdge = fromEdge
        self.delay = delay
    }
    
    private var offset: CGSize {
        switch fromEdge {
        case .top: return CGSize(width: 0, height: -30)
        case .bottom: return CGSize(width: 0, height: 30)
        case .leading: return CGSize(width: -30, height: 0)
        case .trailing: return CGSize(width: 30, height: 0)
        }
    }
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(isVisible ? .zero : offset)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0)) {
                        isVisible = true
                    }
                }
            }
    }
}

extension View {
    /// 添加页面入场动画
    func pageAppear(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        modifier(PageAppearModifier(fromEdge: edge, delay: delay))
    }
}

// MARK: - 放大镜效果（用于图片预览）

/// 放大镜效果视图 - 使用双击和捏合手势缩放
struct MagnifyingGlassView<Content: View>: View {
    let content: () -> Content
    @State private var scale: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    var body: some View {
        content()
            .scaleEffect(scale * magnifyBy)
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newScale = scale * value
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            scale = min(max(newScale, 1.0), 4.0)
                        }
                        HapticFeedback.soft()
                    }
            )
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            scale = scale > 1.0 ? 1.0 : 2.0
                        }
                        HapticFeedback.light()
                    }
            )
    }
}

// MARK: - 弹性下拉效果

/// 弹性滚动修饰符
struct ElasticScrollModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        GeometryReader { outer in
            ScrollView {
                content
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: InteractionScrollOffsetKey.self,
                                value: inner.frame(in: .named("scroll")).minY
                            )
                        }
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(InteractionScrollOffsetKey.self) { value in
                offset = value
            }
        }
    }
}

private struct InteractionScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 脉冲效果

/// 脉冲动画修饰符（用于吸引注意力）
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let duration: Double
    let scale: CGFloat
    
    init(duration: Double = 1.5, scale: CGFloat = 1.05) {
        self.duration = duration
        self.scale = scale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? scale : 1.0)
            .opacity(isPulsing ? 0.9 : 1.0)
            .onAppear {
                withAnimation(
                    Animation
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                ) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// 添加脉冲效果
    func pulse(duration: Double = 1.5, scale: CGFloat = 1.05) -> some View {
        modifier(PulseModifier(duration: duration, scale: scale))
    }
}

// MARK: - 抖动效果

/// 抖动动画修饰符（用于错误提示）
struct ShakeModifier: ViewModifier {
    @Binding var isShaking: Bool
    let intensity: CGFloat
    
    init(isShaking: Binding<Bool>, intensity: CGFloat = 10) {
        self._isShaking = isShaking
        self.intensity = intensity
    }
    
    func body(content: Content) -> some View {
        content
            .offset(x: isShaking ? intensity : 0)
            .animation(
                isShaking
                    ? Animation.spring(response: 0.1, dampingFraction: 0.3).repeatCount(3, autoreverses: true)
                    : .default,
                value: isShaking
            )
            .onChange(of: isShaking) { shaking in
                if shaking {
                    HapticFeedback.error()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShaking = false
                    }
                }
            }
    }
}

extension View {
    /// 添加抖动效果
    func shake(isShaking: Binding<Bool>, intensity: CGFloat = 10) -> some View {
        modifier(ShakeModifier(isShaking: isShaking, intensity: intensity))
    }
}

// MARK: - 渐变边框效果

/// 渐变边框修饰符
struct GradientBorderModifier: ViewModifier {
    let colors: [Color]
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth
                    )
            )
    }
}

extension View {
    /// 添加渐变边框
    func gradientBorder(
        colors: [Color] = AppColors.gradientPrimary,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = AppCornerRadius.medium
    ) -> some View {
        modifier(GradientBorderModifier(colors: colors, lineWidth: lineWidth, cornerRadius: cornerRadius))
    }
}

// MARK: - 点击高亮效果

/// 点击高亮修饰符
struct TapHighlightModifier: ViewModifier {
    @State private var isHighlighted = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .brightness(isHighlighted ? -0.1 : 0)
            .animation(.easeOut(duration: 0.1), value: isHighlighted)
            .onTapGesture {
                isHighlighted = true
                HapticFeedback.light()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isHighlighted = false
                    action()
                }
            }
    }
}

extension View {
    /// 添加点击高亮效果
    func tapHighlight(action: @escaping () -> Void) -> some View {
        modifier(TapHighlightModifier(action: action))
    }
}

// MARK: - 预览

#Preview("Interaction Enhancements") {
    ScrollView {
        VStack(spacing: 32) {
            // 列表入场动画示例
            Text("列表入场动画")
                .font(AppTypography.bodyBold)
            
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.cardBackground)
                        .frame(height: 60)
                        .overlay(
                            Text("Item \(index + 1)")
                                .foregroundColor(AppColors.textPrimary)
                        )
                        .listItemAppear(index: index)
                }
            }
            
            Divider()
            
            // 脉冲效果示例
            Text("脉冲效果")
                .font(AppTypography.bodyBold)
            
            Circle()
                .fill(AppColors.primary)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "bell.fill")
                        .foregroundColor(.white)
                )
                .pulse()
            
            Divider()
            
            // 页面入场动画
            Text("页面入场动画")
                .font(AppTypography.bodyBold)
            
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(height: 80)
                    .pageAppear(from: .bottom, delay: 0)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.success.opacity(0.2))
                    .frame(height: 80)
                    .pageAppear(from: .bottom, delay: 0.1)
                
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.warning.opacity(0.2))
                    .frame(height: 80)
                    .pageAppear(from: .bottom, delay: 0.2)
            }
        }
        .padding()
    }
    .background(AppColors.background)
}
