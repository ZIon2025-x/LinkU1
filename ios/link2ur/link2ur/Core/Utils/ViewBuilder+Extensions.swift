import SwiftUI

/// ViewBuilder 扩展 - 企业级视图构建工具

extension ViewBuilder {
    /// 条件视图构建
    public static func buildIf<Content: View>(
        _ condition: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if condition {
            return AnyView(content())
        } else {
            return AnyView(EmptyView())
        }
    }
    
    /// 可选视图构建
    public static func buildIf<Content: View>(
        _ optional: Content?,
        @ViewBuilder fallback: () -> Content = { EmptyView() }
    ) -> some View {
        if let content = optional {
            return AnyView(content)
        } else {
            return AnyView(fallback())
        }
    }
}

/// 便捷的视图构建扩展
extension View {
    /// 条件显示视图
    @ViewBuilder
    public func `if`<TrueContent: View>(
        _ condition: Bool,
        transform: (Self) -> TrueContent
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 条件显示视图（带 else）
    @ViewBuilder
    public func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
    /// 可选修饰符
    @ViewBuilder
    public func modifier<T: ViewModifier>(
        _ modifier: T?,
        fallback: ((Self) -> AnyView)? = nil
    ) -> some View {
        if let modifier = modifier {
            AnyView(self.modifier(modifier))
        } else if let fallback = fallback {
            fallback(self)
        } else {
            AnyView(self)
        }
    }
}

