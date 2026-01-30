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
                    
                    // 右上角跳过按钮
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                // 停止定时器（如果存在）
                                timer?.invalidate()
                                timer = nil
                                
                                // 直接结束视频加载，进入主界面
                                appState.isCheckingLoginStatus = false
                            }) {
                                Text(LocalizationKey.onboardingSkip.localized)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                            }
                            .padding(.top, 12)
                            .padding(.trailing, 16)
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
            } else {
                // 未登录时也直接显示主界面，不再强制显示登录框
                // 用户可以在需要时通过其他入口进行登录
                MainTabView()
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
        case "message":
            // 处理消息推送（私信或任务聊天）
            if let notificationTypeString = userInfo["notification_type"] as? String {
                switch notificationTypeString {
                case "task_message":
                    // 任务聊天消息
                    if let taskId = extractTaskId(from: userInfo) {
                        // 在 UserDefaults 中标记需要刷新该任务的消息
                        UserDefaults.standard.set(true, forKey: "refresh_task_chat_\(taskId)")
                        // 发送通知，标记需要刷新任务聊天消息
                        NotificationCenter.default.post(
                            name: NSNotification.Name("RefreshTaskChat"),
                            object: nil,
                            userInfo: ["task_id": taskId]
                        )
                        navigateToTask(id: taskId)
                    }
                case "private_message":
                    // 私信消息
                    if let partnerId = userInfo["partner_id"] as? String {
                        navigateToChat(partnerId: partnerId)
                    }
                default:
                    break
                }
            }
        case "task_application", "task_completed", "task_confirmed", "application_accepted":
            // 跳转到任务详情
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            }
        case "forum_reply":
            // 跳转到论坛帖子
            if let postIdString = userInfo["post_id"] as? String,
               let postId = Int(postIdString) {
                navigateToPost(id: postId)
            }
        case "application_message_reply":
            // 跳转到任务聊天
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            }
        case "flea_market_purchase_request":
            // 买家发送议价请求 → 通知卖家，跳转到商品详情页
            if let itemId = extractItemId(from: userInfo) {
                navigateToFleaMarketItem(id: itemId)
            }
        case "flea_market_purchase_accepted":
            // 卖家同意议价 → 通知买家，跳转到任务详情（支付页面）
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            } else if let itemId = extractItemId(from: userInfo) {
                navigateToFleaMarketItem(id: itemId)
            }
        case "flea_market_direct_purchase":
            // 直接购买 → 跳转到任务详情（支付页面）
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            }
        case "flea_market_pending_payment":
            // 支付提醒 → 跳转到任务详情或商品详情
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            } else if let itemId = extractItemId(from: userInfo) {
                navigateToFleaMarketItem(id: itemId)
            }
        case "service_application_approved", "payment_reminder":
            // 达人服务申请通过、支付提醒 → 跳转到任务详情（支付页）
            if let taskId = extractTaskId(from: userInfo) {
                navigateToTask(id: taskId)
            }
        case "activity_reward_points", "activity_reward_cash":
            // 达人活动奖励 → 跳转到活动详情
            if let activityId = extractActivityId(from: userInfo) {
                navigateToActivity(id: activityId)
            }
        default:
            break
        }
    }
    
    // 从 userInfo 中提取活动 ID（推送 payload 的 data 中）
    private func extractActivityId(from userInfo: [AnyHashable: Any]) -> Int? {
        if let data = userInfo["data"] as? [String: Any],
           let activityIdValue = data["activity_id"] {
            return parseTaskId(activityIdValue)
        }
        if let activityIdValue = userInfo["activity_id"] {
            return parseTaskId(activityIdValue)
        }
        return nil
    }
    
    // 导航到活动详情页
    private func navigateToActivity(id: Int) {
        if let url = DeepLinkHandler.generateURL(for: .activity(id: id)) {
            DeepLinkHandler.shared.handle(url)
        }
    }
    
    // 从 userInfo 中提取任务 ID（支持多种格式）
    private func extractTaskId(from userInfo: [AnyHashable: Any]) -> Int? {
        // 优先尝试从 data 字典中获取
        if let data = userInfo["data"] as? [String: Any],
           let taskIdValue = data["task_id"] {
            return parseTaskId(taskIdValue)
        }
        
        // 直接从 userInfo 获取
        if let taskIdValue = userInfo["task_id"] {
            return parseTaskId(taskIdValue)
        }
        
        // 尝试从 related_id 获取（某些通知使用这个字段）
        if let relatedIdValue = userInfo["related_id"] {
            return parseTaskId(relatedIdValue)
        }
        
        return nil
    }
    
    // 解析任务 ID（支持 Int 和 String 类型）
    private func parseTaskId(_ value: Any) -> Int? {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String {
            return Int(stringValue)
        }
        return nil
    }
    
    // 导航到任务详情页
    private func navigateToTask(id: Int) {
        if let url = DeepLinkHandler.generateURL(for: .task(id: id)) {
            DeepLinkHandler.shared.handle(url)
        }
    }
    
    // 导航到论坛帖子详情页
    private func navigateToPost(id: Int) {
        if let url = DeepLinkHandler.generateURL(for: .post(id: id)) {
            DeepLinkHandler.shared.handle(url)
        }
    }
    
    // 从 userInfo 中提取商品 ID
    private func extractItemId(from userInfo: [AnyHashable: Any]) -> String? {
        // 优先尝试从 data 字典中获取
        if let data = userInfo["data"] as? [String: Any],
           let itemIdValue = data["item_id"] {
            return parseItemId(itemIdValue)
        }
        
        // 直接从 userInfo 获取
        if let itemIdValue = userInfo["item_id"] {
            return parseItemId(itemIdValue)
        }
        
        return nil
    }
    
    // 解析商品 ID（支持 Int 和 String 类型）
    private func parseItemId(_ value: Any) -> String? {
        if let stringValue = value as? String {
            return stringValue
        }
        if let intValue = value as? Int {
            return String(intValue)
        }
        return nil
    }
    
    // 导航到跳蚤市场商品详情页
    private func navigateToFleaMarketItem(id: String) {
        if let url = DeepLinkHandler.generateURL(for: .fleaMarketItem(id: id)) {
            DeepLinkHandler.shared.handle(url)
        }
    }
    
    // 导航到私信聊天
    private func navigateToChat(partnerId: String) {
        // 发送通知，让消息页面处理跳转
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToChat"),
            object: nil,
            userInfo: ["partner_id": partnerId]
        )
        
        // 切换到消息标签页（索引3）
        // 注意：这里需要通过某种方式通知 MainTabView 切换标签
        // 由于 ContentView 不直接控制 MainTabView，我们使用通知机制
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToMessagesTab"),
            object: nil
        )
    }
    
    // 检查引导教程状态
    private func checkOnboardingStatus() {
        // 优化：同步读取 UserDefaults，确保获取最新值
        UserDefaults.standard.synchronize()
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
        
        // 调试日志
        if !hasSeenOnboarding {
            // 延迟显示引导教程，确保登录状态检查完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 再次检查，防止在延迟期间状态已改变
                let currentStatus = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
                if !currentStatus {
                    showOnboarding = true
                }
            }
        }
    }
    
    // 视频播放完成后请求通知权限和追踪权限
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
                            
                            if granted {
                                UIApplication.shared.registerForRemoteNotifications()
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

