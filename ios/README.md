# LinkU iOS 应用 - 用户端

这是 LinkU 的 iOS 原生应用项目（**用户端**），使用 Swift + SwiftUI 开发。

**注意**: 这是纯用户端应用，不包含客服功能和管理员功能。客服和管理员功能仅在 Web 端提供。

## 📋 项目结构

```
LinkU/
├── App/                    # 应用入口
├── Models/                 # 数据模型
├── Views/                  # 视图层
├── ViewModels/            # 视图模型
├── Services/              # 服务层
├── Utils/                 # 工具类
└── Resources/             # 资源文件
```

## 🚀 快速开始

### 环境要求

**必需**: macOS 13.0 (Ventura) 或更高版本 + Xcode 15.0+

> ⚠️ **重要**: iOS 应用只能在 macOS 上开发和测试，无法在 Windows 上直接运行。
> 
> 如果你使用 Windows，请查看 [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md) 了解替代方案。

### 安装步骤

1. 在 Xcode 中打开项目
2. 配置开发团队和签名
3. 更新 `Utils/Constants.swift` 中的 API 基础URL
4. 运行项目 (⌘R)

### Windows 用户

如果你使用 Windows 系统：

1. **测试 API**: 使用 `test_api.py` 脚本测试后端 API
2. **测试 WebSocket**: 使用 `test_websocket.html` 测试 WebSocket 连接
3. **代码检查**: 检查 Swift 代码和项目结构
4. **使用 macOS**: 通过虚拟机、云服务或真实 Mac 设备进行实际测试

详细说明请查看 [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md)

### 配置说明

1. **API配置**: 在 `Services/APIService.swift` 中修改 `baseURL`
2. **权限配置**: 在 `Info.plist` 中配置所需权限
3. **推送通知**: 配置 Apple Developer 证书和推送密钥

## 📱 功能模块（用户端）

- ✅ 用户认证（登录/注册）
- ✅ 任务浏览与发布
- ✅ 跳蚤市场（浏览、发布、管理）
- ✅ 消息系统（WebSocket实时聊天）
- ✅ 个人中心（我的任务、我的发布、钱包）
- ✅ 设置与关于
- ✅ 多语言支持（中英文）

**不包含的功能**:
- ❌ 客服功能（仅在Web端）
- ❌ 管理员功能（仅在Web端）

## 🔧 开发说明

### 架构模式

使用 MVVM (Model-View-ViewModel) 架构：
- **Model**: 数据模型和业务逻辑
- **View**: SwiftUI 视图
- **ViewModel**: 视图模型，处理业务逻辑和状态管理

### 网络请求

使用 `URLSession` 进行网络请求，配合 `Combine` 框架处理异步操作。

### 数据持久化

使用 `UserDefaults` 存储简单配置，使用 `Keychain` 存储敏感信息（如token）。

## 📝 注意事项

1. **首次运行前需要配置 API 基础URL**（在 `Utils/Constants.swift` 或 `Services/APIService.swift` 中）
2. 需要配置正确的权限描述（Info.plist）
3. 推送通知需要配置 Apple Developer 证书
4. WebSocket 连接需要有效的认证token（登录后自动连接）
5. **这是用户端应用**，不包含客服和管理员功能

## 📚 相关文档

详细开发文档请参考项目根目录的 `MOBILE_APP_DEVELOPMENT_GUIDE.md`

