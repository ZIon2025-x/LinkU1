import Foundation

/// 通知工具类
/// 用于处理通知相关的通用逻辑
struct NotificationHelper {
    /// 判断通知是否是任务相关的
    static func isTaskRelated(_ notification: SystemNotification) -> Bool {
        guard let type = notification.type else { return false }
        
        let lowercasedType = type.lowercased()
        
        // 检查是否是任务相关的通知类型
        // 后端任务通知类型包括：task_application, task_approved, task_completed, task_confirmation, task_cancelled 等
        if lowercasedType.contains("task") {
            return true
        }
        
        // negotiation_offer, application_message, application_rejected, application_withdrawn, negotiation_rejected 也是任务相关的通知
        if lowercasedType == "negotiation_offer" || 
           lowercasedType == "application_message" ||
           lowercasedType == "application_rejected" ||
           lowercasedType == "application_withdrawn" ||
           lowercasedType == "negotiation_rejected" {
            return true
        }
        
        // application_accepted 也是任务相关的通知（申请被接受）
        if lowercasedType == "application_accepted" {
            return true
        }
        
        // 达人服务/活动相关：服务申请通过、支付提醒 → 跳转任务详情
        if lowercasedType == "service_application_approved" || lowercasedType == "payment_reminder" {
            return true
        }
        
        return false
    }
    
    /// 从通知中提取任务ID
    static func extractTaskId(from notification: SystemNotification) -> Int? {
        // 优先使用 taskId 字段（后端已添加）
        if let taskId = notification.taskId {
            return taskId
        }
        
        guard let type = notification.type else { return nil }
        
        let lowercasedType = type.lowercased()
        
        // 对于 negotiation_offer, application_message, application_rejected, application_withdrawn, negotiation_rejected 类型
        // related_id 是 application_id，不是 task_id，这些通知必须使用 taskId 字段（后端已添加）
        if lowercasedType == "negotiation_offer" || 
           lowercasedType == "application_message" ||
           lowercasedType == "application_rejected" ||
           lowercasedType == "application_withdrawn" ||
           lowercasedType == "negotiation_rejected" {
            return nil  // 如果没有 taskId，不跳转
        }
        
        // 对于 task_application 类型，优先使用 taskId，如果没有则使用 relatedId（应该是 task_id）
        if lowercasedType == "task_application" {
            return notification.relatedId
        }
        
        // application_accepted 类型：related_id 就是 task_id
        if lowercasedType == "application_accepted" {
            return notification.relatedId
        }
        
        // task_approved, task_completed, task_confirmed, task_cancelled, task_reward_paid 等类型
        // related_id 就是 task_id（后端已统一）
        if lowercasedType == "task_approved" || 
           lowercasedType == "task_completed" || 
           lowercasedType == "task_confirmed" || 
           lowercasedType == "task_cancelled" ||
           lowercasedType == "task_reward_paid" {
            return notification.relatedId
        }
        
        // 达人服务/活动：service_application_approved、payment_reminder 的 related_id 就是 task_id
        if lowercasedType == "service_application_approved" || lowercasedType == "payment_reminder" {
            return notification.taskId ?? notification.relatedId
        }
        
        // 其他包含 "task" 的通知类型，尝试使用 relatedId
        if lowercasedType.contains("task") {
            return notification.relatedId
        }
        
        return nil
    }
    
    // MARK: - 达人活动通知相关
    
    /// 判断通知是否是达人活动相关的（活动奖励等）
    static func isActivityRelated(_ notification: SystemNotification) -> Bool {
        guard let type = notification.type else { return false }
        let lowercasedType = type.lowercased()
        return lowercasedType == "activity_reward_points" || lowercasedType == "activity_reward_cash"
    }
    
    /// 从达人活动通知中提取活动ID（用于跳转活动详情）
    static func extractActivityId(from notification: SystemNotification) -> Int? {
        guard isActivityRelated(notification) else { return nil }
        return notification.relatedId
    }
    
    // MARK: - 跳蚤市场通知相关
    
