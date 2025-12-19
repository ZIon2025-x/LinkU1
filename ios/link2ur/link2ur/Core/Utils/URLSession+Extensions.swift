import Foundation
import Combine

/// URLSession 扩展 - 企业级网络会话
extension URLSession {
    
    /// 执行请求并返回 Publisher（带自定义响应类型）
    public func dataTaskPublisherWithCustomResponse(
        for request: URLRequest
    ) -> AnyPublisher<(data: Data, response: URLHTTPResponse), URLError> {
        // 使用 Foundation 的标准方法，避免递归
        return Foundation.URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                return (data: data, response: URLHTTPResponse(httpResponse))
            }
            .mapError { error in
                if let urlError = error as? URLError {
                    return urlError
                }
                return URLError(.unknown)
            }
            .eraseToAnyPublisher()
    }
}

/// HTTP 响应包装器
public struct URLHTTPResponse {
    public let statusCode: Int
    public let headers: [String: String]
    public let url: URL?
    
    init(_ httpResponse: HTTPURLResponse) {
        self.statusCode = httpResponse.statusCode
        self.url = httpResponse.url
        
        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let keyString = key as? String,
               let valueString = value as? String {
                headers[keyString] = valueString
            }
        }
        self.headers = headers
    }
}

