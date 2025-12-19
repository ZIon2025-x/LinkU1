import Foundation

/// 线程安全包装器 - 企业级并发安全工具
@propertyWrapper
public struct ThreadSafe<Value> {
    private var value: Value
    private let lock = NSLock()
    
    public init(wrappedValue: Value) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
    
    /// 线程安全地修改值
    public mutating func mutate(_ mutation: (inout Value) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        mutation(&value)
    }
    
    /// 线程安全地读取值并执行操作
    public func read<T>(_ operation: (Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation(value)
    }
}

/// 线程安全数组
public class ThreadSafeArray<Element> {
    private var array: [Element] = []
    private let queue = DispatchQueue(label: "ThreadSafeArray", attributes: .concurrent)
    
    public init() {}
    
    public var count: Int {
        return queue.sync { array.count }
    }
    
    public var isEmpty: Bool {
        return queue.sync { array.isEmpty }
    }
    
    public func append(_ element: Element) {
        queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }
    
    public func remove(at index: Int) {
        queue.async(flags: .barrier) {
            guard index < self.array.count else { return }
            self.array.remove(at: index)
        }
    }
    
    public func removeAll() {
        queue.async(flags: .barrier) {
            self.array.removeAll()
        }
    }
    
    public subscript(index: Int) -> Element? {
        get {
            return queue.sync { index < array.count ? array[index] : nil }
        }
        set {
            guard let newValue = newValue, index < array.count else { return }
            queue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
    }
    
    public func forEach(_ body: (Element) -> Void) {
        queue.sync {
            array.forEach(body)
        }
    }
    
    public func map<T>(_ transform: (Element) -> T) -> [T] {
        return queue.sync {
            array.map(transform)
        }
    }
    
    public func filter(_ isIncluded: (Element) -> Bool) -> [Element] {
        return queue.sync {
            array.filter(isIncluded)
        }
    }
}

/// 线程安全字典
public class ThreadSafeDictionary<Key: Hashable, Value> {
    private var dictionary: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "ThreadSafeDictionary", attributes: .concurrent)
    
    public init() {}
    
    public var count: Int {
        return queue.sync { dictionary.count }
    }
    
    public var isEmpty: Bool {
        return queue.sync { dictionary.isEmpty }
    }
    
    public var keys: [Key] {
        return queue.sync { Array(dictionary.keys) }
    }
    
    public var values: [Value] {
        return queue.sync { Array(dictionary.values) }
    }
    
    public subscript(key: Key) -> Value? {
        get {
            return queue.sync { dictionary[key] }
        }
        set {
            queue.async(flags: .barrier) {
                self.dictionary[key] = newValue
            }
        }
    }
    
    public func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary.removeValue(forKey: key)
        }
    }
    
    public func removeAll() {
        queue.async(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }
    
    public func forEach(_ body: (Key, Value) -> Void) {
        queue.sync {
            dictionary.forEach(body)
        }
    }
}

