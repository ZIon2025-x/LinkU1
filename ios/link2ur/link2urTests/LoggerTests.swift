//
//  LoggerTests.swift
//  link2urTests
//
//  企业级日志系统单元测试
//

import XCTest
@testable import link2ur

final class LoggerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 确保日志系统处于默认状态
        Logger.shared.minimumLevel = .verbose
        Logger.shared.persistenceEnabled = true
    }
    
    override func tearDown() {
        // 清理测试日志
        Logger.clearAllLogs()
        super.tearDown()
    }
    
    // MARK: - 日志级别测试
    
    func testLogLevel_Comparison() {
        XCTAssertTrue(LogLevel.verbose < LogLevel.debug)
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
    }
    
    func testLogLevel_Labels() {
        XCTAssertEqual(LogLevel.verbose.label, "VERBOSE")
        XCTAssertEqual(LogLevel.debug.label, "DEBUG")
        XCTAssertEqual(LogLevel.info.label, "INFO")
        XCTAssertEqual(LogLevel.warning.label, "WARNING")
        XCTAssertEqual(LogLevel.error.label, "ERROR")
        XCTAssertEqual(LogLevel.critical.label, "CRITICAL")
    }
    
    // MARK: - 日志记录测试
    
    func testLogger_Debug() {
        // 确保 debug 级别的日志被记录
        Logger.debug("Test debug message", category: .general)
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("Test debug message") })
    }
    
    func testLogger_Info() {
        Logger.info("Test info message", category: .api)
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("Test info message") })
    }
    
    func testLogger_Warning() {
        Logger.warning("Test warning message", category: .network)
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("Test warning message") })
    }
    
    func testLogger_Error() {
        Logger.error("Test error message", category: .auth)
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("Test error message") })
    }
    
    func testLogger_MinimumLevel() {
        // 设置最小级别为 warning
        Logger.shared.minimumLevel = .warning
        
        // 清除之前的日志
        Logger.clearAllLogs()
        
        // 这些不应该被记录
        Logger.debug("Should not appear", category: .general)
        Logger.info("Should not appear either", category: .general)
        
        // 这些应该被记录
        Logger.warning("Warning should appear", category: .general)
        Logger.error("Error should appear", category: .general)
        
        let logs = Logger.getRecentLogs(maxCount: 100)
        
        XCTAssertFalse(logs.contains { $0.contains("Should not appear") })
        XCTAssertTrue(logs.contains { $0.contains("Warning should appear") })
        XCTAssertTrue(logs.contains { $0.contains("Error should appear") })
    }
    
    // MARK: - 性能日志测试
    
    func testLogger_Performance() {
        Logger.performance(operation: "test_operation", duration: 0.5)
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("test_operation") })
        XCTAssertTrue(logs.contains { $0.contains("500.00ms") })
    }
    
    // MARK: - 审计日志测试
    
    func testLogger_Audit() {
        Logger.audit(action: "user_login", userId: "test_user_123", details: ["method": "email"])
        
        let logs = Logger.getRecentLogs(maxCount: 10)
        XCTAssertTrue(logs.contains { $0.contains("AUDIT") })
        XCTAssertTrue(logs.contains { $0.contains("user_login") })
    }
    
    // MARK: - 日志导出测试
    
    func testLogger_Export() {
        Logger.info("Test export message", category: .general)
        
        let exportURL = Logger.exportLogs()
        
        XCTAssertNotNil(exportURL)
        
        if let url = exportURL {
            let content = try? String(contentsOf: url, encoding: .utf8)
            XCTAssertNotNil(content)
            XCTAssertTrue(content?.contains("Test export message") ?? false)
            
            // 清理导出文件
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - 日志条目测试

final class LogEntryTests: XCTestCase {
    
    func testLogEntry_Initialization() {
        let entry = LogEntry(
            level: .info,
            category: .api,
            message: "Test message",
            file: "TestFile.swift",
            function: "testFunction()",
            line: 42
        )
        
        XCTAssertEqual(entry.levelEnum, .info)
        XCTAssertEqual(entry.category, "API")
        XCTAssertEqual(entry.message, "Test message")
        XCTAssertEqual(entry.file, "TestFile.swift")
        XCTAssertEqual(entry.function, "testFunction()")
        XCTAssertEqual(entry.line, 42)
    }
    
    func testLogEntry_FormattedMessage() {
        let entry = LogEntry(
            level: .error,
            category: .network,
            message: "Network error",
            file: "NetworkManager.swift",
            function: "fetchData()",
            line: 100
        )
        
        let formatted = entry.formattedMessage
        
        XCTAssertTrue(formatted.contains("Network"))
        XCTAssertTrue(formatted.contains("ERROR"))
        XCTAssertTrue(formatted.contains("Network error"))
    }
}