    /// 判断通知是否是跳蚤市场相关的
    static func isFleaMarketRelated(_ notification: SystemNotification) -> Bool {
        guard let type = notification.type else { return false }
        
        let lowercasedType = type.lowercased()
        
        // 检查是否是跳蚤市场相关的通知类型
        let fleaMarketTypes = [
            "flea_market_purchase_request",      // 买家发送议价请求
            "flea_market_purchase_accepted",     // 卖家同意议价
            "flea_market_direct_purchase",       // 直接购买
            "flea_market_pending_payment",       // 支付提醒
            "flea_market_seller_counter_offer",  // 卖家议价
            "flea_market_purchase_rejected"      // 购买申请被拒绝
        ]
        
        return fleaMarketTypes.contains(lowercasedType)
    }
    
    /// 从跳蚤市场通知中提取商品ID
    /// 返回格式为 "S0020" 的字符串ID，可直接用于 FleaMarketDetailView
    /// 注意：部分跳蚤市场通知的 related_id 存储的是 task_id 而不是 item_id：
    /// - flea_market_purchase_accepted: related_id = task_id
    /// - flea_market_direct_purchase: related_id = task_id
    /// - flea_market_pending_payment: 可能存储 task_id
    /// 这些通知应该优先使用 extractFleaMarketTaskId 方法
    static func extractFleaMarketItemId(from notification: SystemNotification) -> String? {
        guard let type = notification.type else { return nil }
        
        // 只处理跳蚤市场相关通知
        guard isFleaMarketRelated(notification) else { return nil }
        
        // 这些通知类型的 related_id 存储的是 task_id，不是 item_id
        // 应该使用 extractFleaMarketTaskId 来跳转到任务详情页
        let typesWithTaskIdAsRelatedId = [
            "flea_market_purchase_accepted",
            "flea_market_direct_purchase",
            "flea_market_pending_payment"
        ]
        
        // 对于这些类型，related_id 不是 item_id，不能用于跳转商品详情
        if typesWithTaskIdAsRelatedId.contains(type.lowercased()) {
            // 尝试从 variables 中获取 item_id（推送通知的data字段可能包含）
            if let variables = notification.variables,
               let itemIdValue = variables["item_id"] {
                if let itemIdString = itemIdValue.value as? String {
                    return itemIdString
                }
                if let itemIdInt = itemIdValue.value as? Int {
                    return "S\(String(format: "%04d", itemIdInt))"
                }
            }
            // 没有找到 item_id，返回 nil
            return nil
        }
        
        // 对于其他跳蚤市场通知（purchase_request, seller_counter_offer, purchase_rejected），
        // related_id 存储的是 item_id
        if let relatedId = notification.relatedId {
            // 如果是纯数字，转换为 S 格式
            let itemIdStr = String(relatedId)
            if !itemIdStr.hasPrefix("S") {
                return "S\(String(format: "%04d", relatedId))"
            }
            return itemIdStr
        }
        
        // 尝试从 variables 中获取 item_id（某些通知可能在这里存储）
        if let variables = notification.variables,
           let itemIdValue = variables["item_id"] {
            if let itemIdString = itemIdValue.value as? String {
                return itemIdString
            }
            if let itemIdInt = itemIdValue.value as? Int {
                return "S\(String(format: "%04d", itemIdInt))"
            }
        }
        
        return nil
    }
    
    /// 从跳蚤市场通知中提取任务ID（用于需要跳转到支付页面的情况）
    /// 部分跳蚤市场通知（如 purchase_accepted, direct_purchase, pending_payment）的 related_id 存储的是 task_id
    static func extractFleaMarketTaskId(from notification: SystemNotification) -> Int? {
        guard let type = notification.type else { return nil }
        
        let lowercasedType = type.lowercased()
        
        // 只有这些类型的 related_id 存储的是 task_id
        let typesWithTaskIdAsRelatedId = [
            "flea_market_purchase_accepted",
            "flea_market_direct_purchase",
            "flea_market_pending_payment"
        ]
        
        guard typesWithTaskIdAsRelatedId.contains(lowercasedType) else { return nil }
        
        // 优先使用 taskId 字段（如果后端有设置）
        if let taskId = notification.taskId {
            return taskId
        }
        
        // 对于这些类型，related_id 存储的就是 task_id
        if let relatedId = notification.relatedId {
            return relatedId
        }
        
        // 尝试从 variables 中获取 task_id
        if let variables = notification.variables,
           let taskIdValue = variables["task_id"] {
            if let taskIdInt = taskIdValue.value as? Int {
                return taskIdInt
            }
            if let taskIdString = taskIdValue.value as? String,
               let taskId = Int(taskIdString) {
                return taskId
            }
        }
        
        return nil
    }
}
