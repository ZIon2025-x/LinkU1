import Foundation
import SwiftUI
import Combine

/// 用于在异步回调中判断视图是否仍可见，避免在已销毁的 View 上更新 @State 导致崩溃。
/// 在 View 的 onAppear 中设 isVisible = true，onDisappear 中设 isVisible = false；
/// 在 completion/onError 等异步回调中先 guard holder.isVisible else { return } 再更新状态。
public final class ViewVisibilityHolder: ObservableObject {
    @Published public var isVisible = true

    public init() {}
}
