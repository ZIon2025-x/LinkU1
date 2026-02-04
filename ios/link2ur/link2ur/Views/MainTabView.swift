import SwiftUI
import UIKit

public struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection = 0
    @State private var previousSelection = 0 // 跟踪之前的选择
    @State private var showCreateTask = false
    @State private var showLogin = false
    @State private var homeViewResetTrigger = UUID() // 用于重置 HomeView
    @State private var searchKeyword: String? = nil // 用于搜索快捷指令
    @State private var showEmailUpdateAlert = false // 邮箱更新提醒
    
    public var body: some View {
        TabView(selection: Binding(
                get: { selection },
                set: { newValue in
                    // 如果点击的是首页 tab
                    if newValue == 0 {
                        if selection != 0 {
                            appState.shouldResetHomeView = true
                            NotificationCenter.default.post(name: .resetHomeView, object: nil)
                        }
                        previousSelection = 0
                    }
                    
                    // 添加触觉反馈
                    if selection != newValue {
                        HapticFeedback.selection()
                    }
                    
                    // 更新 selection
                    selection = newValue
                }
            )) {
                HomeView()
                    // 移除 id，避免重新创建 HomeView，保持 NavigationStack 状态
                    .tabItem {
                        Label(LocalizationKey.tabsHome.localized, systemImage: "house.fill")
                    }
                    .tag(0)
                
                CommunityView()
                    .id("community-tab") // 添加稳定的 ID，确保视图不会被重新创建
                    .tabItem {
                        Label(LocalizationKey.tabsCommunity.localized, systemImage: "person.3.fill")
                    }
                    .tag(1)
                
                // 中间占位视图（显示➕按钮）- 显示当前页面避免空白
                // 使用 previousSelection，但确保社区页面也显示一个有效视图
                Group {
                    switch previousSelection {
                    case 0:
                        HomeView()
                            // 移除 id，避免重新创建，保持导航栈状态
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
                            // 移除 id，避免重新创建，保持导航栈状态
                    }
                }
                .tabItem {
                    Label(LocalizationKey.tabsCreate.localized, systemImage: "plus.circle.fill")
                }
                .tag(2)
                
                MessageView()
                    .tabItem {
                        Label(LocalizationKey.tabsMessages.localized, systemImage: "message.fill")
                    }
                    .tag(3)
                    .badge(appState.unreadNotificationCount + appState.unreadMessageCount > 0 ? 
                           (appState.unreadNotificationCount + appState.unreadMessageCount > 99 ? "99+" : 
                            "\(appState.unreadNotificationCount + appState.unreadMessageCount)") : nil)
                
                ProfileView()
                    .tabItem {
                        Label(LocalizationKey.tabsProfile.localized, systemImage: "person.fill")
                    }
                    .tag(4)
            }
            .tint(AppColors.primary) // 统一TabBar选中颜色
            .toolbarBackground(Color(UIColor.systemBackground), for: .tabBar) // 加固 TabBar 背景，避免从详情返回等操作后整行背景消失
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
                    let oldSelection = previousSelection
                    previousSelection = newValue
                    handleSelectionChange(newValue, oldSelection: oldSelection)
                    if oldSelection != 0 {
                        appState.shouldResetHomeView = true
                        NotificationCenter.default.post(name: .resetHomeView, object: nil)
                    }
                } else {
                    // 正常切换 tab（社区、我的等）
                    // 先更新 previousSelection，避免在 handleSelectionChange 中判断错误
                    let oldSelection = previousSelection
                    previousSelection = newValue
                    handleSelectionChange(newValue, oldSelection: oldSelection)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("QuickAction"))) { notification in
                // 处理快捷指令
                handleQuickAction(notification.object as? String, userInfo: notification.userInfo)
            }
            .onAppear {
                // 检查用户邮箱是否为系统默认的占位邮箱
                checkEmailAndShowWarning()
            }
            .onChange(of: appState.currentUser?.email) { _ in
                // 用户信息更新时也检查
                checkEmailAndShowWarning()
            }
            .alert(
                LocalizationKey.profilePleaseUpdateEmailTitle.localized,
                isPresented: $showEmailUpdateAlert
            ) {
                Button(LocalizationKey.commonOk.localized, role: .cancel) { }
            } message: {
                Text(LocalizationKey.profilePleaseUpdateEmailMessage.localized)
            }
    }
    
    // 检查邮箱并显示警告
    private func checkEmailAndShowWarning() {
        guard let email = appState.currentUser?.email,
              email.hasSuffix("@link2ur.com"),
              let userId = appState.currentUser?.id else {
            return
        }
        
        // 每24小时最多提醒一次
        let warningKey = "email_warning_shown_\(userId)"
        let lastWarningTime = UserDefaults.standard.double(forKey: warningKey)
        let now = Date().timeIntervalSince1970
        let oneDayInSeconds: Double = 24 * 60 * 60
        
        if lastWarningTime == 0 || (now - lastWarningTime) > oneDayInSeconds {
            // 延迟显示，避免与其他弹窗冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showEmailUpdateAlert = true
                UserDefaults.standard.set(now, forKey: warningKey)
            }
        }
    }
    
    // 处理快捷指令
    private func handleQuickAction(_ actionId: String?, userInfo: [AnyHashable: Any]?) {
        guard let actionId = actionId else { return }
        
        switch actionId {
        case "publish_task":
            if appState.isAuthenticated {
                showCreateTask = true
            } else {
                showLogin = true
            }
            
        case "my_tasks":
            if appState.isAuthenticated {
                // 切换到个人资料页面（我的任务在个人资料中）
                selection = 4
                previousSelection = 4
            } else {
                showLogin = true
            }
            
        case "view_messages":
            if appState.isAuthenticated {
                selection = 3
                previousSelection = 3
            } else {
                showLogin = true
            }
            
        case "search_tasks":
            if let keyword = userInfo?["keyword"] as? String {
                searchKeyword = keyword
                // 切换到首页并触发搜索
                selection = 0
                previousSelection = 0
                // 发送搜索通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("SearchTasks"),
                    object: keyword
                )
            }
            
        case "flea_market":
            // 跳蚤市场在首页中，切换到首页
            selection = 0
            previousSelection = 0
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToFleaMarket"),
                object: nil
            )
            
        case "forum":
            // 论坛在社区页面中，切换到社区
            selection = 1
            previousSelection = 1
            
        default:
            break
        }
        
        HapticFeedback.selection()
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
                                title: LocalizationKey.communityForum.localized,
                                isSelected: selectedTab == 0
                            ) {
                                selectedTab = 0
                            }
                            
                            // 排行榜
                            TabButton(
                                title: LocalizationKey.communityLeaderboard.localized,
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
