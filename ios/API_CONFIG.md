# iOS API 配置说明

## ✅ 已配置的地址

### API 地址
- **HTTP API**: `https://api.link2ur.com`
- **WebSocket**: `wss://api.link2ur.com`

### 配置文件位置

#### 方式 1: 使用 Constants.swift（推荐）
文件：`LinkU/Utils/Constants.swift`
```swift
struct AppConstants {
    static let apiBaseURL = "https://api.link2ur.com"
    static let wsBaseURL = "wss://api.link2ur.com"
}
```

#### 方式 2: 直接在服务类中配置
- **API 配置**: `LinkU/Services/APIService.swift`
  ```swift
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
python ios/test_api.py
```

### 测试 WebSocket
打开测试页面：`ios/test_websocket.html`

## 📝 注意事项

1. **API 和 WebSocket 使用相同域名**：`api.link2ur.com`
2. **WebSocket 路径**：`/ws/chat/{userId}`
3. **协议**：API 使用 `https://`，WebSocket 使用 `wss://`
4. **认证**：WebSocket 使用 Cookie 认证，无需在 URL 中传递 token

## 🔄 如果需要更改

如果将来需要更改 API 地址，只需更新上述配置文件中的常量即可。

