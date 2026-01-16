import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Spotlight 搜索索引管理器
/// 用于将应用内容索引到系统搜索中，用户可以通过 Spotlight 直接搜索应用内容
public class SpotlightIndexer {
    public static let shared = SpotlightIndexer()
    
    private init() {}
    
    // MARK: - 任务索引
    
    /// 索引任务
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - title: 任务标题
    ///   - description: 任务描述
    ///   - taskType: 任务类型
    ///   - location: 任务地点
    ///   - reward: 任务奖励
    public func indexTask(
        taskId: Int,
        title: String,
        description: String?,
        taskType: String?,
        location: String?,
        reward: Double?
    ) {
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "task_\(taskId)",
            domainIdentifier: "tasks",
            attributeSet: createTaskAttributeSet(
                taskId: taskId,
                title: title,
                description: description,
                taskType: taskType,
                location: location,
                reward: reward
            )
        )
        
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                print("❌ Spotlight 索引任务失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已索引任务: \(title)")
            }
        }
    }
    
    /// 批量索引任务
    public func indexTasks(_ tasks: [(id: Int, title: String, description: String?, taskType: String?, location: String?, reward: Double?)]) {
        let searchableItems = tasks.map { task in
            CSSearchableItem(
                uniqueIdentifier: "task_\(task.id)",
                domainIdentifier: "tasks",
                attributeSet: createTaskAttributeSet(
                    taskId: task.id,
                    title: task.title,
                    description: task.description,
                    taskType: task.taskType,
                    location: task.location,
                    reward: task.reward
                )
            )
        }
        
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("❌ Spotlight 批量索引任务失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已索引 \(tasks.count) 个任务")
            }
        }
    }
    
    /// 删除任务索引
    public func deleteTaskIndex(taskId: Int) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["task_\(taskId)"]) { error in
            if let error = error {
                print("❌ Spotlight 删除任务索引失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已删除任务索引: \(taskId)")
            }
        }
    }
    
    // MARK: - 用户索引
    
    /// 索引任务达人
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - name: 用户名
    ///   - bio: 用户简介
    ///   - serviceName: 服务名称
    public func indexExpert(
        userId: Int,
        name: String,
        bio: String?,
        serviceName: String?
    ) {
        let searchableItem = CSSearchableItem(
            uniqueIdentifier: "expert_\(userId)",
            domainIdentifier: "experts",
            attributeSet: createExpertAttributeSet(
                userId: userId,
                name: name,
                bio: bio,
                serviceName: serviceName
            )
        )
        
        CSSearchableIndex.default().indexSearchableItems([searchableItem]) { error in
            if let error = error {
                print("❌ Spotlight 索引任务达人失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已索引任务达人: \(name)")
            }
        }
    }
    
    /// 删除用户索引
    public func deleteExpertIndex(userId: Int) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["expert_\(userId)"]) { error in
            if let error = error {
                print("❌ Spotlight 删除任务达人索引失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已删除任务达人索引: \(userId)")
            }
        }
    }
    
    // MARK: - 快速操作索引
    
    /// 索引快速操作
    public func indexQuickActions() {
        let quickActions = [
            ("publish_task", LocalizationHelper.localized("shortcuts.publish_task"), LocalizationHelper.localized("shortcuts.publish_task_description"), "plus.circle.fill"),
            ("view_messages", LocalizationHelper.localized("shortcuts.view_messages"), LocalizationHelper.localized("shortcuts.view_messages_description"), "message.fill"),
            ("my_tasks", LocalizationHelper.localized("shortcuts.view_my_tasks"), LocalizationHelper.localized("shortcuts.view_my_tasks_description"), "list.bullet"),
            ("flea_market", LocalizationHelper.localized("shortcuts.view_flea_market"), LocalizationHelper.localized("shortcuts.view_flea_market_description"), "cart.fill"),
            ("forum", LocalizationHelper.localized("shortcuts.view_forum"), LocalizationHelper.localized("shortcuts.view_forum_description"), "bubble.left.and.bubble.right.fill")
        ]
        
        let searchableItems = quickActions.map { action in
            CSSearchableItem(
                uniqueIdentifier: "quick_action_\(action.0)",
                domainIdentifier: "quick_actions",
                attributeSet: createQuickActionAttributeSet(
                    identifier: action.0,
                    title: action.1,
                    description: action.2,
                    iconName: action.3
                )
            )
        }
        
        CSSearchableIndex.default().indexSearchableItems(searchableItems) { error in
            if let error = error {
                print("❌ Spotlight 索引快速操作失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已索引快速操作")
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func createTaskAttributeSet(
        taskId: Int,
        title: String,
        description: String?,
        taskType: String?,
        location: String?,
        reward: Double?
    ) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        
        attributeSet.title = title
        attributeSet.contentDescription = description ?? title
        
        // 关键词（用于搜索）- 使用本地化
        var keywords: [String] = [title]
        if let taskType = taskType {
            keywords.append(taskType)
        }
        if let location = location {
            keywords.append(location)
        }
        // 添加本地化的关键词
        keywords.append(LocalizationHelper.localized("spotlight.task"))
        keywords.append("Link²Ur")
        attributeSet.keywords = keywords
        
        // 其他属性
        if let taskType = taskType {
            attributeSet.subject = taskType
        }
        if let location = location {
            attributeSet.contentCreationDate = Date()
            attributeSet.city = location
        }
        if let reward = reward {
            attributeSet.rating = NSNumber(value: reward)
        }
        
        // 注意：uniqueIdentifier 应该在 CSSearchableItem 中设置，而不是在 attributeSet 中
        // attributeSet 不包含 uniqueIdentifier 属性
        
        return attributeSet
    }
    
    private func createExpertAttributeSet(
        userId: Int,
        name: String,
        bio: String?,
        serviceName: String?
    ) -> CSSearchableItemAttributeSet {
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.contact.identifier)
        
        attributeSet.displayName = name
        attributeSet.contentDescription = bio ?? serviceName ?? LocalizationHelper.localized("spotlight.expert")
        
        // 关键词 - 使用本地化
        var keywords: [String] = [name]
        if let serviceName = serviceName {
            keywords.append(serviceName)
        }
        keywords.append(LocalizationHelper.localized("spotlight.expert"))
        keywords.append("Link²Ur")
        attributeSet.keywords = keywords
        
        // 其他属性
        if let serviceName = serviceName {
            attributeSet.subject = serviceName
        }
        
        // 注意：uniqueIdentifier 应该在 CSSearchableItem 中设置，而不是在 attributeSet 中
        // attributeSet 不包含 uniqueIdentifier 属性
        
        return attributeSet
    }
    
    private func createQuickActionAttributeSet(
        identifier: String,
        title: String,
        description: String,
        iconName: String
    ) -> CSSearchableItemAttributeSet {
        // 使用通用类型，因为 UTType.action 可能不存在
        let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.data.identifier)
        
        attributeSet.title = title
        attributeSet.contentDescription = description
        
        // 关键词 - 使用本地化
        attributeSet.keywords = [
            title,
            description,
            "Link²Ur",
            LocalizationHelper.localized("spotlight.quick_action")
        ]
        
        // 注意：uniqueIdentifier 应该在 CSSearchableItem 中设置，而不是在 attributeSet 中
        // attributeSet 不包含 uniqueIdentifier 属性
        
        return attributeSet
    }
    
    // MARK: - 清理
    
    /// 清除所有索引
    public func deleteAllIndexes() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("❌ Spotlight 清除所有索引失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已清除所有索引")
            }
        }
    }
    
    /// 清除指定域的所有索引
    public func deleteIndexes(forDomain domain: String) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { error in
            if let error = error {
                print("❌ Spotlight 清除域索引失败: \(error.localizedDescription)")
            } else {
                print("✅ Spotlight 已清除域索引: \(domain)")
            }
        }
    }
}
