import SwiftUI

/// ScrollViewReader 扩展 - 企业级滚动控制
extension ScrollViewReader {
    
    /// 滚动到顶部
    public static func scrollToTop(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("top", anchor: .top)
        }
    }
    
    /// 滚动到底部
    public static func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    /// 滚动到指定 ID
    public static func scrollTo(
        id: String,
        anchor: UnitPoint = .center,
        proxy: ScrollViewProxy
    ) {
        withAnimation {
            proxy.scrollTo(id, anchor: anchor)
        }
    }
}

/// 滚动视图扩展
extension View {
    /// 添加滚动到顶部/底部功能
    public func scrollable(
        scrollToTop: Binding<Bool>? = nil,
        scrollToBottom: Binding<Bool>? = nil
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                self.id("content")
            }
            .modifier(ScrollToTopModifier(
                scrollToTop: scrollToTop,
                proxy: proxy
            ))
            .modifier(ScrollToBottomModifier(
                scrollToBottom: scrollToBottom,
                proxy: proxy
            ))
        }
    }
}

private struct ScrollToTopModifier: ViewModifier {
    let scrollToTop: Binding<Bool>?
    let proxy: ScrollViewProxy
    
    func body(content: Content) -> some View {
        if let scrollToTop = scrollToTop {
            content.onChange(of: scrollToTop.wrappedValue) { newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                    scrollToTop.wrappedValue = false
                }
            }
        } else {
            content
        }
    }
}

private struct ScrollToBottomModifier: ViewModifier {
    let scrollToBottom: Binding<Bool>?
    let proxy: ScrollViewProxy
    
    func body(content: Content) -> some View {
        if let scrollToBottom = scrollToBottom {
            content.onChange(of: scrollToBottom.wrappedValue) { newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                    scrollToBottom.wrappedValue = false
                }
            }
        } else {
            content
        }
    }
}

