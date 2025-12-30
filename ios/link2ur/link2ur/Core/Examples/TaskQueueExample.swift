import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 任务队列使用示例
class TaskQueueExample {
    
    /// 示例1: 基本任务队列
    func basicTaskQueue() {
        // 添加高优先级任务
        TaskQueue.shared.enqueue({ [self] in
            try await self.uploadCriticalData()
        }, priority: .high)
        
        // 添加普通任务
        TaskQueue.shared.enqueue({ [self] in
            try await self.syncData()
        }, priority: .normal)
        
        // 添加低优先级任务
        TaskQueue.shared.enqueue({ [self] in
            try await self.cleanupCache()
        }, priority: .low)
    }
    
    /// 示例2: 图片上传队列
    func imageUploadQueue() {
        let images = [UIImage(), UIImage(), UIImage()]
        
        for (index, image) in images.enumerated() {
            TaskQueue.shared.enqueue({
                try await self.uploadImage(image, index: index)
            }, priority: .normal)
        }
    }
    
    /// 示例3: 批量数据处理
    func batchProcessing() {
        let items = Array(0..<100)
        
        // 将任务分批添加到队列
        for chunk in items.chunked(into: 10) {
            TaskQueue.shared.enqueue({ [self] in
                try await self.processBatch(chunk)
            }, priority: .normal)
        }
    }
    
    /// 示例4: 使用 Semaphore 控制并发
    func controlledConcurrency() {
        let semaphore = Semaphore(value: 3) // 最多3个并发
        
        for i in 0..<10 {
            TaskQueue.shared.enqueue({ [self] in
                try await semaphore.executeAsync {
                    try await self.processItem(i)
                }
            }, priority: .normal)
        }
    }
    
    // MARK: - 辅助方法
    
    private func uploadCriticalData() async throws {
        // 上传关键数据
        await sleep(seconds: 1.0)
    }
    
    private func syncData() async throws {
        // 同步数据
        await sleep(seconds: 0.5)
    }
    
    private func cleanupCache() async throws {
        // 清理缓存
        await sleep(seconds: 0.2)
    }
    
    private func uploadImage(_ image: UIImage, index: Int) async throws {
        // 上传图片
        print("上传图片 \(index)")
        await sleep(seconds: 1.0)
    }
    
    private func processBatch(_ items: [Int]) async throws {
        // 处理批次
        print("处理批次: \(items.count) 项")
        await sleep(seconds: 0.5)
    }
    
    private func processItem(_ item: Int) async throws {
        // 处理单个项目
        print("处理项目: \(item)")
        await sleep(seconds: 0.2)
    }
    
    // 兼容 Swift 5 的 sleep 函数
    private func sleep(seconds: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
}

