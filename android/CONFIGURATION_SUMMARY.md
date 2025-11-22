# Android 应用配置总结

## ✅ 已完成的配置

### API 地址
- **HTTP API**: `https://api.link2ur.com`
- **WebSocket**: `wss://api.link2ur.com/ws/chat/{userId}`

### 配置文件

1. **RetrofitClient.kt**
   ```kotlin
   private const val BASE_URL = "https://api.link2ur.com"
   ```

2. **WebSocketService.kt**
   ```kotlin
   val url = "wss://api.link2ur.com/ws/chat/$userId"
   ```

## 🚀 现在可以直接测试

所有 API 和 WebSocket 地址已配置完成，可以直接在 Android Studio 中运行测试！

### 测试步骤

1. 创建项目并复制文件（参考 `ANDROID_STUDIO_TEST_GUIDE.md`）
2. 同步项目依赖
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

