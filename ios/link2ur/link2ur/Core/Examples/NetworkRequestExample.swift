import Foundation
import Combine

/// 网络请求示例 - 展示如何使用企业级网络工具
class NetworkRequestExample {
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    /// 示例1: 基本网络请求
    func basicRequest() {
        networkManager.execute(
            User.self,
            endpoint: "/api/users/me"
        )
        .handleError { error in
            ErrorHandler.shared.handle(error, context: "加载用户")
        }
        .receiveOnMain()
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    Logger.error("请求失败: \(error)", category: .api)
                }
            },
            receiveValue: { user in
                Logger.success("加载成功: \(user.name)", category: .api)
            }
        )
        .store(in: &cancellables)
    }
    
    /// 示例2: 使用 RequestBuilder
    func requestWithBuilder() {
        do {
            let request = try RequestBuilder(
                baseURL: Constants.API.baseURL,
                endpoint: "/api/users/me"
            )
            .method("GET")
            .header("X-Session-ID", value: "session_id")
            .timeout(30)
            .build()
            
            // 注意：NetworkManager.execute 不接受 request 参数，需要使用 endpoint
            // 如果需要自定义请求，应该使用 requestBuilder 参数
            networkManager.execute(
                User.self,
                endpoint: "/api/users/me"
            )
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { user in
                        print("用户: \(user.name)")
                    }
                )
                .store(in: &cancellables)
        } catch {
            ErrorHandler.shared.handle(error, context: "构建请求")
        }
    }
    
    /// 示例3: 带缓存和重试的请求
    func requestWithCacheAndRetry() {
        networkManager.execute(
            User.self,
            endpoint: "/api/users/me",
            cachePolicy: .networkFirst
        )
        .retryOnFailure(maxAttempts: 3)
        .handleError { error in
            ErrorHandler.shared.handle(error, context: "加载用户")
        }
        .sink(
            receiveCompletion: { _ in },
            receiveValue: { user in
                // 缓存用户数据（User 是 struct，使用 save 方法）
                CacheManager.shared.save(
                    user,
                    forKey: "user_me"
                )
            }
        )
        .store(in: &cancellables)
    }
    
    /// 示例4: 使用 RetryManager
    func requestWithRetryManager() async {
        do {
            let user = try await RetryManager.shared.execute(
                {
                    try await self.loadUserFromAPI()
                },
                maxAttempts: 3,
                delay: 1.0,
                shouldRetry: { error in
                    // 只对网络错误重试
                    if let urlError = error as? URLError {
                        return urlError.code == .timedOut || urlError.code == .networkConnectionLost
                    }
                    return false
                }
            )
            print("用户: \(user.name)")
        } catch {
            ErrorHandler.shared.handle(error, context: "加载用户")
        }
    }
    
    private func loadUserFromAPI() async throws -> User {
        // 模拟 API 调用（使用 DispatchQueue 兼容 Swift 5）
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                continuation.resume()
            }
        }
        return User(id: "1", name: "示例用户")
    }
}

