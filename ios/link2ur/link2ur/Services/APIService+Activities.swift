import Foundation
import Combine

// MARK: - APIService Activities & Multi-Participant Tasks Extension
// Note: Models are defined in Models/Activity.swift

// MARK: - APIService Activities & Multi-Participant Tasks Extension

extension APIService {
    
    // MARK: - Activities (活动)
    
    /// 获取活动列表（hasTimeSlots: false=单人/非时间段，true=多人/时间段，nil=不筛选）
    func getActivities(expertId: String? = nil, status: String? = nil, hasTimeSlots: Bool? = nil, limit: Int = 20, offset: Int = 0) -> AnyPublisher<[Activity], APIError> {
        var queryParams: [String: String?] = [
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]
        if let expertId = expertId {
            queryParams["expert_id"] = expertId
        }
        if let status = status {
            queryParams["status"] = status
        }
        if let hasTimeSlots = hasTimeSlots {
            queryParams["has_time_slots"] = hasTimeSlots ? "true" : "false"
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Activities.list)?\(queryString)"
        
        return request([Activity].self, endpoint)
    }
    
    /// 获取活动详情
    func getActivityDetail(activityId: Int) -> AnyPublisher<Activity, APIError> {
        return request(Activity.self, APIEndpoints.Activities.detail(activityId))
    }
    
    /// 申请参与活动
    func applyToActivity(activityId: Int, timeSlotId: Int? = nil, preferredDeadline: String? = nil, isFlexibleTime: Bool = false) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = ActivityApplyRequest(
            timeSlotId: timeSlotId,
            preferredDeadline: preferredDeadline,
            isFlexibleTime: isFlexibleTime,
            idempotencyKey: idempotencyKey
        )
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Activities.apply(activityId), method: "POST", body: bodyDict)
    }
    
    // MARK: - Multi-Participant Tasks (多人任务)
    
    /// 获取任务参与者列表
    func getTaskParticipants(taskId: String) -> AnyPublisher<TaskParticipantsResponse, APIError> {
        return request(TaskParticipantsResponse.self, APIEndpoints.Tasks.participants(taskId))
    }
    
    /// 申请参与多人任务 (非活动创建)
    func applyToMultiParticipantTask(taskId: String, timeSlotId: Int? = nil, preferredDeadline: String? = nil, isFlexibleTime: Bool = false) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = TaskApplyRequest(
            timeSlotId: timeSlotId,
            preferredDeadline: preferredDeadline,
            isFlexibleTime: isFlexibleTime,
            idempotencyKey: idempotencyKey
        )
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        // 使用支持字符串 ID 的 apply 方法
        return request(EmptyResponse.self, APIEndpoints.Tasks.applyString(taskId), method: "POST", body: bodyDict)
    }
    
    /// 参与者提交完成
    func completeParticipantTask(taskId: String, completionNotes: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = TaskParticipantCompleteRequest(completionNotes: completionNotes, idempotencyKey: idempotencyKey)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.participantComplete(taskId), method: "POST", body: bodyDict)
    }
    
    /// 参与者申请退出
    func requestExitFromTask(taskId: String, exitReason: String) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = TaskParticipantExitRequest(exitReason: exitReason, idempotencyKey: idempotencyKey)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.participantExitRequest(taskId), method: "POST", body: bodyDict)
    }
    
    // MARK: - Activity Favorites (活动收藏)
    
    /// 收藏/取消收藏活动
    func toggleActivityFavorite(activityId: Int) -> AnyPublisher<ActivityFavoriteToggleResponse, APIError> {
        return request(ActivityFavoriteToggleResponse.self, APIEndpoints.Activities.favorite(activityId), method: "POST")
    }
    
    /// 获取活动收藏状态
    func getActivityFavoriteStatus(activityId: Int) -> AnyPublisher<ActivityFavoriteStatusResponse, APIError> {
        return request(ActivityFavoriteStatusResponse.self, APIEndpoints.Activities.favoriteStatus(activityId))
    }
}

