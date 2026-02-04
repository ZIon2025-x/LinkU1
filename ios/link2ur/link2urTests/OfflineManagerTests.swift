//
//  OfflineManagerTests.swift
//  link2urTests
//
//  离线管理器单元测试
//

import XCTest
import Combine
@testable import link2ur

final class OfflineManagerTests: XCTestCase {
    
    var sut: OfflineManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = OfflineManager.shared
        cancellables = Set<AnyCancellable>()
        
        // 清除之前的操作
        sut.clearAllOperations()
    }
    
    override func tearDown() {
        sut.clearAllOperations()
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - 离线操作测试
    
    func testOfflineOperation_Initialization() {
        let operation = OfflineOperation(
            type: .create,
            endpoint: "/api/tasks",
            method: "POST",
            body: nil,
            headers: nil,
            resourceType: "task",
            resourceId: "123"
        )
        
        XCTAssertEqual(operation.type, .create)
        XCTAssertEqual(operation.endpoint, "/api/tasks")
        XCTAssertEqual(operation.method, "POST")
        XCTAssertEqual(operation.status, .pending)
        XCTAssertEqual(operation.retryCount, 0)
        XCTAssertEqual(operation.resourceType, "task")
        XCTAssertEqual(operation.resourceId, "123")
    }
    
    func testOfflineManager_AddOperation() {
        let initialCount = sut.pendingOperations.count
        
        sut.queueOperation(
            type: .create,
            endpoint: "/api/test",
            method: "POST",
            body: ["test": "data"],
            resourceType: "test",
            resourceId: "1"
        )
        
        // 等待异步操作完成
        let expectation = XCTestExpectation(description: "Operation added")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(sut.pendingOperations.count, initialCount + 1)
    }
    
    func testOfflineManager_CancelOperation() {
        // 添加操作
        let operation = OfflineOperation(
            type: .update,
            endpoint: "/api/test",
            method: "PUT",
            resourceType: "test",
            resourceId: "2"
        )
        sut.addOperation(operation)
        
        // 等待添加完成
        Thread.sleep(forTimeInterval: 0.3)
        
        // 取消操作
        sut.cancelOperation(operation.id)
        
        // 等待取消完成
        Thread.sleep(forTimeInterval: 0.3)
        
        // 检查状态
        let cancelledOperation = sut.pendingOperations.first { $0.id == operation.id }
        XCTAssertEqual(cancelledOperation?.status, .cancelled)
    }
    
    func testOfflineManager_ClearAllOperations() {
        // 添加一些操作
        sut.queueOperation(type: .create, endpoint: "/api/test1", method: "POST")
        sut.queueOperation(type: .create, endpoint: "/api/test2", method: "POST")
        
        Thread.sleep(forTimeInterval: 0.3)
        
        // 清除所有
        sut.clearAllOperations()
        
        Thread.sleep(forTimeInterval: 0.3)
        
        XCTAssertEqual(sut.pendingOperations.count, 0)
    }
    
    func testOfflineManager_GetPendingOperations() {
        // 添加多个操作
        sut.queueOperation(type: .create, endpoint: "/api/tasks", method: "POST", resourceType: "task", resourceId: "1")
        sut.queueOperation(type: .update, endpoint: "/api/tasks/1", method: "PUT", resourceType: "task", resourceId: "1")
        sut.queueOperation(type: .create, endpoint: "/api/messages", method: "POST", resourceType: "message", resourceId: "2")
        
        Thread.sleep(forTimeInterval: 0.3)
        
        let taskOperations = sut.getPendingOperations(for: "task", resourceId: "1")
        
        XCTAssertEqual(taskOperations.count, 2)
    }
    
    func testOfflineManager_SyncStatus() {
        let status = sut.getSyncStatus()
        
        XCTAssertNotNil(status["is_offline"])
        XCTAssertNotNil(status["is_syncing"])
        XCTAssertNotNil(status["pending_count"])
        XCTAssertNotNil(status["failed_count"])
    }
}

// MARK: - 离线数据存储测试

final class OfflineDataStoreTests: XCTestCase {
    
    var sut: OfflineDataStore!
    
    override func setUp() {
        super.setUp()
        sut = OfflineDataStore.shared
    }
    
    override func tearDown() {
        sut.remove(key: "test_key")
        super.tearDown()
    }
    
    func testOfflineDataStore_SaveAndLoad() {
        let testData = TestData(id: 1, name: "Test", value: 42.5)
        
        sut.save(testData, key: "test_key")
        
        // 等待异步保存完成
        Thread.sleep(forTimeInterval: 0.3)
        
        let loaded: TestData? = sut.load(TestData.self, key: "test_key")
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, testData.id)
        XCTAssertEqual(loaded?.name, testData.name)
        XCTAssertEqual(loaded?.value, testData.value)
    }
    
    func testOfflineDataStore_LoadNonExistent() {
        let loaded: TestData? = sut.load(TestData.self, key: "non_existent_key")
        
        XCTAssertNil(loaded)
    }
    
    func testOfflineDataStore_Remove() {
        let testData = TestData(id: 1, name: "Test", value: 42.5)
        
        sut.save(testData, key: "test_remove_key")
        Thread.sleep(forTimeInterval: 0.3)
        
        sut.remove(key: "test_remove_key")
        Thread.sleep(forTimeInterval: 0.3)
        
        let loaded: TestData? = sut.load(TestData.self, key: "test_remove_key")
        
        XCTAssertNil(loaded)
    }
    
    func testOfflineDataStore_Exists() {
        let testData = TestData(id: 1, name: "Test", value: 42.5)
        
        XCTAssertFalse(sut.exists(key: "test_exists_key"))
        
        sut.save(testData, key: "test_exists_key")
        Thread.sleep(forTimeInterval: 0.3)
        
        XCTAssertTrue(sut.exists(key: "test_exists_key"))
        
        // 清理
        sut.remove(key: "test_exists_key")
    }
    
    // MARK: - 测试数据类型
    
    struct TestData: Codable, Equatable {
        let id: Int
        let name: String
        let value: Double
    }
}
