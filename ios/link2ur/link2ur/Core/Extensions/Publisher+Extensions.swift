import Foundation
import Combine

/// Publisher 扩展 - 提供企业级操作符
extension Publisher {
    
    /// 带重试的请求，自动处理错误和重试逻辑
    func retryOnFailure(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        retryCondition: @escaping (Failure) -> Bool = { _ in true }
    ) -> AnyPublisher<Output, Failure> {
        return self.catch { error -> AnyPublisher<Output, Failure> in
            guard maxAttempts > 1, retryCondition(error) else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            
            return Just(())
                .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                .flatMap { _ in
                    self.retryOnFailure(
                        maxAttempts: maxAttempts - 1,
                        delay: delay * 1.5, // 指数退避
                        retryCondition: retryCondition
                    )
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// 带超时的请求
    func timeout(
        _ interval: TimeInterval,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<Output, Error> {
        return self.mapError { $0 as Error }
            .timeout(
                .seconds(interval),
                scheduler: scheduler,
                options: nil,
                customError: { TimeoutError() }
            )
            .eraseToAnyPublisher()
    }
    
    /// 带加载状态的请求
    func withLoadingState<T: ObservableObject>(
        _ loadingState: T,
        isLoadingKeyPath: ReferenceWritableKeyPath<T, Bool>
    ) -> AnyPublisher<Output, Failure> {
        return self
            .handleEvents(
                receiveSubscription: { _ in
                    loadingState[keyPath: isLoadingKeyPath] = true
                },
                receiveCompletion: { _ in
                    loadingState[keyPath: isLoadingKeyPath] = false
                },
                receiveCancel: {
                    loadingState[keyPath: isLoadingKeyPath] = false
                }
            )
            .eraseToAnyPublisher()
    }
    
    /// 带错误处理的请求
    func handleError(
        _ handler: @escaping (Failure) -> Void
    ) -> AnyPublisher<Output, Failure> {
        return self.handleEvents(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    handler(error)
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    /// 在主线程接收
    func receiveOnMain() -> AnyPublisher<Output, Failure> {
        return self.receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// 去抖动（防抖）
    func debounce(
        for interval: TimeInterval,
        scheduler: DispatchQueue = .main
    ) -> AnyPublisher<Output, Failure> {
        return self.debounce(
            for: .seconds(interval),
            scheduler: scheduler
        )
        .eraseToAnyPublisher()
    }
    
    /// 节流（限流）
    func throttle(
        for interval: TimeInterval,
        scheduler: DispatchQueue = .main,
        latest: Bool = true
    ) -> AnyPublisher<Output, Failure> {
        return self.throttle(
            for: .seconds(interval),
            scheduler: scheduler,
            latest: latest
        )
        .eraseToAnyPublisher()
    }
    
    /// 将 Publisher 转换为 async/await
    func async() async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

// MARK: - 错误类型

struct TimeoutError: Error, LocalizedError {
    var errorDescription: String? {
        return "请求超时"
    }
}

// MARK: - Result 扩展

extension Result {
    /// 转换为 Publisher
    func publisher() -> AnyPublisher<Success, Failure> {
        switch self {
        case .success(let value):
            return Just(value)
                .setFailureType(to: Failure.self)
                .eraseToAnyPublisher()
        case .failure(let error):
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
    }
}

