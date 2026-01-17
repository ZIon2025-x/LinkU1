import SwiftUI

// MARK: - 刷新增强组件
// 提供丝滑流畅的下拉刷新体验

/// 刷新状态
enum RefreshState {
    case idle
    case pulling
    case refreshing
    case finished
}

/// 增强的刷新控制
struct RefreshControl: View {
    @Binding var isRefreshing: Bool
    @State private var pullProgress: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            let threshold: CGFloat = 60
            let offset = geometry.frame(in: .global).minY
            let progress = min(max(offset / threshold, 0), 1)
            
            HStack {
                Spacer()
                
                ZStack {
                    // 背景圆环
                    Circle()
                        .stroke(AppColors.primary.opacity(0.15), lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                    
                    if isRefreshing {
                        // 旋转加载动画
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(rotationAngle))
                    } else {
                        // 下拉进度弧
                        Circle()
                            .trim(from: 0, to: progress * 0.7)
                            .stroke(AppColors.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .frame(width: 28, height: 28)
                            .rotationEffect(.degrees(-90))
                    }
                }
                .scaleEffect(0.3 + progress * 0.7)
                .opacity(progress)
                
                Spacer()
            }
            .onChange(of: offset) { newOffset in
                if newOffset > threshold && !isRefreshing {
                    pullProgress = 1
                } else {
                    pullProgress = progress
                }
            }
            .onChange(of: isRefreshing) { refreshing in
                if refreshing {
                    HapticFeedback.pullToRefresh()
                    startRotation()
                } else {
                    stopRotation()
                }
            }
        }
        .frame(height: 60)
    }
    
    private func startRotation() {
        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
    }
    
    private func stopRotation() {
        withAnimation(.easeOut(duration: 0.3)) {
            rotationAngle = 0
        }
    }
}

// MARK: - 丝滑滚动视图

/// 增强的滚动视图，提供更好的滚动体验
struct SilkyScrollView<Content: View>: View {
    let axes: Axis.Set
    let showsIndicators: Bool
    let content: () -> Content
    
    @State private var contentOffset: CGFloat = 0
    @State private var isAtTop: Bool = true
    @State private var isAtBottom: Bool = false
    
    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
    }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollViewOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin
                        )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
            contentOffset = offset.y
            isAtTop = offset.y >= 0
        }
    }
}

private struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

// MARK: - 惯性滚动增强

/// 惯性滚动视图修饰符
struct InertialScrollModifier: ViewModifier {
    @State private var velocity: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        velocity = value.velocity.height
                    }
            )
    }
}

extension View {
    func inertialScroll() -> some View {
        modifier(InertialScrollModifier())
    }
}

// MARK: - 滚动到顶部

/// 滚动到顶部按钮
struct ScrollToTopButton: View {
    let action: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        Button(action: {
            HapticFeedback.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(AppColors.primary)
                        .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.5)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }
    
    func show(_ show: Bool) -> Self {
        var copy = self
        copy._isVisible = State(initialValue: show)
        return copy
    }
}

// MARK: - 滚动反馈修饰符

/// 滚动反馈修饰符 - 在到达边界时提供触觉反馈
struct ScrollBoundaryFeedbackModifier: ViewModifier {
    @State private var hasReachedTop = false
    @State private var hasReachedBottom = false
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { offset in
                // 到达顶部
                if offset.y > 20 && !hasReachedTop {
                    hasReachedTop = true
                    HapticFeedback.boundary()
                } else if offset.y <= 0 {
                    hasReachedTop = false
                }
            }
    }
}

extension View {
    func scrollBoundaryFeedback() -> some View {
        modifier(ScrollBoundaryFeedbackModifier())
    }
}

// MARK: - 视差滚动效果

/// 视差滚动头部
struct ParallaxHeader<Content: View>: View {
    let height: CGFloat
    let parallaxMultiplier: CGFloat
    let content: () -> Content
    
    init(
        height: CGFloat = 250,
        parallaxMultiplier: CGFloat = 0.5,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.height = height
        self.parallaxMultiplier = parallaxMultiplier
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            let offset = geometry.frame(in: .global).minY
            let adjustedHeight = offset > 0 ? height + offset : height
            let yOffset = offset > 0 ? -offset * parallaxMultiplier : 0
            
            content()
                .frame(width: geometry.size.width, height: adjustedHeight)
                .offset(y: yOffset)
                .clipped()
        }
        .frame(height: height)
    }
}

// MARK: - 预览

#Preview("Refresh Enhancements") {
    VStack {
        Text("刷新增强组件示例")
            .font(AppTypography.title2)
        
        Spacer()
        
        ScrollToTopButton {
            print("滚动到顶部")
        }
    }
    .padding()
    .background(AppColors.background)
}
