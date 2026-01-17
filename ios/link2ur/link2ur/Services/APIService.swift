import Foundation
import Combine
import UIKit

public enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case unauthorized
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .requestFailed(let error): return "请求失败: \(error.localizedDescription)"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code): return "服务器错误 (代码: \(code))"
        case .decodingError(let error): return "数据解析错误: \(error.localizedDescription)"
        case .unauthorized: return "未授权或登录已过期"
        case .unknown: return "未知错误"
        }
    }
}

public class APIService {
    public static let shared = APIService()
    
    private let session: URLSession
    private let baseURL = Constants.API.baseURL
    private var isRefreshing = false
    private var refreshSubject = PassthroughSubject<Void, APIError>()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.API.timeoutInterval
        
        // 设置默认的 HTTP headers（用于设备指纹生成）
        // 后端使用 user-agent, accept-language, accept-encoding 生成设备指纹
        // X-Platform 标识移动端，便于后端放宽设备指纹验证
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Link2Ur-iOS/1.0",
            "Accept-Language": Locale.preferredLanguages.joined(separator: ", "),
            "Accept-Encoding": "gzip, deflate, br",
            "X-Platform": "iOS"
        ]
        
        // 配置图片缓存
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB 内存缓存
            diskCapacity: 200 * 1024 * 1024,  // 200MB 磁盘缓存
            diskPath: "ImageCache"
        )
        configuration.urlCache = cache
        URLCache.shared = cache
        
        self.session = URLSession(configuration: configuration)
    }
    
    // Form-data 请求方法（用于 OAuth2 登录等）
    func requestFormData<T: Decodable>(_ type: T.Type, _ endpoint: String, method: String = "POST", body: [String: String]? = nil, headers: [String: String]? = nil) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 确保 iOS 应用识别所需的 headers 被设置（用于长期会话）
        // 后端通过 X-Platform 和 User-Agent 来识别 iOS 应用，创建 1 年有效期的会话
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // 注入 Session ID（后端使用 session-based 认证，移动端使用 X-Session-ID header）
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            // 添加应用签名
            AppSignature.signRequest(&request, sessionId: sessionId)
        }
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = body {
            let formData = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            request.httpBody = formData.data(using: .utf8)
        }
        
        // 记录请求开始时间
        let startTime = Date()
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    return Just(data)
                        .decode(type: T.self, decoder: JSONDecoder())
                        .mapError { APIError.decodingError($0) }
                        .eraseToAnyPublisher()
                } else if httpResponse.statusCode == 401 {
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<T, APIError> in
                            // 重试原请求
                            var retryRequest = request
                            if let newToken = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                            }
                            
                            return self.session.dataTaskPublisher(for: retryRequest)
                                .mapError { APIError.requestFailed($0) }
                                .flatMap { data, response -> AnyPublisher<T, APIError> in
                                    guard let httpResponse = response as? HTTPURLResponse else {
                                        return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                                    }
                                    
                                    if (200...299).contains(httpResponse.statusCode) {
                                        return Just(data)
                                            .decode(type: T.self, decoder: JSONDecoder())
                                            .mapError { APIError.decodingError($0) }
                                            .eraseToAnyPublisher()
                                    } else {
                                        // 尝试解析后端标准错误响应
                                        let apiError: APIError
                                        if let (parsedError, errorMessage) = APIError.parse(from: data) {
                                            Logger.error("API错误: \(errorMessage) (code: \(httpResponse.statusCode))", category: .api)
                                            apiError = parsedError
                                        } else {
                                            // 尝试从响应中提取错误详情
                                            if let errorData = String(data: data, encoding: .utf8) {
                                                Logger.error("HTTP错误响应 (\(httpResponse.statusCode)): \(errorData.prefix(500))", category: .api)
                                            }
                                            apiError = APIError.httpError(httpResponse.statusCode)
                                        }
                                        return Fail(error: apiError).eraseToAnyPublisher()
                                    }
                                }
                                .eraseToAnyPublisher()
                        }
                        .eraseToAnyPublisher()
                } else {
                    // 记录性能指标（其他HTTP错误）
                    let duration = Date().timeIntervalSince(startTime)
                    // 尝试解析后端标准错误响应
                    let apiError: APIError
                    if let (parsedError, errorMessage) = APIError.parse(from: data) {
                        Logger.error("API错误 (\(endpoint)): \(errorMessage) (code: \(httpResponse.statusCode))", category: .api)
                        apiError = parsedError
                    } else {
                        // 记录详细的错误响应内容
                        if let errorData = String(data: data, encoding: .utf8) {
                            Logger.error("HTTP错误响应 (\(httpResponse.statusCode)): \(errorData.prefix(500))", category: .api)
                        }
                        apiError = APIError.httpError(httpResponse.statusCode)
                    }
                    PerformanceMonitor.shared.recordNetworkRequest(
                        endpoint: endpoint,
                        method: method,
                        duration: duration,
                        statusCode: httpResponse.statusCode,
                        error: apiError
                    )
                    return Fail(error: apiError).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func request<T: Decodable>(_ type: T.Type, _ endpoint: String, method: String = "GET", body: [String: Any]? = nil, headers: [String: String]? = nil) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 确保 iOS 应用识别所需的 headers 被设置（用于长期会话）
        // 后端通过 X-Platform 和 User-Agent 来识别 iOS 应用，创建 1 年有效期的会话
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // 注入 Session ID（后端使用 session-based 认证，移动端使用 X-Session-ID header）
        // 检查是否是公开端点（不需要认证）
        let isPublicEndpoint = APIEndpoints.publicEndpoints.contains { endpoint.contains($0) }
        
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            // 添加应用签名（用于后端验证请求来自真正的 App）
            AppSignature.signRequest(&request, sessionId: sessionId)
        } else if !isPublicEndpoint {
            // 只在非公开端点显示警告
            Logger.warning("请求 \(endpoint) 时 Session ID 为空，可能导致401错误", category: .api)
        }
        
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = body {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return Fail(error: APIError.requestFailed(error)).eraseToAnyPublisher()
            }
        }
        
        Logger.debug("请求: \(method) \(endpoint)", category: .api)
        
        // 记录请求开始时间
        let startTime = Date()
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    // 记录性能指标（错误情况）
                    let duration = Date().timeIntervalSince(startTime)
                    PerformanceMonitor.shared.recordNetworkRequest(
                        endpoint: endpoint,
                        method: method,
                        duration: duration,
                        statusCode: nil,
                        error: APIError.invalidResponse
                    )
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // 打印原始响应数据（用于调试）
                    if let jsonString = String(data: data, encoding: .utf8) {
                        Logger.debug("响应数据 (\(endpoint)): \(jsonString.prefix(500))", category: .api)
                    }
                    
                    // 记录性能指标（成功情况）
                    let duration = Date().timeIntervalSince(startTime)
                    PerformanceMonitor.shared.recordNetworkRequest(
                        endpoint: endpoint,
                        method: method,
                        duration: duration,
                        statusCode: httpResponse.statusCode,
                        error: nil
                    )
                    
                    return Just(data)
                        .decode(type: T.self, decoder: JSONDecoder())
                        .mapError { error in
                            // 打印解码错误详情
                            if let jsonString = String(data: data, encoding: .utf8) {
                                Logger.error("解码错误 (\(endpoint)): \(error)", category: .api)
                                Logger.debug("原始数据: \(jsonString.prefix(1000))", category: .api)
                            }
                            return APIError.decodingError(error)
                        }
                        .eraseToAnyPublisher()
                } else if httpResponse.statusCode == 401 {
                    // 记录性能指标（401错误）
                    let duration = Date().timeIntervalSince(startTime)
                    PerformanceMonitor.shared.recordNetworkRequest(
                        endpoint: endpoint,
                        method: method,
                        duration: duration,
                        statusCode: httpResponse.statusCode,
                        error: APIError.unauthorized
                    )
                    // 记录401错误详情
                    Logger.error("401 未授权错误: \(endpoint)", category: .api)
                    // 打印响应内容，帮助调试
                    if let errorData = String(data: data, encoding: .utf8) {
                        Logger.debug("401 错误响应内容: \(errorData.prefix(500))", category: .api)
                    }
                    if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                        Logger.debug("Session ID 存在: \(sessionId.prefix(20))...", category: .api)
                    } else {
                        Logger.error("Session ID 不存在，请重新登录", category: .auth)
                    }
                    
                    // Token刷新策略
                    Logger.debug("🔄 检测到 401 错误，尝试刷新 Session", category: .api)
                    // 保存原始请求的 body 和 headers，用于重试
                    let originalBody = request.httpBody
                    let originalHeaders = request.allHTTPHeaderFields
                    
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<T, APIError> in
                            // 重新构建请求（确保所有 header 和 body 都正确设置）
                            guard let retryURL = URL(string: "\(self.baseURL)\(endpoint)") else {
                                return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
                            }
                            
                            var retryRequest = URLRequest(url: retryURL)
                            retryRequest.httpMethod = method
                            
                            // 恢复原始 headers（包括 User-Agent, Accept-Language, Accept-Encoding 等）
                            // 这些 header 对设备指纹生成很重要
                            if let originalHeaders = originalHeaders {
                                for (key, value) in originalHeaders {
                                    // 确保所有 header 都被恢复，特别是设备指纹相关的
                                    retryRequest.setValue(value, forHTTPHeaderField: key)
                                }
                            }
                            
                            // 确保设备指纹相关的 header 存在（如果原始请求中没有）
                            if retryRequest.value(forHTTPHeaderField: "User-Agent") == nil {
                                retryRequest.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
                            }
                            if retryRequest.value(forHTTPHeaderField: "Accept-Language") == nil {
                                retryRequest.setValue(Locale.preferredLanguages.joined(separator: ", "), forHTTPHeaderField: "Accept-Language")
                            }
                            if retryRequest.value(forHTTPHeaderField: "Accept-Encoding") == nil {
                                retryRequest.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
                            }
                            // 确保 X-Platform 标识存在，便于后端识别移动端请求
                            if retryRequest.value(forHTTPHeaderField: "X-Platform") == nil {
                                retryRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
                            }
                            
                            // 设置 Content-Type（如果还没有）
                            if retryRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                                retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            }
                            
                            // 使用新的 Session ID 并添加签名
                            if let newSessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !newSessionId.isEmpty {
                                retryRequest.setValue(newSessionId, forHTTPHeaderField: "X-Session-ID")
                                // 添加应用签名（必须使用新的 Session ID 和当前时间戳）
                                AppSignature.signRequest(&retryRequest, sessionId: newSessionId)
                                Logger.debug("🔄 使用新 Session ID 重试请求: \(endpoint)", category: .api)
                                Logger.debug("🔄 新 Session ID: \(newSessionId.prefix(20))...", category: .api)
                            } else {
                                Logger.error("❌ 无法获取 Session ID，请求失败: \(endpoint)", category: .api)
                                return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                            }
                            
                            // 恢复原始 body
                            if let originalBody = originalBody {
                                retryRequest.httpBody = originalBody
                            }
                            
                            // 记录所有 header（用于调试设备指纹问题）
                            let headerKeys = retryRequest.allHTTPHeaderFields?.keys.joined(separator: ", ") ?? "none"
                            let hasUserAgent = retryRequest.value(forHTTPHeaderField: "User-Agent") != nil
                            let hasAcceptLanguage = retryRequest.value(forHTTPHeaderField: "Accept-Language") != nil
                            Logger.debug("🔄 重试请求详情: method=\(method), headers=\(headerKeys), hasBody=\(retryRequest.httpBody != nil), hasUserAgent=\(hasUserAgent), hasAcceptLanguage=\(hasAcceptLanguage)", category: .api)
                            
                            return self.session.dataTaskPublisher(for: retryRequest)
                                .mapError { APIError.requestFailed($0) }
                                .flatMap { data, response -> AnyPublisher<T, APIError> in
                                    guard let httpResponse = response as? HTTPURLResponse else {
                                        return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                                    }
                                    
                                    // 打印响应状态码和数据（用于调试）
                                    Logger.debug("🔄 重试响应状态码: \(httpResponse.statusCode), 端点: \(endpoint)", category: .api)
                                    if let responseData = String(data: data, encoding: .utf8) {
                                        Logger.debug("🔄 重试响应内容: \(responseData.prefix(500))", category: .api)
                                    }
                                    
                                    if (200...299).contains(httpResponse.statusCode) {
                                        return Just(data)
                                            .decode(type: T.self, decoder: JSONDecoder())
                                            .mapError { APIError.decodingError($0) }
                                            .eraseToAnyPublisher()
                                    } else {
                                        Logger.error("❌ 重试后仍然失败，状态码: \(httpResponse.statusCode), 端点: \(endpoint)", category: .api)
                                        // 尝试解析后端标准错误响应
                                        let apiError: APIError
                                        if let (parsedError, errorMessage) = APIError.parse(from: data) {
                                            Logger.error("API错误详情: \(errorMessage)", category: .api)
                                            apiError = parsedError
                                        } else {
                                            // 尝试获取错误详情
                                            if let errorData = String(data: data, encoding: .utf8) {
                                                Logger.debug("❌ 错误响应内容: \(errorData.prefix(500))", category: .api)
                                            }
                                            apiError = APIError.httpError(httpResponse.statusCode)
                                        }
                                        // 如果是401错误且刷新也成功，可能是设备指纹不匹配或其他后端验证问题
                                        // 不自动清除Session，让用户手动处理
                                        if httpResponse.statusCode == 401 {
                                            Logger.warning("⚠️ Session 刷新成功但重试仍失败，可能是设备指纹不匹配或后端验证问题，请检查后端日志", category: .api)
                                        }
                                        return Fail(error: apiError).eraseToAnyPublisher()
                                    }
                                }
                                .eraseToAnyPublisher()
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: APIError.httpError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // Session刷新处理
    private func handle401Error() -> AnyPublisher<Void, APIError> {
        // 检查是否有 session_id
        guard let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty else {
            // 没有 session_id，记录错误但不自动登出（避免频繁登出）
            Logger.warning("⚠️ Session ID 不存在，无法刷新", category: .api)
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        // 如果正在刷新，等待刷新完成
        if isRefreshing {
            return refreshSubject
                .first()
                .eraseToAnyPublisher()
        }
        
        // 开始刷新
        isRefreshing = true
        
        // 后端使用 session-based 认证，refresh 端点通过 X-Session-ID header 验证，不需要 body
        guard let refreshURL = URL(string: "\(baseURL)\(APIEndpoints.Auth.refresh)") else {
            isRefreshing = false
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var refreshRequest = URLRequest(url: refreshURL)
        refreshRequest.httpMethod = "POST"
        refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 发送当前的 session_id（后端会验证并刷新）
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            refreshRequest.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }
        
        Logger.debug("🔄 开始刷新 Session: \(refreshURL.absoluteString)", category: .api)
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            Logger.debug("🔄 当前 Session ID: \(sessionId.prefix(20))...", category: .api)
        }
        
        return session.dataTaskPublisher(for: refreshRequest)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<Void, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    Logger.error("❌ Session 刷新失败: 无效响应", category: .api)
                    self.isRefreshing = false
                    self.notifyRefreshQueue()
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                Logger.debug("🔄 Session 刷新响应: 状态码 \(httpResponse.statusCode)", category: .api)
                
                if (200...299).contains(httpResponse.statusCode) {
                    do {
                        if let jsonString = String(data: data, encoding: .utf8) {
                            Logger.debug("🔄 Session 刷新响应数据: \(jsonString.prefix(200))", category: .api)
                        }
                        
                        let refreshResponse = try JSONDecoder().decode(RefreshResponse.self, from: data)
                        // 保存新的 session_id
                        if let sessionId = refreshResponse.sessionId {
                            Logger.success("✅ Session 刷新成功，新 Session ID: \(sessionId.prefix(20))...", category: .api)
                            KeychainHelper.shared.save(sessionId, service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                        } else {
                            Logger.warning("⚠️ Session 刷新响应中没有新的 Session ID", category: .api)
                        }
                        
                        // 更新请求的Authorization header
                        // 注意：这里无法直接修改originalRequest，需要在重试时重新设置
                        self.isRefreshing = false
                        self.notifyRefreshQueue()
                        return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } catch {
                        Logger.error("❌ Session 刷新响应解码失败: \(error)", category: .api)
                        if let jsonString = String(data: data, encoding: .utf8) {
                            Logger.debug("🔄 原始响应数据: \(jsonString)", category: .api)
                        }
                        self.isRefreshing = false
                        self.notifyRefreshQueue()
                        return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
                    }
                } else {
                    // 刷新失败，记录错误但不自动清除Session（避免频繁登出）
                    Logger.error("❌ Session 刷新失败，状态码: \(httpResponse.statusCode)", category: .api)
                    if let jsonString = String(data: data, encoding: .utf8) {
                        Logger.debug("🔄 刷新失败响应: \(jsonString.prefix(500))", category: .api)
                    }
                    // 不自动清除Session，让用户手动处理或由其他逻辑处理
                    self.isRefreshing = false
                    self.notifyRefreshQueue()
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func notifyRefreshQueue() {
        refreshSubject.send(())
    }
    
    // 文件上传
    func uploadImage(_ data: Data, filename: String = "image.jpg") -> AnyPublisher<String, APIError> {
        guard let url = URL(string: "\(baseURL)\(APIEndpoints.Common.uploadImage)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 确保 iOS 应用识别所需的 headers 被设置（用于长期会话）
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // 注入 Session ID（后端使用 session-based 认证，移动端使用 X-Session-ID header）
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            // 添加应用签名
            AppSignature.signRequest(&request, sessionId: sessionId)
        }
        
        // 构建multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<String, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // 假设返回JSON格式: {"url": "..."} 或直接返回URL字符串
                    if let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       urlString.hasPrefix("http") {
                        return Just(urlString).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let url = json["url"] as? String {
                        return Just(url).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else {
                        return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析上传响应"]))).eraseToAnyPublisher()
                    }
                } else if httpResponse.statusCode == 401 {
                    // Token过期，尝试刷新
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<String, APIError> in
                            // 重试上传
                            return self.uploadImage(data, filename: filename)
                        }
                        .eraseToAnyPublisher()
                } else {
                    // 尝试解析后端标准错误响应
                    let apiError: APIError
                    if let (parsedError, errorMessage) = APIError.parse(from: data) {
                        Logger.error("上传图片API错误: \(errorMessage) (code: \(httpResponse.statusCode))", category: .api)
                        apiError = parsedError
                    } else {
                        apiError = APIError.httpError(httpResponse.statusCode)
                    }
                    return Fail(error: apiError).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// 上传图片的便捷方法 (支持 UIImage 和 path)
    func uploadImage(_ image: UIImage, path: String, completion: @escaping (Result<String, APIError>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(APIError.decodingError(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法转换图片数据"]))))
            return
        }
        
        let filename = "\(path)_\(Int(Date().timeIntervalSince1970)).jpg"
        
        self.uploadImage(data, filename: filename)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    completion(.failure(error))
                }
            }, receiveValue: { url in
                completion(.success(url))
            })
            .store(in: &cancellables)
    }
    
    // 注册设备Token（用于推送通知）
    public func registerDeviceToken(_ token: String, completion: @escaping (Bool) -> Void) {
        // 获取应用版本
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        
        // 获取设备唯一标识符
        let deviceId = DeviceInfo.deviceIdentifier
        
        // 获取设备系统语言（用于推送通知本地化）
        // 只有中文使用中文推送，其他所有语言都使用英文推送
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = preferredLanguage.components(separatedBy: "-").first ?? "en"
        // 如果是中文相关语言，返回 "zh"；其他所有语言都返回 "en"
        let deviceLanguage = languageCode.lowercased().hasPrefix("zh") ? "zh" : "en"
        
        let body: [String: Any] = [
            "device_token": token,
            "platform": "ios",
            "device_id": deviceId,
            "app_version": appVersion,
            "device_language": deviceLanguage  // 设备系统语言
        ]
        
        request(EmptyResponse.self, APIEndpoints.Users.deviceToken, method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    // 如果API不存在，静默失败（不影响应用使用）
                    print("Device token registration failed (API may not exist)")
                    completion(false)
                }
            }, receiveValue: { _ in
                print("Device token registered successfully")
                completion(true)
            })
            .store(in: &cancellables)
    }
}

// MARK: - Async/Await 版本
extension APIService {
    /// Async/await 版本的 GET 请求（支持查询参数）
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        // 构建 URL（包含查询参数）
        var urlString = "\(baseURL)\(endpoint)"
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            urlString += "?\(queryString)"
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 注入 Session ID
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            AppSignature.signRequest(&request, sessionId: sessionId)
        }
        
        // 添加自定义 headers
        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 添加 body
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        Logger.debug("Async 请求: \(method.rawValue) \(endpoint)", category: .api)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        // 调试输出
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.debug("Async 响应 (\(endpoint)): \(jsonString.prefix(300))", category: .api)
        }
        
        do {
            // 注意：不使用 convertFromSnakeCase，因为模型的 CodingKeys 已经处理了 snake_case 转换
            // 这样可以保持与 Combine 版本 request 方法的一致性
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.error("Async 解码错误 (\(endpoint)): \(error)", category: .api)
            throw APIError.decodingError(error)
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// 辅助空响应结构体
struct EmptyResponse: Decodable {}

