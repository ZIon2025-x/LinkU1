import Foundation

/// 网络拦截器 - 企业级网络请求拦截
public class NetworkInterceptor {
    public static let shared = NetworkInterceptor()
    
    public typealias RequestInterceptor = (URLRequest) -> URLRequest?
    public typealias ResponseInterceptor = (URLResponse, Data?) -> (URLResponse, Data?)?
    
    private var requestInterceptors: [RequestInterceptor] = []
    private var responseInterceptors: [ResponseInterceptor] = []
    private let lock = NSLock()
    
    private init() {}
    
    /// 添加请求拦截器
    public func addRequestInterceptor(_ interceptor: @escaping RequestInterceptor) {
        lock.lock()
        defer { lock.unlock() }
        requestInterceptors.append(interceptor)
    }
    
    /// 添加响应拦截器
    public func addResponseInterceptor(_ interceptor: @escaping ResponseInterceptor) {
        lock.lock()
        defer { lock.unlock() }
        responseInterceptors.append(interceptor)
    }
    
    /// 拦截请求
    public func interceptRequest(_ request: URLRequest) -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        
        var currentRequest = request
        for interceptor in requestInterceptors {
            guard let modified = interceptor(currentRequest) else {
                return nil // 拦截器拒绝请求
            }
            currentRequest = modified
        }
        return currentRequest
    }
    
    /// 拦截响应
    public func interceptResponse(_ response: URLResponse, data: Data?) -> (URLResponse, Data?)? {
        lock.lock()
        defer { lock.unlock() }
        
        var currentResponse = response
        var currentData = data
        for interceptor in responseInterceptors {
            guard let result = interceptor(currentResponse, currentData) else {
                return nil // 拦截器拒绝响应
            }
            currentResponse = result.0
            currentData = result.1
        }
        return (currentResponse, currentData)
    }
    
    /// 清除所有拦截器
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        requestInterceptors.removeAll()
        responseInterceptors.removeAll()
    }
}

