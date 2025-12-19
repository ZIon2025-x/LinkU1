import Foundation
import Combine

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case unauthorized
    case unknown
    
    var errorDescription: String? {
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
        self.session = URLSession(configuration: configuration)
    }
    
    func request<T: Decodable>(_ type: T.Type, _ endpoint: String, method: String = "GET", body: [String: Any]? = nil, headers: [String: String]? = nil) -> AnyPublisher<T, APIError> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 注入 Token
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
                    // Token刷新策略
                    return self.handle401Error()
                        .flatMap { () -> AnyPublisher<T, APIError> in
                            // 重试原请求（使用新的Token）
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
                                        return Fail(error: APIError.httpError(httpResponse.statusCode)).eraseToAnyPublisher()
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
    
    // Token刷新处理
    private func handle401Error() -> AnyPublisher<Void, APIError> {
        // 检查是否有refreshToken
        guard let refreshToken = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey), !refreshToken.isEmpty else {
            // 没有refreshToken，清除Token并登出
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .userDidLogout, object: nil)
            }
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
        
        let refreshBody = ["refresh_token": refreshToken]
        guard let refreshURL = URL(string: "\(baseURL)/api/secure-auth/refresh") else {
            isRefreshing = false
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var refreshRequest = URLRequest(url: refreshURL)
        refreshRequest.httpMethod = "POST"
        refreshRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            refreshRequest.httpBody = try JSONSerialization.data(withJSONObject: refreshBody)
        } catch {
            isRefreshing = false
            return Fail(error: APIError.requestFailed(error)).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: refreshRequest)
            .mapError { APIError.requestFailed($0) }
            .flatMap { data, response -> AnyPublisher<Void, APIError> in
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.isRefreshing = false
                    self.notifyRefreshQueue()
                    return Fail(error: APIError.invalidResponse).eraseToAnyPublisher()
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    do {
                        let refreshResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                        // 保存新Token
                        KeychainHelper.shared.save(refreshResponse.accessToken, service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                        if let newRefreshToken = refreshResponse.refreshToken {
                            KeychainHelper.shared.save(newRefreshToken, service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
                        }
                        
                        // 更新请求的Authorization header
                        // 注意：这里无法直接修改originalRequest，需要在重试时重新设置
                        self.isRefreshing = false
                        self.notifyRefreshQueue()
                        return Just(()).setFailureType(to: APIError.self).eraseToAnyPublisher()
                    } catch {
                        self.isRefreshing = false
                        self.notifyRefreshQueue()
                        return Fail(error: APIError.decodingError(error)).eraseToAnyPublisher()
                    }
                } else {
                    // 刷新失败，清除Token并登出
                    KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
                    KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .userDidLogout, object: nil)
                    }
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
        guard let url = URL(string: "\(baseURL)/api/upload/image") else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 设置multipart/form-data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // 注入Token
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
                    return Fail(error: APIError.httpError(httpResponse.statusCode)).eraseToAnyPublisher()
                }
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // 注册设备Token（用于推送通知）
    public func registerDeviceToken(_ token: String, completion: @escaping (Bool) -> Void) {
        // 注意：如果后端没有专门的设备token注册API，可以暂时跳过
        // 或者使用通用的用户设置API
        // 这里提供一个基础实现，实际使用时需要根据后端API调整
        
        let body: [String: Any] = [
            "device_token": token,
            "platform": "ios"
        ]
        
        // 假设后端有 /api/users/device-token 或类似的端点
        // 如果没有，可以暂时注释掉或使用其他端点
        request(EmptyResponse.self, "/api/users/device-token", method: "POST", body: body)
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

// 辅助空响应结构体
struct EmptyResponse: Decodable {}

