import Foundation
import AppIntents
import UniformTypeIdentifiers

/// 发布任务快捷指令
@available(iOS 16.0, *)
struct PublishTaskIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.publish_task", defaultValue: "Publish Task")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.publish_task_description", defaultValue: "Quickly publish a new task"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // 发送通知，让应用打开发布任务页面
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "publish_task"
            )
        }
        return .result()
    }
}

/// 查看我的任务快捷指令
@available(iOS 16.0, *)
struct ViewMyTasksIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.view_my_tasks", defaultValue: "View My Tasks")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.view_my_tasks_description", defaultValue: "View tasks I published and accepted"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "my_tasks"
            )
        }
        return .result()
    }
}

/// 查看消息快捷指令
@available(iOS 16.0, *)
struct ViewMessagesIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.view_messages", defaultValue: "View Messages")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.view_messages_description", defaultValue: "View unread messages and notifications"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "view_messages"
            )
        }
        return .result()
    }
}

/// 搜索任务快捷指令
@available(iOS 16.0, *)
struct SearchTasksIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.search_tasks", defaultValue: "Search Tasks")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.search_tasks_description", defaultValue: "Search for tasks"))
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: LocalizedStringResource("common.search", defaultValue: "Keyword"), description: LocalizedStringResource("common.search", defaultValue: "Keyword to search"))
    var keyword: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Search Tasks")
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var userInfo: [String: Any] = [:]
            if let keyword = keyword {
                userInfo["keyword"] = keyword
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "search_tasks",
                userInfo: userInfo
            )
        }
        return .result()
    }
}

/// 查看跳蚤市场快捷指令
@available(iOS 16.0, *)
struct ViewFleaMarketIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.view_flea_market", defaultValue: "View Flea Market")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.view_flea_market_description", defaultValue: "Browse and publish second-hand goods"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "flea_market"
            )
        }
        return .result()
    }
}

/// 查看论坛快捷指令
@available(iOS 16.0, *)
struct ViewForumIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.view_forum", defaultValue: "View Forum")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.view_forum_description", defaultValue: "Participate in community discussions"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("QuickAction"),
                object: "forum"
            )
        }
        return .result()
    }
}

/// 打开应用快捷指令
@available(iOS 16.0, *)
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource("shortcuts.open_app", defaultValue: "Open Link²Ur")
    static var description = IntentDescription(LocalizedStringResource("shortcuts.open_app_description", defaultValue: "Open Link²Ur app"))
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // 直接打开应用（不需要额外操作）
        return .result()
    }
}

/// 应用快捷指令配置
@available(iOS 16.0, *)
struct Link2UrShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // 打开应用 - 支持多种说法
        AppShortcut(
            intent: OpenAppIntent(),
            phrases: [
                // 中文短语
                "打开 ${applicationName}",
                "打开 link to you",
                "打开 link2ur",
                "打开 link 2 u r",
                "启动 ${applicationName}",
                "运行 ${applicationName}",
                // English phrases
                "Open ${applicationName}",
                "Open link to you",
                "Open link2ur",
                "Open link 2 u r",
                "Launch ${applicationName}",
                "Start ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.open_app", defaultValue: "Open Link²Ur"),
            systemImageName: "app.badge"
        )
        
        // 发布任务 - 支持中英文短语
        AppShortcut(
            intent: PublishTaskIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 发布任务",
                "在 ${applicationName} 发布任务",
                "在 ${applicationName} 发布任务",
                // English phrases
                "Publish task with ${applicationName}",
                "Publish task in ${applicationName}",
                "Publish task in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.publish_task", defaultValue: "Publish Task"),
            systemImageName: "plus.circle.fill"
        )
        
        // 查看我的任务 - 支持中英文短语
        AppShortcut(
            intent: ViewMyTasksIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 查看我的任务",
                "在 ${applicationName} 查看我的任务",
                "在 ${applicationName} 查看我的任务",
                // English phrases
                "View my tasks with ${applicationName}",
                "View my tasks in ${applicationName}",
                "View my tasks in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.view_my_tasks", defaultValue: "My Tasks"),
            systemImageName: "list.bullet"
        )
        
        // 查看消息 - 支持中英文短语
        AppShortcut(
            intent: ViewMessagesIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 查看消息",
                "在 ${applicationName} 查看消息",
                "在 ${applicationName} 查看消息",
                // English phrases
                "View messages with ${applicationName}",
                "View messages in ${applicationName}",
                "View messages in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.view_messages", defaultValue: "Messages"),
            systemImageName: "message.fill"
        )
        
        // 搜索任务 - 支持中英文短语
        // 注意：String 类型参数不能在短语中使用，所以只提供不包含参数的短语
        // 用户可以通过 Shortcuts 应用手动添加搜索关键词
        AppShortcut(
            intent: SearchTasksIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 搜索任务",
                "在 ${applicationName} 搜索任务",
                "在 ${applicationName} 搜索任务",
                // English phrases
                "Search tasks with ${applicationName}",
                "Search tasks in ${applicationName}",
                "Search tasks in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.search_tasks", defaultValue: "Search Tasks"),
            systemImageName: "magnifyingglass"
        )
        
        // 查看跳蚤市场 - 支持中英文短语
        AppShortcut(
            intent: ViewFleaMarketIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 查看跳蚤市场",
                "在 ${applicationName} 查看跳蚤市场",
                "在 ${applicationName} 查看跳蚤市场",
                // English phrases
                "View flea market with ${applicationName}",
                "View flea market in ${applicationName}",
                "View flea market in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.view_flea_market", defaultValue: "Flea Market"),
            systemImageName: "cart.fill"
        )
        
        // 查看论坛 - 支持中英文短语
        AppShortcut(
            intent: ViewForumIntent(),
            phrases: [
                // 中文短语（每个短语必须包含 ${applicationName}）
                "用 ${applicationName} 查看论坛",
                "在 ${applicationName} 查看论坛",
                "在 ${applicationName} 查看论坛",
                // English phrases
                "View forum with ${applicationName}",
                "View forum in ${applicationName}",
                "View forum in ${applicationName}"
            ],
            shortTitle: LocalizedStringResource("shortcuts.view_forum", defaultValue: "Forum"),
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .blue
}
