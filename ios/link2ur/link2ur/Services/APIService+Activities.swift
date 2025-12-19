import Foundation
import Combine

// MARK: - APIService Activities & Multi-Participant Tasks Extension
// Note: Models are defined in Models/Activity.swift

// MARK: - APIService Activities & Multi-Participant Tasks Extension

extension APIService {
    
    // MARK: - Activities (活动)
    
    /// 获取活动列表
    func getActivities(expertId: String? = nil, status: String? = nil, limit: Int = 20, offset: Int = 0) -> AnyPublisher<[Activity], APIError> {
        var endpoint = "/api/activities?limit=\(limit)&offset=\(offset)"
        if let expertId = expertId {
            endpoint += "&expert_id=\(expertId)"
        }
        if let status = status {
            endpoint += "&status=\(status)"
        }
        return request([Activity].self, endpoint)
    }
    
    /// 获取活动详情
    func getActivityDetail(activityId: Int) -> AnyPublisher<Activity, APIError> {
        return request(Activity.self, "/api/activities/\(activityId)")
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
        
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, "/api/activities/\(activityId)/apply", method: "POST", body: bodyDict)
    }
    
    // MARK: - Multi-Participant Tasks (多人任务)
    
    /// 获取任务参与者列表
    func getTaskParticipants(taskId: String) -> AnyPublisher<TaskParticipantsResponse, APIError> {
        return request(TaskParticipantsResponse.self, "/api/tasks/\(taskId)/participants")
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
        
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/apply", method: "POST", body: bodyDict)
    }
    
    /// 参与者提交完成
    func completeParticipantTask(taskId: String, completionNotes: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = TaskParticipantCompleteRequest(completionNotes: completionNotes, idempotencyKey: idempotencyKey)
        
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/participants/me/complete", method: "POST", body: bodyDict)
    }
    
    /// 参与者申请退出
    func requestExitFromTask(taskId: String, exitReason: String) -> AnyPublisher<EmptyResponse, APIError> {
        let idempotencyKey = UUID().uuidString
        let body = TaskParticipantExitRequest(exitReason: exitReason, idempotencyKey: idempotencyKey)
        
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/participants/me/exit-request", method: "POST", body: bodyDict)
    }
}

