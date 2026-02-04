import SwiftUI
import Combine

// MARK: - 键盘避让工具

/// 键盘高度观察者（优化版）
class KeyboardHeightObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var keyboardAnimationDuration: Double = 0.25
    @Published var keyboardAnimationCurve: UIView.AnimationCurve = .easeInOut
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 监听键盘显示通知 - 使用 keyboardWillShow 获取动画信息
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // 获取键盘frame
                guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                    return
                }
                
                // 获取屏幕高度
                let screenHeight = UIScreen.main.bounds.height
                
                // 计算键盘高度（键盘frame已经是相对于屏幕的）
                // keyboardFrame.origin.y 是键盘顶部位置，从屏幕底部到键盘顶部的距离就是键盘高度
                let keyboardHeight = screenHeight - keyboardFrame.origin.y
                
                // 获取动画信息
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
                let curve = curveValue.flatMap { UIView.AnimationCurve(rawValue: $0) }
                
                // 使用异步方式更新状态，避免在视图更新期间发布变更
                DispatchQueue.main.async {
                    self.keyboardHeight = max(0, keyboardHeight)
                    if let duration = duration {
                        self.keyboardAnimationDuration = duration
                    }
                    if let curve = curve {
                        self.keyboardAnimationCurve = curve
                    }
                }
            }
            .store(in: &cancellables)
        
        // 监听键盘隐藏通知
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // 获取动画信息
                let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
                let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int
                let curve = curveValue.flatMap { UIView.AnimationCurve(rawValue: $0) }
                
                // 使用异步方式更新状态，避免在视图更新期间发布变更
                DispatchQueue.main.async {
                    self.keyboardHeight = 0
                    if let duration = duration {
                        self.keyboardAnimationDuration = duration
                    }
                    if let curve = curve {
                        self.keyboardAnimationCurve = curve
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 获取键盘动画
    var keyboardAnimation: Animation {
        let timingCurve: Animation
        switch keyboardAnimationCurve {
        case .easeInOut:
            timingCurve = .easeInOut(duration: keyboardAnimationDuration)
        case .easeIn:
            timingCurve = .easeIn(duration: keyboardAnimationDuration)
        case .easeOut:
            timingCurve = .easeOut(duration: keyboardAnimationDuration)
        case .linear:
            timingCurve = .linear(duration: keyboardAnimationDuration)
        @unknown default:
            timingCurve = .easeInOut(duration: keyboardAnimationDuration)
        }
        return timingCurve
    }
}

/// 键盘避让修饰符（已弃用 - 可能导致约束冲突）
/// 建议使用 KeyboardHeightObserver 手动处理键盘避让
/// 或使用 KeyboardAvoidingScrollView 组件
struct KeyboardAvoidingModifier: ViewModifier {
    var extraPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            // ⚠️ 注意：此方法可能导致 Auto Layout 约束冲突
            // 建议使用 KeyboardHeightObserver 手动处理键盘避让
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

extension View {
    /// 应用键盘避让
    func keyboardAvoiding(extraPadding: CGFloat = 0) -> some View {
        modifier(KeyboardAvoidingModifier(extraPadding: extraPadding))
    }
}

/// 键盘避让ScrollView包装器（优化版）
struct KeyboardAvoidingScrollView<Content: View>: View {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    let content: Content
    var showsIndicators: Bool = true
    var extraPadding: CGFloat = 0
    
    init(showsIndicators: Bool = true, extraPadding: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.extraPadding = extraPadding
        self.content = content()
    }
    
    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            VStack(spacing: 0) {
                content
                
                // 底部间距，确保内容在键盘上方可见
                // 使用系统级键盘处理，避免约束冲突
                if keyboardObserver.keyboardHeight > 0 {
                    Spacer()
                        .frame(height: keyboardObserver.keyboardHeight + extraPadding)
                        .transition(.opacity)
                }
            }
        }
        .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
    }
}

/// 自动滚动到焦点输入框的ScrollView
struct AutoScrollScrollView<Content: View>: View {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    let content: Content
    var showsIndicators: Bool = true
    var scrollToId: AnyHashable?
    
    init(showsIndicators: Bool = true, scrollToId: AnyHashable? = nil, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.scrollToId = scrollToId
        self.content = content()
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: showsIndicators) {
                content
                    .padding(.bottom, keyboardObserver.keyboardHeight > 0 ? keyboardObserver.keyboardHeight + 20 : 0)
            }
            .onChange(of: keyboardObserver.keyboardHeight) { height in
                if height > 0, let id = scrollToId {
                    // 键盘出现时，滚动到指定ID
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: keyboardObserver.keyboardHeight)
        }
    }
}

/// 带焦点追踪的键盘避让ScrollView（增强版）
/// 自动滚动到当前焦点的输入框
struct FocusAwareScrollView<Content: View, FocusField: Hashable>: View {
    @StateObject private var keyboardObserver = KeyboardHeightObserver()
    let content: (ScrollViewProxy) -> Content
    let focusedField: FocusField?
    var showsIndicators: Bool
    var extraPadding: CGFloat
    
    init(
        focusedField: FocusField?,
        showsIndicators: Bool = true,
        extraPadding: CGFloat = 20,
        @ViewBuilder content: @escaping (ScrollViewProxy) -> Content
    ) {
        self.focusedField = focusedField
        self.showsIndicators = showsIndicators
        self.extraPadding = extraPadding
        self.content = content
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: showsIndicators) {
                VStack(spacing: 0) {
                    content(proxy)
                    
                    // 底部间距，确保内容在键盘上方可见
                    if keyboardObserver.keyboardHeight > 0 {
                        Spacer()
                            .frame(height: keyboardObserver.keyboardHeight + extraPadding)
                            .transition(.opacity)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { newField in
                if let field = newField {
                    // 焦点变化时，延迟滚动以确保键盘已经显示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: keyboardObserver.keyboardHeight) { height in
                // 键盘高度变化时，如果有焦点，滚动到焦点位置
                if height > 0, let field = focusedField {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
        }
        .animation(keyboardObserver.keyboardAnimation, value: keyboardObserver.keyboardHeight)
    }
}

// MARK: - View 扩展

extension View {
    /// 隐藏键盘
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// 添加键盘工具栏（带完成按钮）
    func keyboardDismissToolbar() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(LocalizationKey.commonDone.localized) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
}
