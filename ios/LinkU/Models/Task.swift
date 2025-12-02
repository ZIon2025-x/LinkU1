import Foundation

struct Task: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let category: String
    let city: String
    let price: Double?
    let status: TaskStatus
    let images: [String]?
    let createdAt: String
    let author: User?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, city, price, status, images
        case createdAt = "created_at"
        case author
    }
}

enum TaskStatus: String, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayText: String {
        switch self {
        case .open: return "开放中"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        }
    }
}

struct TaskListResponse: Codable {
    let tasks: [Task]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case tasks
        case total
        case page
        case pageSize = "page_size"
    }
}

