import Foundation
#if canImport(XCTest)
import XCTest
#endif
import Combine

/// 测试辅助工具 - 企业级测试支持

#if canImport(XCTest)
// MARK: - Combine 测试辅助

extension XCTestCase {
    
    /// 等待 Publisher 完成并返回结果
    public func awaitPublisher<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Output {
        var result: Result<T.Output, Error>?
        let expectation = expectation(description: "Awaiting publisher")
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    break
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                result = .success(value)
            }
        )
        
        waitForExpectations(timeout: timeout)
        cancellable.cancel()
        
        let unwrappedResult = try XCTUnwrap(
            result,
            "Awaited publisher did not produce any output",
            file: file,
            line: line
        )
        
        return try unwrappedResult.get()
    }
    
    /// 等待 Publisher 完成并返回错误
    public func awaitError<T: Publisher>(
        _ publisher: T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T.Failure {
        var result: Result<T.Output, T.Failure>?
        let expectation = expectation(description: "Awaiting publisher error")
        
        let cancellable = publisher.sink(
            receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    result = .failure(error)
                case .finished:
                    break
                }
                expectation.fulfill()
            },
            receiveValue: { value in
                result = .success(value)
            }
        )
        
        waitForExpectations(timeout: timeout)
        cancellable.cancel()
        
        let unwrappedResult = try XCTUnwrap(
            result,
            "Awaited publisher did not produce any error",
            file: file,
            line: line
        )
        
        switch unwrappedResult {
        case .failure(let error):
            return error
        case .success:
            throw XCTFailure("Expected error but got success", file: file, line: line)
        }
    }
}

// MARK: - 异步测试辅助

extension XCTestCase {
    
    /// 等待异步操作完成
    public func awaitAsync<T>(
        _ operation: @escaping () async throws -> T,
        timeout: TimeInterval = 5.0,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        var result: Result<T, Error>?
        let expectation = expectation(description: "Awaiting async operation")
        
        _Concurrency.Task {
            do {
                let value = try await operation()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: timeout)
        
        let unwrappedResult = try XCTUnwrap(
            result,
            "Async operation did not complete",
            file: file,
            line: line
        )
        
        return try unwrappedResult.get()
    }
}

// MARK: - Mock 数据生成器

public struct MockDataGenerator {
    
    /// 生成随机字符串
    public static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// 生成随机邮箱
    public static func randomEmail() -> String {
        return "\(randomString(length: 8))@\(randomString(length: 5)).com"
    }
    
    /// 生成随机手机号
    public static func randomPhone() -> String {
        return "+44\(Int.random(in: 1000000000...9999999999))"
    }
    
    /// 生成随机整数
    public static func randomInt(min: Int = 0, max: Int = 100) -> Int {
        return Int.random(in: min...max)
    }
    
    /// 生成随机双精度数
    public static func randomDouble(min: Double = 0.0, max: Double = 100.0) -> Double {
        return Double.random(in: min...max)
    }
    
    /// 生成随机日期
    public static func randomDate(
        from startDate: Date = Date().addingTimeInterval(-365 * 24 * 3600),
        to endDate: Date = Date()
    ) -> Date {
        let timeInterval = TimeInterval.random(in: startDate.timeIntervalSince1970...endDate.timeIntervalSince1970)
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    /// 生成随机布尔值
    public static func randomBool() -> Bool {
        return Bool.random()
    }
}

// MARK: - 测试辅助错误

struct XCTFailure: Error {
    let message: String
    let file: StaticString
    let line: UInt
    
    init(_ message: String, file: StaticString = #file, line: UInt = #line) {
        self.message = message
        self.file = file
        self.line = line
    }
}

#endif

// MARK: - Mock 数据生成器（可在非测试环境中使用）

public struct MockDataGenerator {
    
    /// 生成随机字符串
    public static func randomString(length: Int = 10) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in letters.randomElement()! })
    }
    
    /// 生成随机邮箱
    public static func randomEmail() -> String {
        return "\(randomString(length: 8))@\(randomString(length: 5)).com"
    }
    
    /// 生成随机手机号
    public static func randomPhone() -> String {
        return "+44\(Int.random(in: 1000000000...9999999999))"
    }
    
    /// 生成随机整数
    public static func randomInt(min: Int = 0, max: Int = 100) -> Int {
        return Int.random(in: min...max)
    }
    
    /// 生成随机双精度数
    public static func randomDouble(min: Double = 0.0, max: Double = 100.0) -> Double {
        return Double.random(in: min...max)
    }
    
    /// 生成随机日期
    public static func randomDate(
        from startDate: Date = Date().addingTimeInterval(-365 * 24 * 3600),
        to endDate: Date = Date()
    ) -> Date {
        let timeInterval = TimeInterval.random(in: startDate.timeIntervalSince1970...endDate.timeIntervalSince1970)
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    /// 生成随机布尔值
    public static func randomBool() -> Bool {
        return Bool.random()
    }
}

