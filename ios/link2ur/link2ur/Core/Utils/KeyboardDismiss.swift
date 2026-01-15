import SwiftUI

/// 键盘关闭工具 - 企业级键盘管理

/// 统一的键盘关闭方法
public func hideKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}

extension View {
    /// 添加点击关闭键盘手势（点击空白区域关闭键盘）
    /// 使用 simultaneousGesture 确保不会阻止其他交互（如 NavigationLink）
    public func dismissKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    hideKeyboard()
                }
        )
    }
    
    /// 添加拖拽关闭键盘手势
    /// 使用 simultaneousGesture 确保不会阻止其他交互
    public func dismissKeyboardOnDrag() -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { _ in
                    hideKeyboard()
                }
        )
    }
}

/// 键盘关闭修饰符 - 点击空白区域关闭键盘
/// 使用 simultaneousGesture 避免阻止其他手势（如 NavigationLink 的点击）
public struct KeyboardDismissModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        hideKeyboard()
                    }
            )
    }
}

extension View {
    /// 应用键盘关闭修饰符（点击空白区域关闭键盘）
    /// 使用 simultaneousGesture 确保不会阻止 NavigationLink 等其他交互
    /// 使用示例：.keyboardDismissable()
    public func keyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
    
}

