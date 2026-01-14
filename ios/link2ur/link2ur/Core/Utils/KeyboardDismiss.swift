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
    /// 优化：使用 contentShape 确保整个区域可点击，但不影响其他交互
    public func dismissKeyboardOnTap() -> some View {
        self.contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    /// 添加拖拽关闭键盘手势
    public func dismissKeyboardOnDrag() -> some View {
        self.gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { _ in
                    hideKeyboard()
                }
        )
    }
}

/// 键盘关闭修饰符 - 点击空白区域关闭键盘
public struct KeyboardDismissModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
    }
}

extension View {
    /// 应用键盘关闭修饰符（点击空白区域关闭键盘）
    /// 使用示例：.keyboardDismissable()
    public func keyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
    
}

