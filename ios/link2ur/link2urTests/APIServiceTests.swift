//
//  APIServiceTests.swift
//  link2urTests
//
//  企业级 API 服务单元测试
//

import XCTest
import Combine
@testable import link2ur

final class APIServiceTests: XCTestCase {
    
    var sut: APIService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = APIService.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - 重试配置测试
    
    func testNetworkRetryConfiguration_Default() {
        let config = NetworkRetryConfiguration.default
        
        XCTAssertEqual(config.maxAttempts, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.backoffMultiplier, 2.0)
        XCTAssertTrue(config.useJitter)
    }
    
    func testNetworkRetryConfiguration_Fast() {
        let config = NetworkRetryConfiguration.fast
        
        XCTAssertEqual(config.maxAttempts, 2)
        XCTAssertEqual(config.baseDelay, 0.5)
    }
    
    func testNetworkRetryConfiguration_Persistent() {
        let config = NetworkRetryConfiguration.persistent
        
        XCTAssertEqual(config.maxAttempts, 5)
        XCTAssertEqual(config.baseDelay, 2.0)
    }
    
    func testNetworkRetryConfiguration_DelayCalculation() {
        let config = NetworkRetryConfiguration(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0,
            useJitter: false,  // 禁用抖动以便精确测试
            retryableStatusCodes: [],
            retryableErrorCodes: []
        )
        
        XCTAssertEqual(config.delay(forAttempt: 1), 1.0)
        XCTAssertEqual(config.delay(forAttempt: 2), 2.0)
        XCTAssertEqual(config.delay(forAttempt: 3), 4.0)
    }
    
    func testNetworkRetryConfiguration_ShouldRetry_StatusCode() {
        let config = NetworkRetryConfiguration.default
        
        XCTAssertTrue(config.shouldRetry(error: APIError.httpError(500)))
        XCTAssertTrue(config.shouldRetry(error: APIError.httpError(502)))
        XCTAssertTrue(config.shouldRetry(error: APIError.httpError(503)))
        XCTAssertFalse(config.shouldRetry(error: APIError.httpError(400)))
        XCTAssertFalse(config.shouldRetry(error: APIError.httpError(404)))
    }
    
    func testNetworkRetryConfiguration_ShouldRetry_NetworkError() {
        let config = NetworkRetryConfiguration.default
        
        // 超时错误
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        XCTAssertTrue(config.shouldRetry(error: timeoutError))
        
        // 无网络连接
        let noConnectionError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        XCTAssertTrue(config.shouldRetry(error: noConnectionError))
        
        // 非网络错误
        let otherError = NSError(domain: "CustomDomain", code: 0, userInfo: nil)
        XCTAssertFalse(config.shouldRetry(error: otherError))
    }
    
    // MARK: - API 缓存测试
    
    func testAPICache_SetAndGet() {
        let cache = APICache.shared
        let testData = TestModel(id: 1, name: "Test")
        
        cache.set(testData, for: "/test/endpoint")
        
        let retrieved: TestModel? = cache.get(TestModel.self, for: "/test/endpoint")
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, testData.id)
        XCTAssertEqual(retrieved?.name, testData.name)
        
        // 清理
        cache.remove(for: "/test/endpoint")
    }
    
    func testAPICache_GetNonExistent() {
        let cache = APICache.shared
        
        let retrieved: TestModel? = cache.get(TestModel.self, for: "/non/existent")
        
        XCTAssertNil(retrieved)
    }
    
    func testAPICache_Remove() {
        let cache = APICache.shared
        let testData = TestModel(id: 1, name: "Test")
        
        cache.set(testData, for: "/test/remove")
        cache.remove(for: "/test/remove")
        
        let retrieved: TestModel? = cache.get(TestModel.self, for: "/test/remove")
        
        XCTAssertNil(retrieved)
    }
    
    func testAPICache_GetTTL() {
        let cache = APICache.shared
        
        // 测试默认规则
        let tasksTTL = cache.getTTL(for: "/api/tasks")
        XCTAssertEqual(tasksTTL, 300) // 5分钟
        
        let bannersTTL = cache.getTTL(for: "/api/banners")
        XCTAssertEqual(bannersTTL, 3600) // 1小时
    }
    
    // MARK: - 辅助类型
    
    struct TestModel: Codable, Equatable {
        let id: Int
        let name: String
    }
}

// MARK: - 网络请求 Mock

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Handler is unavailable.")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    
    override func stopLoading() {}
}
