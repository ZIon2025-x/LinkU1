# iOS 与后端 API 连接优化建议

## 概述

本文档分析了 iOS 应用与后端 API 的连接情况，并提供了优化建议。

## 发现的问题

### 1. API 端点管理分散

**问题**：
- API 端点字符串硬编码在多个文件中（`APIService+Endpoints.swift`, `APIService+Activities.swift` 等）
- 没有统一的端点常量管理
- 端点路径容易出错，且难以维护

**影响**：
- 端点路径修改时需要搜索多个文件
- 容易出现拼写错误
- 无法在编译时检查端点路径的正确性

### 2. 错误处理不统一

**问题**：
- 后端返回标准错误格式：`{"error": true, "message": "...", "error_code": "...", "status_code": ...}`
- iOS 端没有统一解析后端错误响应的逻辑
- 错误信息显示不够友好

**后端错误格式**：
```json
{
  "error": true,
  "message": "错误描述",
  "error_code": "ERROR_CODE",
  "status_code": 400,
  "details": {...}  // 可选
}
```

### 3. 代码重复

**问题**：
- `Encodable` 转 `Dictionary` 的逻辑在多处重复
- URL 查询参数构建方式不一致
- 请求构建逻辑重复

**示例**：
```swift
// 在多处重复出现
guard let bodyData = try? JSONEncoder().encode(body),
      let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
    return Fail(error: APIError.unknown).eraseToAnyPublisher()
}
```

### 4. URL 构建问题

**问题**：
- 查询参数构建方式不一致（字符串拼接 vs URLComponents）
- URL 编码处理可能不完整
- 容易出现 URL 格式错误

**示例**：
```swift
// 方式1：字符串拼接（容易出错）
var endpoint = "/api/tasks?page=\(page)&page_size=\(pageSize)"

// 方式2：使用 URLComponents（更安全，但未统一使用）
```

### 5. 401 错误处理复杂

**问题**：
- Session 刷新逻辑复杂，代码冗长（200+ 行）
- 重试逻辑嵌套较深
- 错误处理不够清晰

### 6. 类型安全不足

**问题**：
- 端点路径是字符串类型，无法在编译时检查
- HTTP 方法使用字符串，容易拼写错误
- 缺少类型安全的 API 调用方式

## 优化方案

### 方案 1: 统一 API 端点管理

**创建 `APIEndpoints.swift` 文件**：

