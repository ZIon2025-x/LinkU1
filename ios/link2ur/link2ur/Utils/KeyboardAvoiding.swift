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
                self.keyboardHeight = max(0, keyboardHeight)
                
                // 获取动画信息
                if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                    self.keyboardAnimationDuration = duration
                }
                if let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
                   let curve = UIView.AnimationCurve(rawValue: curveValue) {
                    self.keyboardAnimationCurve = curve
                }
            }
            .store(in: &cancellables)
        
        // 监听键盘隐藏通知
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                self.keyboardHeight = 0
                
                // 获取动画信息
                if let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double {
                    self.keyboardAnimationDuration = duration
                }
                if let curveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
                   let curve = UIView.AnimationCurve(rawValue: curveValue) {
                    self.keyboardAnimationCurve = curve
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

/// 键盘避让修饰符（优化版 - 使用系统级键盘处理）
struct KeyboardAvoidingModifier: ViewModifier {
    var extraPadding: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
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
