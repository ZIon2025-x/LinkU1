import Foundation

/// 请求构建器 - 企业级请求构建
public class RequestBuilder {
    private var url: URL?
    private var method: String = "GET"
    private var headers: [String: String] = [:]
    private var body: Data?
    private var queryParameters: [String: String] = [:]
    private var timeout: TimeInterval = 30
    
    public init(baseURL: String? = nil, endpoint: String? = nil) {
        if let baseURL = baseURL, let endpoint = endpoint {
            self.url = URL(string: "\(baseURL)\(endpoint)")
        } else if let endpoint = endpoint {
            self.url = URL(string: endpoint)
        }
    }
    
    /// 设置 URL
    @discardableResult
    public func url(_ url: URL) -> Self {
        self.url = url
        return self
    }
    
    /// 设置方法
    @discardableResult
    public func method(_ method: String) -> Self {
        self.method = method
        return self
    }
    
    /// 设置请求头
    @discardableResult
    public func header(_ key: String, value: String) -> Self {
        headers[key] = value
        return self
    }
    
    /// 设置多个请求头
    @discardableResult
    public func headers(_ headers: [String: String]) -> Self {
        self.headers.merge(headers) { _, new in new }
        return self
    }
    
    /// 设置请求体
    @discardableResult
    public func body(_ data: Data) -> Self {
        self.body = data
        return self
    }
    
    /// 设置 JSON 请求体
    @discardableResult
    public func jsonBody<T: Encodable>(_ object: T) throws -> Self {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try encoder.encode(object)
        self.header("Content-Type", value: "application/json")
        return self
    }
    
    /// 设置查询参数
    @discardableResult
    public func query(_ key: String, value: String) -> Self {
        queryParameters[key] = value
        return self
    }
    
    /// 设置多个查询参数
    @discardableResult
    public func queries(_ parameters: [String: String]) -> Self {
        queryParameters.merge(parameters) { _, new in new }
        return self
    }
    
    /// 设置超时
    @discardableResult
    public func timeout(_ timeout: TimeInterval) -> Self {
        self.timeout = timeout
        return self
    }
    
    /// 构建请求
    public func build() throws -> URLRequest {
        guard var finalURL = url else {
            throw RequestBuilderError.missingURL
        }
        
        // 添加查询参数
        if !queryParameters.isEmpty {
            finalURL = finalURL.appendingQueryParameters(queryParameters) ?? finalURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.timeoutInterval = timeout
        
        // 设置请求头
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 设置请求体
        if let body = body {
            request.httpBody = body
        }
        
        return request
    }
}

/// 请求构建器错误
enum RequestBuilderError: LocalizedError {
    case missingURL
    
    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "缺少 URL"
        }
    }
}

