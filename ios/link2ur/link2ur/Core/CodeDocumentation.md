# 代码文档规范

## 概述

本文档定义了企业级 iOS 项目的代码文档规范，确保代码的可维护性和可读性。

## 文档类型

### 1. 文件头注释

每个 Swift 文件应包含文件头注释：

```swift
//
//  FileName.swift
//  Link²Ur
//
//  Created by [Author] on [Date].
//  Copyright © [Year] Link²Ur. All rights reserved.
//
//  Description: 简要描述文件的功能和用途
//
```

### 2. 类型文档

所有公开的类型（类、结构体、枚举、协议）应包含文档注释：

```swift
/// 企业级网络管理器
/// 
/// 提供请求队列、重试机制、请求去重、缓存策略等功能
/// 
/// ## 使用示例
/// ```swift
/// let manager = NetworkManager.shared
/// manager.execute(User.self, endpoint: "/api/users/me")
///     .sink(receiveValue: { user in
///         print(user.name)
///     })
/// ```
/// 
/// - Note: 所有网络请求都会自动重试，最多 3 次
/// - Warning: 不要在后台线程直接调用
public final class NetworkManager {
    // ...
}
```

### 3. 方法文档

所有公开方法应包含文档注释：

```swift
/// 执行网络请求
///
/// - Parameters:
///   - type: 响应数据类型，必须遵循 `Decodable` 协议
///   - endpoint: API 端点路径（不包含基础 URL）
///   - method: HTTP 方法，默认为 GET
///   - body: 请求体（字典格式）
///   - headers: 自定义请求头
///   - retryCount: 当前重试次数（内部使用）
///   - maxRetries: 最大重试次数，默认为 3
///   - cachePolicy: 缓存策略，默认为 networkFirst
///
/// - Returns: 发布者，成功时返回解码后的数据，失败时返回 `APIError`
///
/// - Throws: 不会抛出异常，错误通过 Combine 发布者返回
///
/// ## 示例
/// ```swift
/// NetworkManager.shared.execute(
///     User.self,
///     endpoint: "/api/users/me",
///     method: "GET"
/// )
/// ```
public func execute<T: Decodable>(
    _ type: T.Type,
    endpoint: String,
    method: String = "GET",
    body: [String: Any]? = nil,
    headers: [String: String]? = nil,
    retryCount: Int = 0,
    maxRetries: Int = 3,
    cachePolicy: CachePolicy = .networkFirst
) -> AnyPublisher<T, APIError>
```

### 4. 属性文档

重要属性应包含文档注释：

```swift
/// 当前环境配置
/// 
/// 支持 development、staging、production 三种环境
/// 环境会影响 API 基础 URL 和其他配置
public let environment: Environment
```

### 5. 复杂逻辑注释

对于复杂的业务逻辑，应添加行内注释：

```swift
// 检查请求去重：相同请求在 500ms 内只执行一次
if shouldDeduplicate(requestKey: requestKey) {
    Logger.debug("请求去重: \(requestKey)", category: .network)
    return waitForPendingRequest(requestKey: requestKey)
        .eraseToAnyPublisher()
}
```

## 文档标签

### 常用标签

- `- Parameter`: 参数说明
- `- Returns`: 返回值说明
- `- Throws`: 异常说明
- `- Note`: 重要提示
- `- Warning`: 警告信息
- `- Important`: 重要信息
- `- Author`: 作者
- `- Since`: 版本信息
- `- Version`: 版本号

### 示例

```swift
/// 加密敏感数据
///
/// - Parameter data: 要加密的数据
/// - Returns: 加密后的数据
/// - Throws: `SecurityError.encryptionFailed` 如果加密失败
/// - Note: 使用 AES-GCM 256 位加密
/// - Warning: 不要在日志中输出加密后的数据
/// - Since: iOS 14.0
public func encrypt(_ data: Data) throws -> Data
```

## 代码示例

文档中的代码示例应该是可运行的：

```swift
/// ## 使用示例
/// ```swift
/// let errorHandler = ErrorHandler.shared
/// errorHandler.handle(APIError.unauthorized, context: "登录")
/// ```
```

## 文档生成

使用 Jazzy 或 Swift-DocC 生成 HTML 文档：

```bash
# 安装 Jazzy
gem install jazzy

# 生成文档
jazzy --min-acl public
```

## 检查清单

- [ ] 所有公开类型都有文档注释
- [ ] 所有公开方法都有文档注释
- [ ] 复杂逻辑有行内注释
- [ ] 代码示例是可运行的
- [ ] 使用了适当的文档标签
- [ ] 文档与代码实现保持一致

