import SwiftUI
import UIKit

public struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection = 0
    @State private var previousSelection = 0 // 跟踪之前的选择
    @State private var showCreateTask = false
    @State private var showLogin = false
    @State private var homeViewResetTrigger = UUID() // 用于重置 HomeView
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: Binding(
                get: { selection },
                set: { newValue in
                    // 如果点击的是首页 tab
                    if newValue == 0 {
                        // 无论是否已经在首页，都触发重置
                        // 这样可以确保从任务大厅等子页面返回到首页
                        if selection == 0 {
                            // 如果已经在首页，重置 homeViewResetTrigger 以强制重新创建 HomeView
                            // 这会将 NavigationView 的导航栈重置，从任务大厅返回到首页
                            homeViewResetTrigger = UUID()
                        }
                        // 触发首页重置
                        appState.shouldResetHomeView = true
                        NotificationCenter.default.post(name: .resetHomeView, object: nil)
                        // 更新 previousSelection 为 0，确保中间占位视图显示首页
                        previousSelection = 0
                    }
                    // 更新 selection
                    selection = newValue
                }
            )) {
                HomeView()
                    .id(homeViewResetTrigger) // 使用 id 来强制重置
                    .tabItem {
                        Label("首页", systemImage: "house.fill")
                    }
                    .tag(0)
                
                CommunityView()
                    .id("community-tab") // 添加稳定的 ID，确保视图不会被重新创建
                    .tabItem {
                        Label("社区", systemImage: "person.3.fill")
                    }
                    .tag(1)
                
                // 中间占位视图（显示➕按钮）- 显示当前页面避免空白
                // 使用 previousSelection，但确保社区页面也显示一个有效视图
                Group {
                    switch previousSelection {
                    case 0:
                        HomeView()
                            .id(homeViewResetTrigger)
                    case 1:
                        // 社区页面 - 显示一个占位视图，确保 tab 可见
                        Color.clear
                            .frame(width: 1, height: 1)
                    case 3:
                        MessageView()
                    case 4:
                        ProfileView()
                    default:
                        HomeView()
                            .id(homeViewResetTrigger)
                    }
                }
                .tabItem {
                    Label("发布", systemImage: "plus.circle.fill")
                }
                .tag(2)
                
                MessageView()
                    .tabItem {
                        Label("消息", systemImage: "message.fill")
                    }
                    .tag(3)
                    .badge(appState.unreadNotificationCount + appState.unreadMessageCount > 0 ? 
                           (appState.unreadNotificationCount + appState.unreadMessageCount > 99 ? "99+" : 
                            "\(appState.unreadNotificationCount + appState.unreadMessageCount)") : nil)
                
                ProfileView()
                    .tabItem {
                        Label("我的", systemImage: "person.fill")
                    }
                    .tag(4)
            }
            .tint(AppColors.primary) // 统一TabBar选中颜色
            .onChange(of: selection) { newValue in
                if newValue == 2 {
                    // 点击中间➕按钮时，不改变 selection，直接触发创建任务
                    if appState.isAuthenticated {
                        showCreateTask = true
                    } else {
                        showLogin = true
                    }
                    // 立即恢复之前的选择，避免显示空白页面
                    selection = previousSelection
                } else if newValue == 3 {
                    // 点击消息按钮时，检查登录状态
                    if appState.isAuthenticated {
                        // 正常切换 tab
                        let oldSelection = previousSelection
                        previousSelection = newValue
                        handleSelectionChange(newValue, oldSelection: oldSelection)
                    } else {
                        // 未登录，显示登录页面
                        showLogin = true
                        // 不改变 selection，保持在当前页面
                        selection = previousSelection
                    }
                } else if newValue == 0 {
                    // 切换到首页时，更新 previousSelection
                    let oldSelection = previousSelection
                    previousSelection = newValue
                    handleSelectionChange(newValue, oldSelection: oldSelection)
                } else {
                    // 正常切换 tab（社区、我的等）
                    // 先更新 previousSelection，避免在 handleSelectionChange 中判断错误
                    let oldSelection = previousSelection
                    previousSelection = newValue
                    handleSelectionChange(newValue, oldSelection: oldSelection)
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .onChange(of: appState.isAuthenticated) { isAuthenticated in
            // 登录成功后，如果之前点击的是消息，自动切换到消息页面
            if isAuthenticated && previousSelection == 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    selection = 3
                    previousSelection = 3
                }
            }
        }
    }
    
    
    // 处理选择变化
    private func handleSelectionChange(_ newValue: Int, oldSelection: Int) {
        // 注意：首页重置逻辑已经在 binding 的 set 中处理了
        // 这里只处理其他情况，避免重复逻辑
        // 如果需要在其他场景下重置首页，可以在这里添加
    }
    
}

// 社区视图 - 包含论坛和排行榜
struct CommunityView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 自定义顶部导航栏（类似首页样式）
                    HStack(spacing: 0) {
                        // 左侧占位（保持对称）
                        Spacer()
                            .frame(width: 44)
                        
                        Spacer()
                        
                        // 中间两个标签
                        HStack(spacing: 0) {
                            // 论坛
                            TabButton(
                                title: "论坛",
                                isSelected: selectedTab == 0
                            ) {
                                selectedTab = 0
                            }
                            
                            // 排行榜
                            TabButton(
                                title: "排行榜",
                                isSelected: selectedTab == 1
                            ) {
                                selectedTab = 1
                            }
                        }
                        
                        Spacer()
                        
                        // 右侧占位（保持对称）
                        Spacer()
                            .frame(width: 44)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(AppColors.background)
                    
                    // 内容区域 - 使用 TabView 实现左右滑动切换，和首页一样
                    TabView(selection: $selectedTab) {
                        ForumView()
                            .tag(0)
                        
                        LeaderboardView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
        }
    }
}
