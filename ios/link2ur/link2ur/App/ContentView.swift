import SwiftUI

public struct ContentView: View {
    @EnvironmentObject public var appState: AppState
    
    public var body: some View {
        MainTabView()
            .onAppear {
                // 静默检查登录状态，但不强制登录
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

