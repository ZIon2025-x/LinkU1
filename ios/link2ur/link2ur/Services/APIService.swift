import Foundation
import Combine
import UIKit

public enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case httpError(Int)
    case serverError(Int, String)
    case decodingError(Error)
    case unauthorized
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的 URL"
        case .requestFailed(let error): return "请求失败: \(error.localizedDescription)"
        case .invalidResponse: return "无效的响应"
        case .httpError(let code): return "服务器错误 (代码: \(code))"
        case .serverError(let code, let message): return "服务器错误 (代码: \(code)): \(message)"
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
        configuration.timeoutIntervalForResource = Constants.API.timeoutInterval * 2
        
        // 启用等待连接功能 - 当网络暂时不可用时，等待连接恢复而不是立即失败
        // 这有助于处理网络切换、短暂断开等情况
        configuration.waitsForConnectivity = true
        
        // 允许使用蜂窝网络
        configuration.allowsCellularAccess = true
        
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
            .mapError { error -> APIError in
                // 改进网络错误处理，特别是socket连接错误
                let nsError = error as NSError
                let errorDescription = error.localizedDescription
                let endpoint = request.url?.path ?? "unknown"
                
                // 检查是否是socket连接错误
                if errorDescription.contains("Socket is not connected") || 
                   errorDescription.contains("nw_flow_add_write_request") ||
                   errorDescription.contains("nw_write_request_report") {
                    Logger.warning("网络连接错误 (\(endpoint)): \(errorDescription)", category: .network)
                    Logger.debug("错误详情: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)", category: .network)
                    
                    // 检查网络连接状态
                    if !Reachability.shared.isConnected {
                        Logger.warning("设备当前无网络连接", category: .network)
                    }
                } else {
                    Logger.error("请求失败 (\(endpoint)): \(errorDescription)", category: .api)
                }
                
                return APIError.requestFailed(error)
            }
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
                                            // 如果解析出的错误状态码为0（FastAPI detail格式），使用实际HTTP状态码
                                            if case .serverError(0, let message) = parsedError {
                                                apiError = .serverError(httpResponse.statusCode, message)
                                            } else {
                                                apiError = parsedError
                                            }
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
                        // 如果解析出的错误状态码为0（FastAPI detail格式），使用实际HTTP状态码
                        if case .serverError(0, let message) = parsedError {
                            apiError = .serverError(httpResponse.statusCode, message)
                        } else {
                            apiError = parsedError
                        }
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
        
        return performRequest(request: request, type: type, startTime: startTime)
    }
    
    /// 发送数组作为请求体的请求方法（用于批量API）
    public func requestWithArrayBody<T: Decodable>(_ type: T.Type, _ endpoint: String, method: String = "POST", body: [Any]? = nil, headers: [String: String]? = nil) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 确保 iOS 应用识别所需的 headers 被设置
        request.setValue("iOS", forHTTPHeaderField: "X-Platform")
        request.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // 注入 Session ID
        let isPublicEndpoint = APIEndpoints.publicEndpoints.contains { endpoint.contains($0) }
        
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
            AppSignature.signRequest(&request, sessionId: sessionId)
        } else if !isPublicEndpoint {
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
        
        let startTime = Date()
        
        return performRequest(request: request, type: type, startTime: startTime)
    }
    
    /// 执行请求的通用方法
    private func performRequest<T: Decodable>(request: URLRequest, type: T.Type, startTime: Date) -> AnyPublisher<T, APIError> {
        return session.dataTaskPublisher(for: request)
            .mapError { error -> APIError in
                // 改进网络错误处理，特别是socket连接错误
                let nsError = error as NSError
                let errorDescription = error.localizedDescription
                let endpoint = request.url?.path ?? "unknown"
                
                // 检查是否是socket连接错误
                if errorDescription.contains("Socket is not connected") || 
                   errorDescription.contains("nw_flow_add_write_request") ||
                   errorDescription.contains("nw_write_request_report") {
                    Logger.warning("网络连接错误 (\(endpoint)): \(errorDescription)", category: .network)
                    Logger.debug("错误详情: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)", category: .network)
                    
                    // 检查网络连接状态
                    if !Reachability.shared.isConnected {
                        Logger.warning("设备当前无网络连接", category: .network)
                    }
                } else {
                    Logger.error("请求失败 (\(endpoint)): \(errorDescription)", category: .api)
                }
                
                return APIError.requestFailed(error)
            }
            .flatMap { data, response -> AnyPublisher<T, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    // 记录性能指标（错误情况）
                    let duration = Date().timeIntervalSince(startTime)
                    PerformanceMonitor.shared.recordNetworkRequest(
                        endpoint: request.url?.path ?? "",
                        method: request.httpMethod ?? "GET",
                        duration: duration,
                        statusCode: nil,
                        error: APIError.invalidResponse
                    )
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                let endpoint = request.url?.path ?? ""
                let method = request.httpMethod ?? "GET"
                
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
                    
                    let endpoint = request.url?.path ?? ""
                    let method = request.httpMethod ?? "GET"
                    
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<T, APIError> in
                            // 重新构建请求（确保所有 header 和 body 都正确设置）
                            guard let retryURL = request.url else {
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
                    // 非 2xx、非 401：尝试解析响应体中的 detail，便于展示「您已经申请过此任务」等后端提示
                    let apiError: APIError
                    if let (parsedError, errorMessage) = APIError.parse(from: data) {
                        if case .serverError(0, _) = parsedError {
                            apiError = .serverError(httpResponse.statusCode, errorMessage)
                        } else {
                            apiError = parsedError
                        }
                    } else {
                        apiError = .httpError(httpResponse.statusCode)
                    }
                    return Fail(error: apiError).eraseToAnyPublisher()
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
        
        // ⚠️ 关键：设置 iOS 应用识别 headers（用于后端识别 iOS 应用，使用宽松的 IP 验证策略）
        refreshRequest.setValue("iOS", forHTTPHeaderField: "X-Platform")
        refreshRequest.setValue("Link2Ur-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // 发送当前的 session_id（后端会验证并刷新）
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            refreshRequest.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }
        
        // 如果存在 refresh_token，也发送它（作为备用，当 session 无效时使用）
        if let refreshToken = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey), !refreshToken.isEmpty {
            refreshRequest.setValue(refreshToken, forHTTPHeaderField: "X-Refresh-Token")
            Logger.debug("🔄 已附加 Refresh Token 到刷新请求", category: .api)
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
                        
                        // 保存新的 refresh_token（如果存在）
                        if let refreshToken = refreshResponse.refreshToken, !refreshToken.isEmpty {
                            KeychainHelper.shared.save(refreshToken, service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
                            Logger.success("✅ Refresh Token 已更新", category: .api)
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
    /// 上传公开图片（任务图片、头像等，所有人可访问）
    func uploadPublicImage(_ data: Data, filename: String = "image.jpg", category: String = "public", resourceId: String? = nil) -> AnyPublisher<String, APIError> {
        var urlString = "\(baseURL)\(APIEndpoints.Common.uploadPublicImage)?category=\(category)"
        if let resourceId = resourceId {
            urlString += "&resource_id=\(resourceId)"
        }
        guard let url = URL(string: urlString) else {
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
        
        // 构建multipart body（安全编码）：顺序为 头 → 空行 → 文件内容 → 结束边界
        var body = Data()
        guard body.appendIfUTF8("--\(boundary)\r\n"),
              body.appendIfUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n"),
              body.appendIfUTF8("Content-Type: image/jpeg\r\n\r\n") else {
            return Fail(error: APIError.requestFailed(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Multipart encoding failed"]))).eraseToAnyPublisher()
        }
        body.append(data)
        _ = body.appendIfUTF8("\r\n--\(boundary)--\r\n")
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
                            return self.uploadPublicImage(data, filename: filename, category: category, resourceId: resourceId)
                        }
                        .eraseToAnyPublisher()
                } else {
                    // 尝试解析后端标准错误响应
                    let apiError: APIError
                    if let (parsedError, errorMessage) = APIError.parse(from: data) {
                        Logger.error("上传公开图片API错误: \(errorMessage) (code: \(httpResponse.statusCode))", category: .api)
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
    
    /// 上传私密图片（任务聊天、客服聊天，需要token验证，返回Publisher）
    func uploadImage(_ data: Data, filename: String = "image.jpg", taskId: Int? = nil) -> AnyPublisher<String, APIError> {
        var urlString = "\(baseURL)\(APIEndpoints.Common.uploadImage)"
        if let taskId = taskId {
            urlString += "?task_id=\(taskId)"
        }
        guard let url = URL(string: urlString) else {
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
        
        // 构建multipart body（安全编码）：顺序为 头 → 空行 → 文件内容 → 结束边界
        var body = Data()
        guard body.appendIfUTF8("--\(boundary)\r\n"),
              body.appendIfUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n"),
              body.appendIfUTF8("Content-Type: image/jpeg\r\n\r\n") else {
            return Fail(error: APIError.requestFailed(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Multipart encoding failed"]))).eraseToAnyPublisher()
        }
        body.append(data)
        _ = body.appendIfUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        
        return session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<String, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // 解析JSON响应: {"success": true, "url": "..."} 或 {"success": true, "image_id": "..."}
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let url = json["url"] as? String, !url.isEmpty {
                        Logger.debug("上传私密图片成功，获得 url: \(url.prefix(80))...", category: .api)
                        return Just(url).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else if let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                              urlString.hasPrefix("http") {
                        return Just(urlString).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } else {
                        let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(400)) } ?? ""
                        Logger.error("上传私密图片：无法解析 url。响应片段: \(snippet)", category: .api)
                        return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析上传响应，缺少 url"]))).eraseToAnyPublisher()
                    }
                } else if httpResponse.statusCode == 401 {
                    // Token过期，尝试刷新
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<String, APIError> in
                            // 重试上传
                            return self.uploadImage(data, filename: filename, taskId: taskId)
                        }
                        .eraseToAnyPublisher()
                } else {
                    // 尝试解析后端标准错误响应
                    let apiError: APIError
                    if let (parsedError, errorMessage) = APIError.parse(from: data) {
                        Logger.error("上传私密图片API错误: \(errorMessage) (code: \(httpResponse.statusCode))", category: .api)
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
    
    /// 上传图片的便捷方法 (支持 UIImage 和 path，使用 completion handler)
    func uploadImage(_ image: UIImage, path: String, taskId: Int? = nil, completion: @escaping (Result<String, APIError>) -> Void) {
        // 压缩图片，质量0.7（避免重复压缩）
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(APIError.decodingError(NSError(domain: "ImageError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法转换图片数据"]))))
            return
        }
        
        // 生成文件名
        let filename = "\(path)_\(Int(Date().timeIntervalSince1970)).jpg"
        
        // 如果有 taskId，添加到 URL 查询参数
        var uploadURL = "\(baseURL)\(APIEndpoints.Common.uploadImage)"
        if let taskId = taskId {
            uploadURL += "?task_id=\(taskId)"
        }
        
        guard let url = URL(string: uploadURL) else {
            completion(.failure(APIError.invalidURL))
            return
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
        
        // 构建multipart body（安全编码）：顺序为 头 → 空行 → 文件内容 → 结束边界
        var body = Data()
        guard body.appendIfUTF8("--\(boundary)\r\n"),
              body.appendIfUTF8("Content-Disposition: form-data; name=\"image\"; filename=\"\(filename)\"\r\n"),
              body.appendIfUTF8("Content-Type: image/jpeg\r\n\r\n") else {
            completion(.failure(APIError.requestFailed(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Multipart encoding failed"]))))
            return
        }
        body.append(data)
        _ = body.appendIfUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        
        session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<String, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // 解析响应
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // 优先从 JSON 中获取 URL
                        if let url = json["url"] as? String, !url.isEmpty {
                            return Just(url).setFailureType(to: APIError.self).eraseToAnyPublisher()
                        } else if json["image_id"] != nil {
                            // 如果没有 URL 但有 image_id，说明后端没有生成 URL
                            // 这种情况不应该发生，但为了兼容性，返回错误
                            return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "图片上传成功但无法获取访问URL"]))).eraseToAnyPublisher()
                        }
                    }
                    // 尝试直接解析为URL字符串
                    if let urlString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       urlString.hasPrefix("http") {
                        return Just(urlString).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    }
                    return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析上传响应"]))).eraseToAnyPublisher()
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "上传失败"
                    return Fail(error: APIError.serverError(httpResponse.statusCode, errorMessage)).eraseToAnyPublisher()
                }
            }
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
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    // 注销设备Token（用于推送通知）
    public func unregisterDeviceToken(_ token: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = [
            "device_token": token
        ]
        
        request(EmptyResponse.self, APIEndpoints.Users.deviceToken, method: "DELETE", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                } else {
                    completion(true)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    // MARK: - 文件上传（用于任务证据等）
    func uploadFile(data: Data, filename: String, taskId: Int? = nil, completion: @escaping (Result<String, APIError>) -> Void) {
        // 如果有 taskId，添加到 URL 查询参数
        var uploadURL = "\(baseURL)\(APIEndpoints.Common.uploadFile)"
        if let taskId = taskId {
            uploadURL += "?task_id=\(taskId)"
        }
        
        guard let url = URL(string: uploadURL) else {
            completion(.failure(APIError.invalidURL))
            return
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
        
        // 检测文件类型
        let contentType: String
        if filename.lowercased().hasSuffix(".jpg") || filename.lowercased().hasSuffix(".jpeg") {
            contentType = "image/jpeg"
        } else if filename.lowercased().hasSuffix(".png") {
            contentType = "image/png"
        } else if filename.lowercased().hasSuffix(".pdf") {
            contentType = "application/pdf"
        } else if filename.lowercased().hasSuffix(".doc") {
            contentType = "application/msword"
        } else if filename.lowercased().hasSuffix(".docx") {
            contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        } else if filename.lowercased().hasSuffix(".txt") {
            contentType = "text/plain"
        } else {
            contentType = "application/octet-stream"
        }
        
        // 构建multipart body（安全编码）：顺序为 头 → 空行 → 文件内容 → 结束边界
        var body = Data()
        guard body.appendIfUTF8("--\(boundary)\r\n"),
              body.appendIfUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"),
              body.appendIfUTF8("Content-Type: \(contentType)\r\n\r\n") else {
            completion(.failure(APIError.requestFailed(NSError(domain: "APIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Multipart encoding failed"]))))
            return
        }
        body.append(data)
        _ = body.appendIfUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        
        session.dataTaskPublisher(for: request)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<String, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    // 解析响应
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // 优先从 JSON 中获取 file_id
                        if let fileId = json["file_id"] as? String, !fileId.isEmpty {
                            return Just(fileId).setFailureType(to: APIError.self).eraseToAnyPublisher()
                        } else if let success = json["success"] as? Bool, success, let fileId = json["file_id"] as? String {
                            return Just(fileId).setFailureType(to: APIError.self).eraseToAnyPublisher()
                        } else {
                            return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "文件上传成功但无法获取文件ID"]))).eraseToAnyPublisher()
                        }
                    }
                    return Fail(error: APIError.decodingError(NSError(domain: "UploadError", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析上传响应"]))).eraseToAnyPublisher()
                } else if httpResponse.statusCode == 401 {
                    return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
                } else {
                    let errorMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String ?? "上传失败"
                    return Fail(error: APIError.serverError(httpResponse.statusCode, errorMessage)).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { fileId in
                    completion(.success(fileId))
                }
            )
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
        
        do {
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
        } catch let error as APIError {
            // 如果是已经转换的 APIError，直接抛出
            throw error
        } catch {
            // 处理网络错误，特别是socket连接错误
            let nsError = error as NSError
            let errorDescription = error.localizedDescription
            
            // 检查是否是socket连接错误
            if errorDescription.contains("Socket is not connected") || 
               errorDescription.contains("nw_flow_add_write_request") ||
               errorDescription.contains("nw_write_request_report") {
                Logger.warning("网络连接错误 (\(endpoint)): \(errorDescription)", category: .network)
                Logger.debug("错误详情: domain=\(nsError.domain), code=\(nsError.code), userInfo=\(nsError.userInfo)", category: .network)
                
                // 检查网络连接状态
                if !Reachability.shared.isConnected {
                    Logger.warning("设备当前无网络连接", category: .network)
                }
            } else {
                Logger.error("Async 请求失败 (\(endpoint)): \(errorDescription)", category: .api)
            }
            
            throw APIError.requestFailed(error)
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

// MARK: - Multipart 安全编码
private extension Data {
    mutating func appendIfUTF8(_ string: String) -> Bool {
        guard let d = string.data(using: .utf8) else { return false }
        append(d)
        return true
    }
}

