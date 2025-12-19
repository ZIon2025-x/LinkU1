import Foundation
import Combine

/// Mock API 服务 - 用于测试
public class MockAPIService: APIServiceProtocol {
    
    public var responses: [String: Any] = [:]
    public var errors: [String: Error] = [:]
    public var delays: [String: TimeInterval] = [:]
    
    public init() {}
    
    /// 设置响应
    public func setResponse<T>(_ response: T, for endpoint: String) {
        responses[endpoint] = response
    }
    
    /// 设置错误
    public func setError(_ error: Error, for endpoint: String) {
        errors[endpoint] = error
    }
    
    /// 设置延迟
    public func setDelay(_ delay: TimeInterval, for endpoint: String) {
        delays[endpoint] = delay
    }
    
    /// 清除所有模拟数据
    public func clear() {
        responses.removeAll()
        errors.removeAll()
        delays.removeAll()
    }
    
    // MARK: - APIServiceProtocol
    
    public func request<T: Decodable>(
        _ type: T.Type,
        _ endpoint: String,
        method: String,
        body: [String: Any]?,
        headers: [String: String]?
    ) -> AnyPublisher<T, APIError> {
        let key = "\(method) \(endpoint)"
        
        // 检查是否有错误
        if let error = errors[key] {
            return Fail(error: error as? APIError ?? APIError.unknown)
                .eraseToAnyPublisher()
        }
        
        // 检查是否有响应
        guard let response = responses[key] as? T else {
            return Fail(error: APIError.unknown)
                .eraseToAnyPublisher()
        }
        
        // 检查是否有延迟
        let delay = delays[key] ?? 0
        
        if delay > 0 {
            return Just(response)
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        } else {
            return Just(response)
                .setFailureType(to: APIError.self)
                .eraseToAnyPublisher()
        }
    }
}

