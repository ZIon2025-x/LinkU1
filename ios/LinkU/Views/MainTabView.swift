import SwiftUI

public struct MainTabView: View {
    @State private var selection = 0
    
    public var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("首页", systemImage: "house.fill")
                }
                .tag(0)
            
            TasksView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet")
                }
                .tag(1)
            
            TaskExpertListView()
                .tabItem {
                    Label("达人", systemImage: "star.fill")
                }
                .tag(2)
            
            CommunityView()
                .tabItem {
                    Label("社区", systemImage: "person.3.fill")
                }
                .tag(3)
            
            MessageView()
                .tabItem {
                    Label("消息", systemImage: "message.fill")
                }
                .tag(4)
            
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(5)
        }
    }
}

// 社区视图 - 包含论坛和排行榜
struct CommunityView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部切换标签
                Picker("", selection: $selectedTab) {
                    Text("论坛").tag(0)
                    Text("排行榜").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    ForumView()
                        .tag(0)
                    
                    LeaderboardView()
                        .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("社区")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
