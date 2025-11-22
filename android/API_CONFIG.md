# API 配置说明

## ✅ 已配置的地址

### API 地址
- **HTTP API**: `https://api.link2ur.com`
- **WebSocket**: `wss://api.link2ur.com`

### 配置文件位置

#### Android
- **API 配置**: `app/src/main/java/com/linku/app/data/api/RetrofitClient.kt`
  ```kotlin
  private const val BASE_URL = "https://api.link2ur.com"
  ```

- **WebSocket 配置**: `app/src/main/java/com/linku/app/data/websocket/WebSocketService.kt`
  ```kotlin
  val url = "wss://api.link2ur.com/ws/chat/$userId"
  ```

#### iOS
- **API 配置**: `LinkU/Utils/Constants.swift` 或 `LinkU/Services/APIService.swift`
  ```swift
  static let apiBaseURL = "https://api.link2ur.com"
  let baseURL = "https://api.link2ur.com"
  ```

- **WebSocket 配置**: `LinkU/Services/WebSocketService.swift`
  ```swift
  "wss://api.link2ur.com/ws/chat/\(userId)"
  ```

## 🔍 验证配置

### 测试 API
运行测试脚本：
```bash
# Android
python android/test_api.py

# iOS
python ios/test_api.py
```

### 测试 WebSocket
打开测试页面：
- Android: `android/test_websocket.html`
- iOS: `ios/test_websocket.html`

## 📝 注意事项

1. **API 和 WebSocket 使用相同域名**：`api.link2ur.com`
2. **WebSocket 路径**：`/ws/chat/{userId}`
3. **协议**：API 使用 `https://`，WebSocket 使用 `wss://`
4. **认证**：WebSocket 使用 Cookie 认证，无需在 URL 中传递 token

## 🔄 如果需要更改

如果将来需要更改 API 地址，只需更新上述配置文件中的常量即可。

