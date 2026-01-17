import SwiftUI
import UserNotifications

public struct ContentView: View {
    @EnvironmentObject public var appState: AppState
    @State private var remainingTime: Double = 3.0 // 剩余时间（秒）
    @State private var progress: Double = 1.0 // 进度值（1.0 到 0.0）
    @State private var timer: Timer?
    @State private var hasStartedAnimation: Bool = false // 标记是否已启动动画
    @State private var showOnboarding = false // 是否显示引导教程
    @State private var hasCheckedOnboarding = false // 优化：防止重复检查引导教程状态
    
    public var body: some View {
        Group {
            if appState.isCheckingLoginStatus {
                // 正在检查登录状态，显示视频加载界面
                ZStack {
                    // 视频背景（全屏循环播放，从多个视频中随机选择）
                    VideoLoadingView(
                        videoName: "linker",  // 默认视频名（如果 videoNames 为空时使用）
                        videoExtension: "mp4",
                        videoNames: ["linker1", "linker2", "linker3", "linker4"],  // 4个视频文件名（不含扩展名）
                        showOverlay: false
                    )
                    
                    // 可选的半透明遮罩（如果需要降低视频亮度）
                    Color.black.opacity(0.05)
                        .ignoresSafeArea()
                    
                    // 右上角倒计时圆圈（可选，如果需要显示加载进度）
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                // 背景圆圈
                                Circle()
                                    .stroke(AppColors.separator.opacity(0.3), lineWidth: 3)
                                    .frame(width: 40, height: 40)
                                
                                // 进度圆圈（带动画）
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: AppColors.gradientPrimary),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                    )
                                    .frame(width: 40, height: 40)
                                    .rotationEffect(.degrees(-90))
                                
                                // 时间文字
                                Text("\(max(0, Int(ceil(remainingTime))))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 16)
                            .onAppear {
                                // 当加载界面出现时，立即启动动画
                                if appState.isCheckingLoginStatus && !hasStartedAnimation {
                                    remainingTime = 3.0
                                    progress = 0.0  // 从空开始
                                    hasStartedAnimation = true
                                    
                                    // 立即启动动画，从空到满
                                    withAnimation(.linear(duration: 3.0)) {
                                        progress = 1.0
                                    }
                                    
                                    // 使用定时器更新显示的数字
                                    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                                        if remainingTime > 0 {
                                            remainingTime = max(0, remainingTime - 0.1)
                                        } else {
                                            timer?.invalidate()
                                            timer = nil
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    // 中间文本：Link to your world（蓝色字体，world 是蓝底白字）
                    VStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("Link to your ")
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primary)
                            
                            Text("world")
                                .font(AppTypography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(AppColors.primary)
                                .cornerRadius(8)
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .padding(.top, 100)  // 往下移动（增加顶部间距）
                        Spacer()
                    }
                    
                    // 左下角 Logo
                    VStack {
                        Spacer()
                        HStack {
                            Image("Logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)  // 确保左对齐
                        .padding(.leading, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.lg)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)  // 确保在左下角
                }
            } else if appState.isAuthenticated || appState.userSkippedLogin {
                // 已登录或用户选择跳过登录，都显示主界面
                MainTabView()
                    .sheet(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                    }
            } else {
                LoginView()
                    .sheet(isPresented: $showOnboarding) {
                        OnboardingView(isPresented: $showOnboarding)
                    }
            }
        }
        .onAppear {
            // 优化：只在首次出现时检查引导教程状态，避免重复检查
            if !hasCheckedOnboarding {
                checkOnboardingStatus()
                hasCheckedOnboarding = true
            }
        }
        // 移除 onAppear 中的 checkLoginStatus 调用
        // AppState 的 init() 中已经调用了 checkLoginStatus()，避免重复调用
        .onChange(of: appState.isCheckingLoginStatus) { isChecking in
            if !isChecking {
                // 停止倒计时
                timer?.invalidate()
                timer = nil
                remainingTime = 3.0 // 重置
                progress = 0.0 // 重置为空
                hasStartedAnimation = false // 重置标记
                
                // 视频播放完成，进入app后，请求通知权限
                requestNotificationPermissionAfterVideo()
            }
        }
        .onDisappear {
            // 清理定时器
            timer?.invalidate()
            timer = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PushNotificationTapped"))) { notification in
            // 处理推送通知点击
            handlePushNotificationTap(userInfo: notification.userInfo)
        }
    }
    
    // 处理推送通知点击
    private func handlePushNotificationTap(userInfo: [AnyHashable: Any]?) {
        guard let userInfo = userInfo,
              let notificationType = userInfo["type"] as? String else {
            return
        }
        
        // 根据通知类型进行跳转
        switch notificationType {
        case "task_application", "task_completed", "task_confirmed":
            // 跳转到任务详情
            if let taskIdString = userInfo["task_id"] as? String,
               let taskId = Int(taskIdString) {
                // TODO: 实现跳转到任务详情页
                print("跳转到任务详情: \(taskId)")
            }
        case "forum_reply":
            // 跳转到论坛帖子
            if let postIdString = userInfo["post_id"] as? String,
               let postId = Int(postIdString) {
                // TODO: 实现跳转到论坛帖子详情页
                print("跳转到论坛帖子: \(postId)")
            }
        case "application_message_reply":
            // 跳转到任务聊天
            if let taskIdString = userInfo["task_id"] as? String,
               let taskId = Int(taskIdString) {
                // TODO: 实现跳转到任务聊天页
                print("跳转到任务聊天: \(taskId)")
            }
        default:
            // 其他通知类型，跳转到通知列表
            print("跳转到通知列表")
        }
    }
    
    // 检查引导教程状态
    private func checkOnboardingStatus() {
        // 优化：同步读取 UserDefaults，确保获取最新值
        UserDefaults.standard.synchronize()
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
        
        // 调试日志
        print("📱 [ContentView] 检查引导教程状态: hasSeenOnboarding = \(hasSeenOnboarding)")
        
        if !hasSeenOnboarding {
            // 延迟显示引导教程，确保登录状态检查完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 再次检查，防止在延迟期间状态已改变
                let currentStatus = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
                if !currentStatus {
                    print("📱 [ContentView] 显示引导教程")
                    showOnboarding = true
                } else {
                    print("📱 [ContentView] 引导教程已在延迟期间被标记为已看过，跳过显示")
                }
            }
        } else {
            print("📱 [ContentView] 用户已看过引导教程，跳过显示")
        }
    }
    
    // 视频播放完成后请求通知权限
    private func requestNotificationPermissionAfterVideo() {
        // 检查是否已经请求过通知权限
        let hasRequestedNotification = UserDefaults.standard.bool(forKey: "has_requested_notification_permission")
        
        if hasRequestedNotification {
            // 已经请求过，检查当前权限状态
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus == .authorized {
                        // 已授权，注册远程推送
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
            return
        }
        
        // 检查当前权限状态，如果已经授权则不需要请求
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // 已经授权，直接注册远程推送
                    UIApplication.shared.registerForRemoteNotifications()
                    return
                }
                
                // 延迟一小段时间，确保用户已经看到主界面，然后直接请求系统权限
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    // 直接请求系统通知权限（会显示系统提示框）
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        DispatchQueue.main.async {
                            // 标记已经请求过
                            UserDefaults.standard.set(true, forKey: "has_requested_notification_permission")
                            
                            if let error = error {
                                print("推送通知权限请求失败: \(error)")
                            } else if granted {
                                print("推送通知权限已授予")
                                // 权限授予后，注册远程推送
                                UIApplication.shared.registerForRemoteNotifications()
                            } else {
                                print("推送通知权限被拒绝")
                            }
                        }
                    }
                }
            }
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

