# iOS 项目设置指南

## 📋 在 Xcode 中创建项目

由于这是一个 Swift 源代码集合，你需要在 Xcode 中创建新项目，然后将这些文件添加到项目中。

### 步骤 1: 创建新项目

1. 打开 Xcode
2. 选择 `File > New > Project`
3. 选择 `iOS > App`
4. 填写项目信息：
   - **Product Name**: LinkU
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (或根据需要选择)
5. 选择保存位置（**不要**保存在当前 ios 文件夹中）
6. 点击 `Create`

### 步骤 2: 添加文件到项目

1. 在 Xcode 项目导航器中，右键点击项目名称
2. 选择 `Add Files to "LinkU"...`
3. 导航到 `ios/LinkU` 文件夹
4. 选择所有文件夹（App, Models, Views, ViewModels, Services, Utils）
5. 确保勾选：
   - ✅ Copy items if needed
   - ✅ Create groups
   - ✅ Add to targets: LinkU
6. 点击 `Add`

### 步骤 3: 配置 Info.plist

1. 在 Xcode 中，找到项目的 `Info.plist` 文件
2. 打开 `ios/LinkU/Info.plist` 文件
3. 将权限描述复制到项目的 Info.plist 中，或直接替换

### 步骤 4: 配置 API 地址

1. 打开 `Utils/Constants.swift`，确认已配置：
   ```swift
   static let apiBaseURL = "https://api.link2ur.com"
   static let wsBaseURL = "wss://api.link2ur.com"
   ```

2. 或者在 `Services/APIService.swift` 中确认 `baseURL` 为：`"https://api.link2ur.com"`
3. WebSocket URL 已配置为：`"wss://api.link2ur.com/ws/chat/{userId}"`

### 步骤 5: 配置签名

1. 在 Xcode 中，选择项目文件（最顶部的蓝色图标）
2. 选择 `TARGETS > LinkU`
3. 在 `Signing & Capabilities` 标签页中：
   - 勾选 `Automatically manage signing`
   - 选择你的开发团队（Team）

### 步骤 6: 添加必要的框架

项目使用了以下系统框架，Xcode 会自动链接：
- Foundation
- SwiftUI
- Combine
- UserNotifications
- Security

### 步骤 7: 运行项目

1. 选择目标设备（模拟器或真机）
2. 按 `⌘R` 运行项目
3. 如果遇到编译错误，检查：
   - 所有文件是否已添加到项目
   - 文件是否在正确的 target 中
   - API 地址是否已配置

## 🔧 项目结构说明

```
LinkU/
├── App/                    # 应用入口
│   ├── LinkUApp.swift     # @main 入口点
│   └── ContentView.swift  # 主视图
├── Models/                 # 数据模型
│   ├── Task.swift
│   ├── User.swift
│   └── Message.swift
├── Views/                  # SwiftUI 视图
│   ├── LoginView.swift
│   ├── HomeView.swift
│   ├── TasksView.swift
│   ├── FleaMarketView.swift
│   ├── MessageView.swift
│   └── ProfileView.swift
├── ViewModels/            # 视图模型 (MVVM)
│   ├── AuthViewModel.swift
│   └── TasksViewModel.swift
├── Services/              # 服务层
│   ├── APIService.swift
│   ├── WebSocketService.swift
│   └── NotificationManager.swift
└── Utils/                 # 工具类
    ├── KeychainHelper.swift
    └── AppState.swift
```

## ⚠️ 注意事项

1. **API 地址**: 必须更新 `APIService.swift` 和 `WebSocketService.swift` 中的 URL
2. **权限**: Info.plist 中的权限描述已配置，但需要确保在 Xcode 项目中正确设置
3. **依赖**: 项目目前只使用系统框架，无需安装第三方依赖
4. **测试**: 部分功能（如 WebSocket、推送通知）需要在真机上测试

## 📱 下一步开发

1. 完善各个 View 的实现
2. 添加更多 ViewModel
3. 实现图片选择功能
4. 完善 WebSocket 消息处理
5. 添加更多业务逻辑

## 🐛 常见问题

**Q: 编译错误 "Cannot find type 'X' in scope"**
A: 确保所有文件都已添加到项目的 target 中

**Q: WebSocket 连接失败**
A: 检查 API 地址是否正确，以及网络权限是否配置

**Q: 推送通知不工作**
A: 需要在真机上测试，模拟器不支持推送通知

