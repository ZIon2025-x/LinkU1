import SwiftUI

/// 键盘关闭工具 - 企业级键盘管理

extension View {
    /// 添加点击关闭键盘手势
    public func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
    
    /// 添加拖拽关闭键盘手势
    public func dismissKeyboardOnDrag() -> some View {
        self.gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { _ in
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
        )
    }
}

/// 键盘关闭修饰符
public struct KeyboardDismissModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    /// 应用键盘关闭修饰符
    public func keyboardDismissable() -> some View {
        modifier(KeyboardDismissModifier())
    }
}