```swift
import Foundation

enum APIEndpoints {
    // MARK: - Authentication
    enum Auth {
        static let login = "/api/secure-auth/login"
        static let loginWithCode = "/api/secure-auth/login-with-code"
        static let loginWithPhoneCode = "/api/secure-auth/login-with-phone-code"
        static let sendVerificationCode = "/api/secure-auth/send-verification-code"
        static let sendPhoneVerificationCode = "/api/secure-auth/send-phone-verification-code"
        static let refresh = "/api/secure-auth/refresh"
        static let logout = "/api/secure-auth/logout"
        static let captchaSiteKey = "/api/secure-auth/captcha-site-key"
    }
    
    // MARK: - Users
    enum Users {
        static let register = "/api/users/register"
        static let profileMe = "/api/users/profile/me"
        static func profile(_ userId: String) -> String {
            "/api/users/profile/\(userId)"
        }
        static let updateAvatar = "/api/users/profile/avatar"
        static let sendEmailUpdateCode = "/api/users/profile/send-email-update-code"
        static let sendPhoneUpdateCode = "/api/users/profile/send-phone-update-code"
        static let myTasks = "/api/users/my-tasks"
        static let notifications = "/api/users/notifications"
        static let unreadNotifications = "/api/users/notifications/unread"
        static func markNotificationRead(_ id: Int) -> String {
            "/api/users/notifications/\(id)/read"
        }
        static let markAllNotificationsRead = "/api/users/notifications/read-all"
    }
    
    // MARK: - Tasks
    enum Tasks {
        static let list = "/api/tasks"
        static func detail(_ id: Int) -> String {
            "/api/tasks/\(id)"
        }
        static func apply(_ id: Int) -> String {
            "/api/tasks/\(id)/apply"
        }
        static func complete(_ id: Int) -> String {
            "/api/users/tasks/\(id)/complete"
        }
        static func confirmCompletion(_ id: Int) -> String {
            "/api/tasks/\(id)/confirm_completion"
        }
        static func cancel(_ id: Int) -> String {
            "/api/tasks/\(id)/cancel"
        }
        static func delete(_ id: Int) -> String {
            "/api/tasks/\(id)/delete"
        }
        static func participants(_ id: String) -> String {
            "/api/tasks/\(id)/participants"
        }
    }
    
    // MARK: - Forum
    enum Forum {
        static let categories = "/api/forum/forums/visible"
        static let posts = "/api/forum/posts"
        static func postDetail(_ id: Int) -> String {
            "/api/forum/posts/\(id)"
        }
        static func replies(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/replies"
        }
        static let likes = "/api/forum/likes"
        static let favorites = "/api/forum/favorites"
        static func incrementView(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/view"
        }
    }
    
    // MARK: - Flea Market
    enum FleaMarket {
        static let items = "/api/flea-market/items"
        static func itemDetail(_ id: String) -> String {
            "/api/flea-market/items/\(id)"
        }
        static func directPurchase(_ id: String) -> String {
            "/api/flea-market/items/\(id)/direct-purchase"
        }
        static func refresh(_ id: String) -> String {
            "/api/flea-market/items/\(id)/refresh"
        }
        static let myPurchases = "/api/flea-market/my-purchases"
        static let favorites = "/api/flea-market/favorites/items"
    }
    
    // MARK: - Task Experts
    enum TaskExperts {
        static let list = "/api/task-experts"
        static func detail(_ id: String) -> String {
            "/api/task-experts/\(id)"
        }
        static func services(_ expertId: String) -> String {
            "/api/task-experts/\(expertId)/services"
        }
        static func applyForService(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)/apply"
        }
        static let apply = "/api/task-experts/apply"
    }
    
    // MARK: - Activities
    enum Activities {
        static let list = "/api/activities"
        static func detail(_ id: Int) -> String {
            "/api/activities/\(id)"
        }
        static func apply(_ id: Int) -> String {
            "/api/activities/\(id)/apply"
        }
        static func favorite(_ id: Int) -> String {
            "/api/activities/\(id)/favorite"
        }
        static func favoriteStatus(_ id: Int) -> String {
            "/api/activities/\(id)/favorite/status"
        }
    }
    
    // MARK: - Common
    enum Common {
        static let uploadImage = "/api/upload/image"
        static let banners = "/api/banners"
    }
    
    // MARK: - Public Endpoints (不需要认证)
    static let publicEndpoints: Set<String> = [
        Auth.login,
        Auth.loginWithCode,
        Auth.loginWithPhoneCode,
        Auth.sendVerificationCode,
        Auth.sendPhoneVerificationCode,
        Users.register,
        Forum.posts,
        Forum.categories,
        Activities.list,
        Common.banners
    ]
}
```

### 方案 2: 统一错误响应解析

**创建 `APIErrorResponse.swift` 文件**：

```swift
import Foundation

struct APIErrorResponse: Decodable {
    let error: Bool
    let message: String
    let errorCode: String
    let statusCode: Int
    let details: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case error
        case message
        case errorCode = "error_code"
        case statusCode = "status_code"
        case details
    }
}

extension APIError {
    /// 从后端错误响应创建 APIError
    static func from(errorResponse: APIErrorResponse) -> APIError {
        switch errorResponse.statusCode {
        case 401:
            return .unauthorized
        case 400...499:
            return .httpError(errorResponse.statusCode)
        case 500...599:
            return .httpError(errorResponse.statusCode)
        default:
            return .unknown
        }
    }
    
    /// 从 HTTP 响应数据解析错误
    static func parse(from data: Data) -> (error: APIError, message: String)? {
        guard let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) else {
            return nil
        }
        return (from(errorResponse: errorResponse), errorResponse.message)
    }
}
```

**更新 `APIService.request` 方法**：

```swift
// 在错误处理部分添加
} else {
    // 尝试解析后端错误响应
    if let (apiError, message) = APIError.parse(from: data) {
        Logger.error("API错误: \(message) (code: \(httpResponse.statusCode))", category: .api)
        return Fail(error: apiError).eraseToAnyPublisher()
    }
    return Fail(error: APIError.httpError(httpResponse.statusCode)).eraseToAnyPublisher()
}
```

### 方案 3: 提取公共请求构建逻辑

**创建 `RequestBuilder.swift` 文件**：

```swift
import Foundation

struct RequestBuilder {
    /// 将 Encodable 对象转换为 Dictionary
    static func encodeToDictionary<T: Encodable>(_ object: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(object),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    /// 构建带查询参数的 URL
    static func buildURL(baseURL: String, endpoint: String, queryParams: [String: String?]? = nil) -> URL? {
        guard let base = URL(string: baseURL) else { return nil }
        guard var components = URLComponents(string: baseURL + endpoint) else { return nil }
        
        if let params = queryParams, !params.isEmpty {
            components.queryItems = params.compactMap { key, value in
                guard let value = value else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }
        
        return components.url
    }
    
    /// 构建查询参数字符串（用于向后兼容）
    static func buildQueryString(_ params: [String: String?]) -> String {
        let items = params.compactMap { key, value -> String? in
            guard let value = value else { return nil }
            return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        return items.joined(separator: "&")
    }
}
```

