//
//  MemoryMonitorTests.swift
//  link2urTests
//
//  内存监控单元测试
//

import XCTest
@testable import link2ur

final class MemoryMonitorTests: XCTestCase {
    
    var sut: MemoryMonitor!
    
    override func setUp() {
        super.setUp()
        sut = MemoryMonitor.shared
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - 内存压力级别测试
    
    func testMemoryPressureLevel_Comparison() {
        XCTAssertTrue(MemoryPressureLevel.normal < MemoryPressureLevel.warning)
        XCTAssertTrue(MemoryPressureLevel.warning < MemoryPressureLevel.critical)
        XCTAssertTrue(MemoryPressureLevel.critical < MemoryPressureLevel.emergency)
    }
    
    func testMemoryPressureLevel_Description() {
        XCTAssertEqual(MemoryPressureLevel.normal.description, "正常")
        XCTAssertEqual(MemoryPressureLevel.warning.description, "警告")
        XCTAssertEqual(MemoryPressureLevel.critical.description, "危险")
        XCTAssertEqual(MemoryPressureLevel.emergency.description, "紧急")
    }
    
    // MARK: - 内存监控测试
    
    func testMemoryMonitor_CurrentUsage() {
        // 内存使用量应该大于 0
        XCTAssertGreaterThan(sut.currentMemoryUsage, 0)
    }
    
    func testMemoryMonitor_DeviceTotalMemory() {
        // 设备总内存应该大于 0
        XCTAssertGreaterThan(sut.deviceTotalMemory, 0)
    }
    
    func testMemoryMonitor_MemoryInfo() {
        let info = sut.memoryInfo
        
        XCTAssertNotNil(info["current"])
        XCTAssertNotNil(info["peak"])
        XCTAssertNotNil(info["total"])
        XCTAssertNotNil(info["pressure"])
    }
    
    // MARK: - 内存快照测试
    
    func testMemorySnapshot_Creation() {
        let snapshot = sut.takeSnapshot(context: "test")
        
        XCTAssertGreaterThan(snapshot.usedMemory, 0)
        XCTAssertGreaterThan(snapshot.totalMemory, 0)
        XCTAssertEqual(snapshot.context, "test")
    }
    
    func testMemorySnapshot_UsagePercentage() {
        let snapshot = sut.takeSnapshot()
        
        XCTAssertGreaterThan(snapshot.usagePercentage, 0)
        XCTAssertLessThanOrEqual(snapshot.usagePercentage, 100)
    }
    
    // MARK: - 内存历史测试
    
    func testMemoryMonitor_History() {
        // 创建一些快照
        _ = sut.takeSnapshot(context: "test1")
        _ = sut.takeSnapshot(context: "test2")
        _ = sut.takeSnapshot(context: "test3")
        
        let history = sut.getMemoryHistory()
        
        XCTAssertGreaterThanOrEqual(history.count, 3)
    }
    
    // MARK: - 泄漏检测测试
    
    func testMemoryMonitor_LeakDetection() {
        let baseline = sut.takeSnapshot(context: "baseline")
        
        // 模拟内存增长
        // 在实际测试中，这里可能需要分配一些内存
        
        let current = sut.takeSnapshot(context: "current")
        
        // 使用较大的阈值，因为我们没有实际分配大量内存
        let hasLeak = sut.detectLeak(baseline: baseline, current: current, threshold: 100 * 1024 * 1024)
        
        // 在正常情况下不应该检测到泄漏
        XCTAssertFalse(hasLeak)
    }
}

// MARK: - ANR 检测器测试

final class ANRDetectorTests: XCTestCase {
    
    var sut: ANRDetector!
    
    override func setUp() {
        super.setUp()
        sut = ANRDetector.shared
    }
    
    override func tearDown() {
        sut.stop()
        super.tearDown()
    }
    
    func testANRDetector_Configuration() {
        XCTAssertEqual(sut.watchdogInterval, 2.0)
        XCTAssertEqual(sut.threshold, 5.0)
    }
    
    func testANRDetector_StartStop() {
        sut.start()
        // 给一些时间让线程启动
        Thread.sleep(forTimeInterval: 0.5)
        
        sut.stop()
        // 应该能够安全停止
    }
}
