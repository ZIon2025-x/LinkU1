//
//  Task.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation

struct Task: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let taskType: String
    let location: String
    let reward: Double
    let status: TaskStatus
    let createdAt: String
    let updatedAt: String?
    let posterId: String
    let takerId: String?
    let images: [String]?
    let deadline: String?
    let isFlexible: Int?
    
    // 计算属性，兼容旧代码
    var category: String { taskType }
    var city: String { location }
    var price: Double? { reward }
    var author: User? { nil } // 需要单独获取
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, images, deadline
        case taskType = "task_type"
        case location
        case reward
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case posterId = "poster_id"
        case takerId = "taker_id"
        case isFlexible = "is_flexible"
    }
}

enum TaskStatus: String, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
}

struct TaskListResponse: Codable {
    let tasks: [Task]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case tasks, total, page
        case pageSize = "page_size"
    }
}

struct CreateTaskRequest: Codable {
    let title: String
    let description: String
    let taskType: String
    let location: String
    let reward: Double
    let images: [String]?
    let deadline: String?
    let isFlexible: Int
    let isPublic: Int
    
    enum CodingKeys: String, CodingKey {
        case title, description, images, deadline
        case taskType = "task_type"
        case location
        case reward
        case isFlexible = "is_flexible"
        case isPublic = "is_public"
    }
}

