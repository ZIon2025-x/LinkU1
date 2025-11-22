//
//  APIService.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation
import Combine

class APIService {
    static let shared = APIService()
    
    let baseURL = "https://api.link2ur.com"
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: configuration)
    }
    
    // 通用请求方法
    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证token
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // 添加自定义headers
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        // 添加请求体
        if let body = body {
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                return Fail(error: APIError.encodingError)
                    .eraseToAnyPublisher()
            }
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError
                } else {
                    return APIError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // 获取任务列表
    func getTasks(params: TaskListParams) -> AnyPublisher<TaskListResponse, APIError> {
        var queryItems: [URLQueryItem] = []
        if let category = params.category {
            queryItems.append(URLQueryItem(name: "task_type", value: category))
        }
        if let city = params.city {
            queryItems.append(URLQueryItem(name: "location", value: city))
        }
        
        var endpoint = "/api/tasks"
        if !queryItems.isEmpty {
            var components = URLComponents(string: baseURL + endpoint)!
            components.queryItems = queryItems
            if let query = components.url?.query {
                endpoint = "\(endpoint)?\(query)"
            }
        }
        
        return request(endpoint: endpoint)
    }
    
    // 上传图片
    func uploadImage(_ imageData: Data) -> AnyPublisher<ImageUploadResponse, APIError> {
        guard let url = URL(string: "\(baseURL)/api/upload/image") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainHelper.shared.getToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ImageUploadResponse.self, decoder: JSONDecoder())
            .mapError { _ in APIError.networkError(NSError()) }
            .eraseToAnyPublisher()
    }
    
    // 登录
    func login(_ request: LoginRequest) -> AnyPublisher<LoginResponse, APIError> {
        return self.request(endpoint: "/api/auth/login", method: .POST, body: request)
    }
    
    // 注册
    func register(_ request: RegisterRequest) -> AnyPublisher<LoginResponse, APIError> {
        return self.request(endpoint: "/api/auth/register", method: .POST, body: request)
    }
    
    // 获取任务详情
    func getTask(id: Int) -> AnyPublisher<Task, APIError> {
        return request(endpoint: "/api/tasks/\(id)", method: .GET)
    }
    
    // 创建任务
    func createTask(_ request: CreateTaskRequest) -> AnyPublisher<Task, APIError> {
        return request(endpoint: "/api/tasks", method: .POST, body: request)
    }
    
    // 获取跳蚤市场商品列表
    func getFleaMarketItems(category: String? = nil, keyword: String? = nil, page: Int = 1) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        var queryItems: [URLQueryItem] = []
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let keyword = keyword {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }
        queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
        
        var endpoint = "/api/flea-market/items"
        if !queryItems.isEmpty {
            var components = URLComponents(string: baseURL + endpoint)!
            components.queryItems = queryItems
            if let query = components.url?.query {
                endpoint = "\(endpoint)?\(query)"
            }
        }
        
        return request(endpoint: endpoint)
    }
    
    // 获取跳蚤市场分类
    func getFleaMarketCategories() -> AnyPublisher<FleaMarketCategoriesResponse, APIError> {
        return request(endpoint: "/api/flea-market/categories", method: .GET)
    }
    
    // 获取我的任务
    func getMyTasks(status: String? = nil) -> AnyPublisher<TaskListResponse, APIError> {
        var endpoint = "/api/users/tasks"
        if let status = status {
            endpoint += "?status=\(status)"
        }
        return request(endpoint: endpoint)
    }
    
    // 获取我的跳蚤市场商品
    func getMyFleaMarketItems(status: String? = nil) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        var endpoint = "/api/users/flea-market/items"
        if let status = status {
            endpoint += "?status=\(status)"
        }
        return request(endpoint: endpoint)
    }
    
    // 获取对话列表
    func getConversations() -> AnyPublisher<ConversationListResponse, APIError> {
        return request(endpoint: "/api/users/conversations", method: .GET)
    }
    
    // 获取对话消息
    func getMessages(conversationId: Int, page: Int = 1) -> AnyPublisher<MessageListResponse, APIError> {
        return request(endpoint: "/api/users/conversations/\(conversationId)/messages?page=\(page)", method: .GET)
    }
    
    // 发送消息（HTTP备用）
    func sendMessage(content: String, receiverId: Int, taskId: Int? = nil) -> AnyPublisher<Message, APIError> {
        let body: [String: Any] = [
            "content": content,
            "receiver_id": receiverId,
            "task_id": taskId as Any
        ]
        // 需要将字典转换为Encodable
        struct SendMessageRequest: Codable {
            let content: String
            let receiverId: Int
            let taskId: Int?
            
            enum CodingKeys: String, CodingKey {
                case content
                case receiverId = "receiver_id"
                case taskId = "task_id"
            }
        }
        
        let request = SendMessageRequest(content: content, receiverId: receiverId, taskId: taskId)
        return self.request(endpoint: "/api/messages", method: .POST, body: request)
    }
    
    // 获取未读消息数量
    func getUnreadCount() -> AnyPublisher<UnreadCountResponse, APIError> {
        return request(endpoint: "/api/users/messages/unread/count", method: .GET)
    }
    
    // 获取用户资料
    func getUserProfile() -> AnyPublisher<User, APIError> {
        return request(endpoint: "/api/users/profile/me", method: .GET)
    }
    
    // 更新用户资料
    func updateUserProfile(_ profile: UpdateUserProfileRequest) -> AnyPublisher<User, APIError> {
        return request(endpoint: "/api/users/profile/me", method: .PUT, body: profile)
    }
}

struct ConversationListResponse: Codable {
    let conversations: [Conversation]
}

struct MessageListResponse: Codable {
    let messages: [Message]
    let total: Int
    let page: Int
}

struct UnreadCountResponse: Codable {
    let count: Int
}

struct UpdateUserProfileRequest: Codable {
    let username: String?
    let phone: String?
    let city: String?
    let avatar: String?
}

struct FleaMarketItemListResponse: Codable {
    let items: [FleaMarketItem]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}

struct FleaMarketCategoriesResponse: Codable {
    let success: Bool
    let categories: [String]
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingError
    case decodingError
    case networkError(Error)
    case unauthorized
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .encodingError:
            return "编码错误"
        case .decodingError:
            return "解码错误"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .unauthorized:
            return "未授权，请重新登录"
        case .serverError(let code):
            return "服务器错误: \(code)"
        }
    }
}

struct TaskListParams {
    let category: String?
    let city: String?
}

