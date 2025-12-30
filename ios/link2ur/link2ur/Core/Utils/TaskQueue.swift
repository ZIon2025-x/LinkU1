import Foundation

/// 任务队列 - 企业级任务管理
public class TaskQueue {
    public static let shared = TaskQueue()
    
    private let queue = DispatchQueue(label: "com.link2ur.taskqueue", attributes: .concurrent)
    private var tasks: [QueuedTask] = []
    private var isProcessing = false
    private let lock = NSLock()
    
    private init() {}
    
    /// 添加任务
    public func enqueue(_ task: @escaping () async throws -> Void, priority: TaskPriority = .normal) {
        lock.lock()
        defer { lock.unlock() }
        
        let queuedTask = QueuedTask(
            id: UUID().uuidString,
            task: task,
            priority: priority,
            createdAt: Date()
        )
        
        tasks.append(queuedTask)
        tasks.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        processNext()
    }
    
    /// 处理下一个任务
    private func processNext() {
        guard !isProcessing else { return }
        
        lock.lock()
        guard !tasks.isEmpty else {
            lock.unlock()
            return
        }
        
        isProcessing = true
        let task = tasks.removeFirst()
        lock.unlock()
        
        // 执行异步任务
        // 注意：由于项目中存在 Task 模型，需要使用 _Concurrency.Task 来明确指定 Swift 并发框架的 Task
        _Concurrency.Task {
            do {
                try await task.task()
            } catch {
                Logger.error("任务执行失败: \(error)", category: .general)
            }
            
            // 使用同步队列来更新状态，避免在异步上下文中直接使用 NSLock
            queue.async {
                self.lock.lock()
                self.isProcessing = false
                self.lock.unlock()
                
                // 处理下一个任务
                self.processNext()
            }
        }
    }
    
    /// 清除所有任务
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        tasks.removeAll()
    }
    
    /// 获取队列长度
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return tasks.count
    }
}

/// 队列任务
private struct QueuedTask {
    let id: String
    let task: () async throws -> Void
    let priority: TaskPriority
    let createdAt: Date
}

/// 任务优先级
public enum TaskPriority: Int {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

