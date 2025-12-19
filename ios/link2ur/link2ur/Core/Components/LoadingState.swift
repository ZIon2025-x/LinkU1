import SwiftUI

/// 加载状态组件 - 企业级加载状态管理
public enum LoadingState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
    
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    public var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    public var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
}

/// 加载状态视图修饰符
public struct LoadingStateViewModifier<T>: ViewModifier {
    let state: LoadingState<T>
    let loadingView: AnyView?
    let errorView: ((Error) -> AnyView)?
    let emptyView: AnyView?
    
    public init(
        state: LoadingState<T>,
        loadingView: AnyView? = nil,
        errorView: ((Error) -> AnyView)? = nil,
        emptyView: AnyView? = nil
    ) {
        self.state = state
        self.loadingView = loadingView
        self.errorView = errorView
        self.emptyView = emptyView
    }
    
    @ViewBuilder
    public func body(content: Content) -> some View {
        switch state {
        case .idle:
            if let emptyView = emptyView {
                emptyView
            } else {
                content
            }
        case .loading:
            if let loadingView = loadingView {
                loadingView
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .success:
            content
        case .failure(let error):
            if let errorView = errorView {
                errorView(error)
            } else {
                // 获取用户友好的错误消息
                ErrorStateView(message: (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription)
            }
        }
    }
}

extension View {
    /// 应用加载状态视图
    public func loadingState<T>(
        _ state: LoadingState<T>,
        loadingView: AnyView? = nil,
        errorView: ((Error) -> AnyView)? = nil,
        emptyView: AnyView? = nil
    ) -> some View {
        modifier(LoadingStateViewModifier(
            state: state,
            loadingView: loadingView,
            errorView: errorView,
            emptyView: emptyView
        ))
    }
}

