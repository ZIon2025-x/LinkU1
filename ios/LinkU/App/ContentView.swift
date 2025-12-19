import SwiftUI

public struct ContentView: View {
    @EnvironmentObject public var appState: AppState
    
    public var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // 检查是否已有 Token
            appState.checkLoginStatus()
        }
    }
    
    public init() {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}

