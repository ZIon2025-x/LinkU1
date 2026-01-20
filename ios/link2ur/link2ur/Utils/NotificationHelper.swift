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
        
        // 其他包含 "task" 的通知类型，尝试使用 relatedId
        if lowercasedType.contains("task") {
            return notification.relatedId
        }
        
        return nil
    }
}
