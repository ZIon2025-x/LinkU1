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
2. **测试 WebSocket**: 使用 `test_websocket.html` 脚本测试 WebSocket 连接
3. **代码检查**: 检查 Swift 代码和项目结构
4. **使用 macOS**: 通过虚拟机、云服务或真实 Mac 设备进行实际测试

详细说明请查看 [WINDOWS_TESTING_GUIDE.md](WINDOWS_TESTING_GUIDE.md)

### 配置说明

1. **API配置**: 在 `Services/APIService.swift` 中修改 `baseURL`
2. **权限配置**: 在 `Info.plist` 中配置所需权限
3. **推送通知**: 配置 Apple Developer 证书和推送密钥

## 🎨 UI 设计

本应用采用现代化的设计风格，符合主流 iOS 应用的审美标准：

### 设计特点

- **简洁现代**：使用卡片式设计，清晰的视觉层次
- **统一配色**：采用系统蓝色作为主色调，支持深色模式
- **流畅动画**：使用系统默认动画，提供流畅的交互体验
- **友好反馈**：清晰的加载状态、错误提示和空状态设计

### 设计系统

所有 UI 组件都基于统一的设计系统（`Utils/DesignSystem.swift`）：

- **颜色**：主色调、辅助色、语义化颜色（成功、警告、错误）
- **间距**：使用 8pt 倍数系统（4pt, 8pt, 16pt, 24pt, 32pt）
- **圆角**：统一使用 8pt, 12pt, 16pt, 24pt
- **阴影**：轻微阴影，提供层次感

### 主要界面

1. **登录界面**：渐变背景、圆形 Logo、现代化输入框、渐变按钮
2. **首页**：个性化欢迎语、快捷操作按钮、推荐任务卡片、最新动态
3. **任务列表**：卡片式布局、清晰信息层次、状态标签、搜索筛选
4. **个人中心**：圆形头像、功能列表、退出登录确认

## 📱 功能模块（用户端）

- ✅ 用户认证（登录/注册）
- ✅ 任务浏览与发布
- ✅ 跳蚤市场（浏览、发布、管理）
- ✅ 任务达人功能（浏览达人、查看服务、申请服务、我的申请）
- ✅ 论坛功能（发帖、回帖、点赞、收藏、搜索）
- ✅ 排行榜功能（查看榜单、提交竞品、投票）
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

