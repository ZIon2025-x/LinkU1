import SwiftUI

/// 可刷新的滚动视图 - 企业级下拉刷新组件
public struct RefreshableScrollView<Content: View>: View {
    let content: Content
    let onRefresh: () async -> Void
    @State private var isRefreshing = false
    
    public init(
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    public var body: some View {
        ScrollView {
            content
                .refreshable {
                    await onRefresh()
                }
        }
    }
}

/// 可刷新的列表视图
public struct RefreshableList<Data: RandomAccessCollection, RowContent: View>: View where Data.Element: Identifiable {
    let data: Data
    let rowContent: (Data.Element) -> RowContent
    let onRefresh: () async -> Void
    
    public init(
        _ data: Data,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
    ) {
        self.data = data
        self.onRefresh = onRefresh
        self.rowContent = rowContent
    }
    
    public var body: some View {
        List(data) { item in
            rowContent(item)
        }
        .refreshable {
            await onRefresh()
        }
    }
}