**使用示例**：

```swift
// 替换原来的代码
func getTasks(page: Int = 1, pageSize: Int = 20, type: String? = nil) -> AnyPublisher<TaskListResponse, APIError> {
    let queryParams: [String: String?] = [
        "page": "\(page)",
        "page_size": "\(pageSize)",
        "task_type": type
    ]
    
    guard let url = RequestBuilder.buildURL(
        baseURL: baseURL,
        endpoint: APIEndpoints.Tasks.list,
        queryParams: queryParams
    ) else {
        return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
    }
    
    var request = URLRequest(url: url)
    // ... 设置请求头等
}
```

### 方案 4: 简化 401 错误处理

**创建 `SessionRefreshManager.swift` 文件**：

```swift
import Foundation
import Combine

class SessionRefreshManager {
    static let shared = SessionRefreshManager()
    
    private var isRefreshing = false
    private var refreshSubject = PassthroughSubject<Void, APIError>()
    private var pendingRequests: [(URLRequest) -> Void] = []
    
    func refreshSession() -> AnyPublisher<Void, APIError> {
        if isRefreshing {
            return refreshSubject.first().eraseToAnyPublisher()
        }
        
        isRefreshing = true
        
        guard let sessionId = KeychainHelper.shared.read(
            service: Constants.Keychain.service,
            account: Constants.Keychain.accessTokenKey
        ), !sessionId.isEmpty else {
            isRefreshing = false
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        guard let url = URL(string: "\(Constants.API.baseURL)\(APIEndpoints.Auth.refresh)") else {
            isRefreshing = false
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<Void, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.isRefreshing = false
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    self.isRefreshing = false
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
                
                if let refreshResponse = try? JSONDecoder().decode(RefreshResponse.self, from: data),
                   let newSessionId = refreshResponse.sessionId {
                    KeychainHelper.shared.save(
                        newSessionId,
                        service: Constants.Keychain.service,
                        account: Constants.Keychain.accessTokenKey
                    )
                }
                
                self.isRefreshing = false
                self.refreshSubject.send(())
                return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
```

**简化 `APIService.request` 中的 401 处理**：

```swift
} else if httpResponse.statusCode == 401 {
    return SessionRefreshManager.shared.refreshSession()
        .flatMap { [weak self] () -> AnyPublisher<T, APIError> in
            // 使用新的 session ID 重试请求
            guard let self = self else {
                return Fail(error: APIError.unknown).eraseToAnyPublisher()
            }
            // 重新构建请求并重试
            return self.retryRequest(originalRequest: request, endpoint: endpoint, method: method, body: body)
        }
        .eraseToAnyPublisher()
}
```

### 方案 5: 类型安全的 HTTP 方法

**扩展 `HTTPMethod` 枚举**：

```swift
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
    
    var allowsBody: Bool {
        switch self {
        case .get, .delete:
            return false
        case .post, .put, .patch:
            return true
        }
    }
}
```

### 方案 6: 统一公开端点检查

**在 `APIService` 中使用**：

```swift
private func isPublicEndpoint(_ endpoint: String) -> Bool {
    return APIEndpoints.publicEndpoints.contains { endpoint.contains($0) }
}
```

## 实施优先级

1. **高优先级**：
   - 统一 API 端点管理（方案 1）
   - 统一错误响应解析（方案 2）
   - 提取公共请求构建逻辑（方案 3）

2. **中优先级**：
   - 简化 401 错误处理（方案 4）
   - 统一公开端点检查（方案 6）

3. **低优先级**：
   - 类型安全的 HTTP 方法（方案 5）

## 预期收益

1. **可维护性提升**：
   - 端点修改只需在一个地方
   - 减少代码重复
   - 提高代码可读性

2. **错误处理改进**：
   - 统一错误响应格式
   - 更友好的错误提示
   - 更好的错误日志记录

3. **类型安全**：
   - 编译时检查端点路径
   - 减少运行时错误
   - 更好的 IDE 支持

4. **代码质量**：
   - 减少代码重复
   - 提高代码复用性
   - 更清晰的代码结构

## 注意事项

1. **向后兼容**：实施时需要确保不影响现有功能
2. **渐进式迁移**：可以逐步迁移，不需要一次性完成
3. **测试**：每个方案实施后都需要充分测试
4. **文档**：更新相关文档，确保团队了解新的 API 使用方式

