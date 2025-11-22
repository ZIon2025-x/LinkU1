# iOS 应用配置总结

## ✅ 已完成的配置

### API 地址
- **HTTP API**: `https://api.link2ur.com`
- **WebSocket**: `wss://api.link2ur.com/ws/chat/{userId}`

### 配置文件

1. **Constants.swift**
   ```swift
   static let apiBaseURL = "https://api.link2ur.com"
   static let wsBaseURL = "wss://api.link2ur.com"
   ```

2. **APIService.swift**
   ```swift
   let baseURL = "https://api.link2ur.com"
   ```

3. **WebSocketService.swift**
   ```swift
   "wss://api.link2ur.com/ws/chat/\(userId)"
   ```

## 🚀 现在可以直接测试

所有 API 和 WebSocket 地址已配置完成，可以直接在 Xcode 中运行测试！

### 测试步骤

1. 在 Xcode 中创建项目并添加文件（参考 `SETUP.md`）
2. 配置签名
3. 运行项目
4. 使用真实账号登录测试

### 预期结果

- ✅ 登录界面正常显示
- ✅ 可以成功登录（如果 API 地址正确）
- ✅ 登录后自动连接 WebSocket
- ✅ 可以浏览任务、跳蚤市场等页面

## 📝 注意事项

- API 和 WebSocket 使用相同的域名：`api.link2ur.com`
- WebSocket 路径：`/ws/chat/{userId}`
- 确保设备/模拟器有网络连接

