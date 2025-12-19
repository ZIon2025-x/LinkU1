import Foundation

/// Array 扩展 - 企业级数组操作工具
extension Array {
    
    // MARK: - 安全访问
    
    /// 安全获取元素（不会越界）
    public subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// 安全获取第一个元素
    public var safeFirst: Element? {
        return isEmpty ? nil : first
    }
    
    /// 安全获取最后一个元素
    public var safeLast: Element? {
        return isEmpty ? nil : last
    }
    
    // MARK: - 分块
    
    /// 将数组分块
    public func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
    
    // MARK: - 去重
    
    /// 根据键去重
    public func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { seen.insert($0[keyPath: keyPath]).inserted }
    }
    
    /// 去重（需要 Equatable）
    public func unique() -> [Element] where Element: Equatable {
        var result: [Element] = []
        for element in self {
            if !result.contains(element) {
                result.append(element)
            }
        }
        return result
    }
    
    // MARK: - 分组
    
    /// 根据键分组
    public func grouped<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [T: [Element]] {
        return Dictionary(grouping: self, by: { $0[keyPath: keyPath] })
    }
    
    // MARK: - 随机
    
    /// 随机打乱数组
    public func shuffled() -> [Element] {
        var result = self
        result.shuffle()
        return result
    }
    
    /// 随机获取元素
    public func randomElement() -> Element? {
        return isEmpty ? nil : self[Int.random(in: 0..<count)]
    }
    
    /// 随机获取多个元素
    public func randomElements(_ count: Int) -> [Element] {
        guard count > 0 && count <= self.count else { return [] }
        return Array(shuffled().prefix(count))
    }
    
    // MARK: - 移除
    
    /// 移除第一个匹配的元素
    @discardableResult
    public mutating func removeFirst(where predicate: (Element) -> Bool) -> Element? {
        guard let index = firstIndex(where: predicate) else { return nil }
        return remove(at: index)
    }
    
    // 注意：removeAll(where:) 已在标准库中提供，无需重复实现
}

/// 数组扩展 - Equatable 元素
extension Array where Element: Equatable {
    
    /// 移除指定元素
    @discardableResult
    public mutating func remove(_ element: Element) -> Element? {
        guard let index = firstIndex(of: element) else { return nil }
        return remove(at: index)
    }
    
    /// 移除所有指定元素
    public mutating func removeAll(_ element: Element) {
        removeAll { $0 == element }
    }
}

