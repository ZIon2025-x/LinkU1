import SwiftUI

// 登录检查工具
struct LoginChecker {
    static func requireLogin<T: View>(
        isAuthenticated: Bool,
        @ViewBuilder content: () -> T,
        onRequireLogin: @escaping () -> Void
    ) -> some View {
        Group {
            if isAuthenticated {
                content()
            } else {
                EmptyView()
                    .onAppear {
                        onRequireLogin()
                    }
            }
        }
    }
}

// 登录检查ViewModifier
struct RequireLoginModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    @State private var showLogin = false
    let onRequireLogin: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if !appState.isAuthenticated {
                    showLogin = true
                    onRequireLogin()
                }
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
    }
}

extension View {
    func requireLogin(onRequireLogin: @escaping () -> Void = {}) -> some View {
        modifier(RequireLoginModifier(onRequireLogin: onRequireLogin))
    }
}

