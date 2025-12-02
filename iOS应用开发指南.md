# LinkU iOS 应用开发指南

## 版本信息

**当前版本**：v1.2  
**最后更新**：2025-01-20

### 变更记录

- **v1.0**（2025-01-20）：初始化文档，包含完整开发流程
- **v1.1**（2025-01-20）：
  - 修正章节编号，统一使用附录格式
  - 统一401错误处理策略，消除前后矛盾
  - 补充技术路线说明
  - 补充UI设计规范章节
  - 补充隐私合规、埋点、状态管理等内容
  - 优化细节表述，增强文档严谨性
- **v1.2**（2025-01-20）：
  - 新增"开发前准备清单"章节
  - 明确从文档到编码的前置条件
  - 包含后端环境、设计资源、证书配置、团队约定等检查项

---

## 技术路线说明

在开始开发前，请了解项目当前约定的技术路线：

**网络层**：
- 使用 URLSession + Combine 进行网络请求和状态订阅
- 后续规划（可选）：视情况逐步引入 async/await，将 APIService 改为 async throws 风格

**架构模式**：
- SwiftUI + MVVM + Service 分层架构
- View层使用SwiftUI，ViewModel层使用ObservableObject，Service层负责业务逻辑

**导航系统**：
- 最低支持 iOS 15，当前统一使用 NavigationView
- 新功能避免使用 iOS 16+ 特性（如 NavigationStack、navigationDestination）
- 未来整体升级最低版本时，统一迁移到 NavigationStack

**状态管理**：
- AppState 管理全局状态（登录状态、用户信息、全局配置）
- 各模块使用独立的 ViewModel 管理业务状态
- 通过 EnvironmentObject 共享全局状态

**缓存策略**：
- 仅做简单缓存，不支持离线编辑
- 所有会改变服务器状态的操作必须在线执行
- 失败后不做本地排队重试

**设备支持**：
- 首个版本仅支持 iPhone 竖屏
- iPad 以 iPhone 模式运行
- 新写 View 时尽量使用自适应布局，为后续 iPad 适配留余地

---

## 概述

本指南详细描述如何开发LinkU的iOS原生应用。应用使用Swift和SwiftUI开发，采用MVVM架构模式，复用现有的后端API，无需修改后端代码。应用专注于用户端功能，包括任务发布、跳蚤市场、实时消息等核心功能。

---

## 开发前准备清单

在开始编码之前，请确认以下准备工作是否就绪。这些是开始开发的前置条件，缺一不可。

### 后端接口与环境就绪

**第一步：确认后端环境**
- [ ] **域名/Base URL确定**：
  - 开发环境URL：`https://dev-api.link2ur.com`（示例）
  - 测试环境URL：`https://test-api.link2ur.com`（示例）
  - 生产环境URL：`https://api.link2ur.com`（示例）
  - WebSocket URL：`wss://api.link2ur.com`（示例）
- [ ] **环境可访问性验证**：
  - 开发/测试环境可以正常访问
  - 网络请求无防火墙阻拦
  - CORS配置正确（如果涉及跨域）

**第二步：核心接口联调**
- [ ] **认证相关接口**：
  - [ ] 登录接口（POST /api/secure-auth/login）可调通
  - [ ] 注册接口（POST /api/users/register）可调通
  - [ ] Token刷新接口（POST /api/secure-auth/refresh）可调通
  - [ ] 获取用户信息接口（GET /api/users/profile/me）可调通
- [ ] **任务相关接口**：
  - [ ] 获取任务列表（GET /api/tasks）可调通
  - [ ] 获取任务详情（GET /api/tasks/{id}）可调通
  - [ ] 创建任务（POST /api/tasks）可调通
- [ ] **跳蚤市场接口**：
  - [ ] 获取商品列表（GET /api/flea-market/items）可调通
  - [ ] 获取商品详情（GET /api/flea-market/items/{id}）可调通
- [ ] **文件上传接口**：
  - [ ] 上传图片（POST /api/upload/image）可调通
  - [ ] 返回格式确认（URL格式、大小限制等）

**第三步：接口文档确认**
- [ ] 获取完整的API文档（Swagger/Postman集合等）
- [ ] 确认所有接口的请求/响应格式
- [ ] 确认错误码和错误信息格式
- [ ] 确认分页、筛选、搜索等参数的格式

**第四步：WebSocket连接测试**
- [ ] WebSocket连接地址确认
- [ ] 连接认证方式确认（Token传递方式）
- [ ] 消息格式确认（JSON结构）
- [ ] 可以手动测试连接和收发消息

### 设计稿与设计资源

**第一步：设计稿准备**
- [ ] **关键页面设计稿**（Figma/XD/Sketch等）：
  - [ ] 登录/注册页面
  - [ ] 首页（Tab导航、推荐任务）
  - [ ] 任务列表页
  - [ ] 任务详情页
  - [ ] 发布任务页
  - [ ] 跳蚤市场列表页
  - [ ] 商品详情页
  - [ ] 消息列表页
  - [ ] 聊天页面
  - [ ] 个人中心页
  - [ ] 设置页面
- [ ] **设计稿标注**：
  - [ ] 颜色值（Hex/RGB）
  - [ ] 字体大小和权重
  - [ ] 间距和布局尺寸
  - [ ] 圆角、阴影等样式参数

**第二步：设计资源准备**
- [ ] **应用图标**：
  - [ ] 提供所有尺寸的图标（20pt、29pt、40pt、60pt、76pt、83.5pt、1024pt等）
  - [ ] 或提供1024x1024的源文件，开发时生成各尺寸
- [ ] **启动画面**：
  - [ ] 启动画面设计稿
  - [ ] 或使用LaunchScreen.storyboard配置
- [ ] **图片资源**：
  - [ ] 空状态插图（任务列表为空、消息列表为空等）
  - [ ] 错误状态插图（网络错误、加载失败等）
  - [ ] 占位图（头像占位、图片占位等）
- [ ] **图标资源**：
  - [ ] 确认使用SF Symbols还是自定义图标
  - [ ] 如需自定义图标，提供图标文件（SVG/PDF格式）

**第三步：设计规范确认**
- [ ] 颜色系统已定义（主色调、辅助色、语义化颜色）
- [ ] 字体系统已定义（字体层级、权重）
- [ ] 组件样式已定义（按钮、卡片、输入框等）
- [ ] 深色模式设计稿（如有需求）

### Apple Developer账号与证书

**第一步：Apple Developer账号**
- [ ] 已有Apple Developer账号（个人账号或企业账号）
- [ ] 账号状态正常，可以创建App ID和证书
- [ ] 了解账号类型限制（个人账号有设备数量限制）

**第二步：App ID和证书配置**
- [ ] 在Apple Developer网站创建App ID
  - Bundle Identifier：`com.yourcompany.LinkU`
  - 启用所需Capabilities（Push Notifications、Associated Domains等）
- [ ] 配置开发证书和发布证书
  - 或在Xcode中使用自动签名（推荐）
- [ ] 创建Provisioning Profile（如果使用手动签名）

**第三步：真机测试准备**
- [ ] 有可用于测试的iPhone设备（iOS 15+）
- [ ] 设备已注册到Apple Developer账号
- [ ] 可以在真机上安装测试版本
- [ ] 了解如何通过Xcode安装或通过TestFlight分发

**第四步：推送通知配置（如需要）**
- [ ] 在Apple Developer网站创建推送证书
  - 开发环境推送证书
  - 生产环境推送证书
- [ ] 后端已配置APNs推送服务
- [ ] 后端可以接收设备Token并发送推送
- [ ] 测试推送功能是否正常

### 团队约定对齐

**第一步：架构约定**
- [ ] 团队已确认使用SwiftUI + MVVM + Service架构
- [ ] 理解各层职责划分（View、ViewModel、Service、Model）
- [ ] 理解状态管理方式（AppState、ViewModel、EnvironmentObject）

**第二步：代码风格约定**
- [ ] 命名规范已确认（类名、变量名、函数名等）
- [ ] 目录结构已确认（App、Models、Views、ViewModels、Services、Utils）
- [ ] 代码组织方式已确认（一个View一个文件、模块化组织）
- [ ] SwiftLint规则已配置（如使用）

**第三步：开发流程约定**
- [ ] Git工作流已确认（分支策略、提交规范）
- [ ] Code Review流程已确认
- [ ] 开发环境配置已确认（.xcconfig文件、环境变量等）

**第四步：测试策略约定**
- [ ] 测试优先级已确认：
  - [ ] 先功能测试再UI测试
  - [ ] 或需要编写部分单元测试
  - [ ] 或需要编写快照测试（Snapshot Testing）
- [ ] 测试覆盖率要求已确认（如60%）
- [ ] 测试环境数据准备（测试账号、测试数据等）

**第五步：协作工具约定**
- [ ] 项目管理工具（Jira/Trello/Notion等）
- [ ] 设计稿查看工具（Figma/Zeplin等）
- [ ] API文档工具（Swagger/Postman等）
- [ ] 沟通工具（Slack/企业微信等）

### 开发环境配置

**第一步：开发工具安装**
- [ ] Xcode 15.0+已安装
- [ ] Swift 5.9+已安装
- [ ] CocoaPods或Swift Package Manager可用（如需要）

**第二步：项目初始化**
- [ ] 项目已在Git仓库中创建
- [ ] 项目结构已按文档创建（文件夹结构）
- [ ] 基础配置文件已创建（.xcconfig、Info.plist等）

**第三步：依赖管理**
- [ ] 确认是否需要第三方库
- [ ] 如需使用，已确定依赖管理方式（SPM/CocoaPods）
- [ ] 依赖库列表已确认

### 检查清单使用说明

**如何使用此清单**：
1. 在开始编码前，逐项检查并勾选
2. 如有未完成项，先完成准备工作
3. 所有项都完成后，可以开始按照文档进行开发
4. 建议将此清单打印或保存，定期回顾

**优先级说明**：
- **必须项**：缺少这些项无法开始开发（后端接口、Apple账号、设计稿）
- **重要项**：缺少这些项会影响开发效率（设计资源、团队约定）
- **可选项**：可以在开发过程中逐步完善（部分测试策略、部分设计资源）

---

## 第一部分：开发环境准备

### 系统要求

**必需环境**：
- macOS 13.0 (Ventura) 或更高版本
- Xcode 15.0 或更高版本
- Swift 5.9 或更高版本
- iOS 15.0 或更高版本作为最低支持版本

**可选工具**：
- CocoaPods（如果需要使用第三方库）
- Swift Package Manager（推荐，Xcode内置）

### 创建新项目

**第一步：在Xcode中创建项目**
- 打开Xcode，选择"Create a new Xcode project"
- 选择iOS平台，应用模板选择"App"
- 项目名称填写"LinkU"
- Interface选择"SwiftUI"（推荐）或"Storyboard"
- Language选择"Swift"
- 取消勾选"Use Core Data"（除非需要本地数据库）
- 选择项目保存位置，点击"Create"

**第二步：配置项目基本信息**
- 在项目设置中，设置Bundle Identifier为"com.yourcompany.LinkU"
- 设置Display Name为"LinkU"
- 设置最低iOS版本为15.0
- 选择支持的方向（通常选择Portrait和Landscape）

**第三步：配置开发团队和签名**
- 在Signing & Capabilities中，选择你的Apple Developer账号
- 如果还没有账号，可以先用个人免费账号进行开发测试
- 启用"Automatically manage signing"让Xcode自动管理证书

### 配置项目权限

**第一步：添加权限说明**
- 打开Info.plist文件（或在项目设置的Info标签页）
- 添加以下权限说明，这些说明会在用户首次使用时显示：

**位置权限**：
- 添加Key：Privacy - Location When In Use Usage Description
- 值填写："我们需要您的位置信息以提供附近的任务和跳蚤市场商品，帮助您选择所在城市"

**相机权限**：
- 添加Key：Privacy - Camera Usage Description
- 值填写："我们需要访问相机以拍摄任务或商品图片"

**相册权限**：
- 添加Key：Privacy - Photo Library Usage Description
- 值填写："我们需要访问相册以选择任务或商品的图片"

**注意**：iOS的通知权限不需要在Info.plist中配置Usage Description。通知权限是通过UNUserNotificationCenter.requestAuthorization()弹窗获取的，详见"推送通知"章节。

**第二步：配置网络访问**
- 在Info.plist中添加App Transport Security设置
- 允许HTTP访问（如果后端使用HTTP）或配置HTTPS例外
- 通常生产环境使用HTTPS，开发环境可能需要HTTP

---

## 第二部分：项目结构搭建

### 创建目录结构

**第一步：在Xcode中创建文件夹**
- 在项目导航器中，右键点击LinkU文件夹
- 选择"New Group"，创建以下文件夹结构：

```
LinkU/
├── App/                    # 应用入口
├── Models/                 # 数据模型
├── Views/                  # 视图层
│   ├── Auth/              # 认证相关视图
│   ├── Home/              # 首页视图
│   ├── Tasks/              # 任务相关视图
│   ├── FleaMarket/         # 跳蚤市场视图
│   ├── Message/            # 消息视图
│   └── Profile/            # 个人中心视图
├── ViewModels/            # 视图模型
├── Services/              # 服务层
├── Utils/                 # 工具类
└── Resources/             # 资源文件
```

**第二步：创建基础文件**
- 在App文件夹中，保留自动生成的LinkUApp.swift和ContentView.swift
- 在其他文件夹中，先创建占位文件，后续逐步实现

### 配置MVVM架构

**第一步：理解架构层次**
- **View层**：使用SwiftUI创建界面，只负责展示和用户交互
- **ViewModel层**：继承ObservableObject，使用@Published属性发布状态变化
- **Model层**：定义数据结构，实现Codable协议用于JSON序列化
- **Service层**：负责网络请求、数据持久化等业务逻辑

**第二步：设置依赖注入和状态管理**
- 在LinkUApp.swift中，使用@StateObject创建全局的ViewModel
- 使用@EnvironmentObject在视图间共享状态
- 创建AppState类管理全局应用状态

**状态管理边界原则**：
- **AppState 只放"全局且高复用"的状态**：
  - 登录状态（isAuthenticated）
  - 当前用户信息（currentUser）
  - 全局配置（theme、language等）
  - 通知计数（unreadMessageCount等）
- **业务页面状态放在各自 ViewModel**：
  - 列表分页状态（currentPage、hasMore）
  - 筛选条件（filters）
  - 当前详情数据（selectedTask等）
- **避免在多个模块中同时直接依赖 AppState**：
  - 统一通过 EnvironmentObject 或依赖注入传递
  - 减少模块间的直接耦合

---

## 第三部分：UI设计规范和设计系统

### 设计原则

**第一步：遵循iOS设计规范**
- 严格遵循Apple的Human Interface Guidelines（HIG）
- 保持与iOS系统应用一致的交互模式
- 使用系统提供的标准组件和控件
- 确保应用看起来和感觉起来都像原生iOS应用

**第二步：设计一致性**
- 在整个应用中保持视觉和交互的一致性
- 统一的颜色、字体、间距、圆角等设计元素
- 统一的组件样式和行为
- 统一的动画和过渡效果

### 颜色系统

**第一步：定义颜色方案**
- 在Assets.xcassets中创建Color Set
- 定义主色调（Primary Color）：用于主要按钮、链接、强调元素
- 定义辅助色（Secondary Color）：用于次要元素
- 定义语义化颜色：
  - 成功（Success）：绿色，用于成功状态
  - 警告（Warning）：橙色，用于警告状态
  - 错误（Error）：红色，用于错误状态
  - 信息（Info）：蓝色，用于信息提示

**第二步：支持深色模式**
- 每个颜色都定义Light和Dark两个变体
- 在Asset Catalog中为每个Color Set配置Appearances
- 确保浅色和深色模式下都有足够的对比度（至少4.5:1）
- 测试所有界面在两种模式下的显示效果

**第三步：使用语义化颜色**
- 使用系统提供的语义化颜色（如Color.label、Color.background）
- 自定义颜色时，使用语义化命名（如primaryColor、errorColor）
- 避免硬编码颜色值，统一使用Color Set

**示例颜色定义**：
- Primary: 主品牌色（如蓝色 #007AFF）
- Secondary: 辅助色（如灰色 #8E8E93）
- Success: 成功绿色 #34C759
- Warning: 警告橙色 #FF9500
- Error: 错误红色 #FF3B30
- Background: 背景色（浅色模式白色，深色模式黑色）
- Label: 文字颜色（自动适配深色模式）

### 字体系统

**第一步：使用系统字体**
- 优先使用SF Pro字体（iOS系统字体）
- 使用Text组件时，默认使用系统字体
- 支持Dynamic Type，让用户调整字体大小

**第二步：定义字体层级**
- **大标题（Large Title）**：34pt，用于页面主标题
- **标题1（Title 1）**：28pt，用于重要标题
- **标题2（Title 2）**：22pt，用于次要标题
- **标题3（Title 3）**：20pt，用于小标题
- **正文（Body）**：17pt，用于正文内容
- **副标题（Subheadline）**：15pt，用于辅助信息
- **脚注（Footnote）**：13pt，用于说明文字
- **说明文字（Caption）**：12pt，用于最小文字

**第三步：字体权重**
- 常规（Regular）：用于正文
- 中等（Medium）：用于强调
- 粗体（Bold）：用于标题和重要信息
- 半粗体（Semibold）：用于次要标题

**第四步：实现Dynamic Type支持**
- 所有Text组件使用系统字体样式（如.title、.body）
- 避免固定字体大小，使用相对大小
- 测试不同字体大小下的界面布局
- 确保文字不会被截断或重叠

### 间距和布局

**第一步：定义间距系统**
- 使用8pt的倍数作为基础间距单位
- 常用间距：
  - 4pt：最小间距（图标与文字之间）
  - 8pt：小间距（列表项内部）
  - 16pt：标准间距（卡片内边距、列表项间距）
  - 24pt：中等间距（区块之间）
  - 32pt：大间距（主要区块之间）

**第二步：布局规范**
- 使用SwiftUI的Padding、Spacing等修饰符统一管理间距
- 列表项使用统一的padding（通常16pt）
- 卡片使用统一的圆角（通常12pt或16pt）
- 屏幕边缘留出安全区域（使用safeAreaInset）

**第三步：响应式布局**
- 使用GeometryReader适配不同屏幕尺寸
- 使用HStack、VStack、ZStack合理组织布局
- 使用Spacer和Divider分隔内容
- 考虑横屏和竖屏的布局差异
- **iPad适配策略**：
  - 首个版本仅支持iPhone竖屏，iPad以iPhone模式运行
  - 新写View时尽量使用自适应布局，避免绝对宽高
  - 为后续iPad适配留余地（使用相对尺寸而非固定尺寸）

### 组件设计规范

**第一步：按钮设计**
- **主要按钮（Primary Button）**：
  - 使用主色调背景，白色文字
  - 圆角12pt，高度44pt（最小触摸区域）
  - 使用.bold字体权重
- **次要按钮（Secondary Button）**：
  - 使用边框样式，透明背景
  - 文字颜色为主色调
  - 圆角和高度与主要按钮一致
- **文字按钮（Text Button）**：
  - 无背景，仅文字
  - 用于次要操作
- **按钮状态**：
  - 正常、高亮、禁用三种状态
  - 禁用状态降低透明度（0.5）

**第二步：卡片设计**
- 使用Card组件统一卡片样式
- 白色背景（深色模式下深灰色）
- 圆角12pt或16pt
- 阴影：浅色模式轻微阴影，深色模式无阴影或发光效果
- 内边距16pt
- 支持点击交互（使用Button包装）

**第三步：输入框设计**
- 使用TextField和SecureField
- 圆角8pt
- 边框颜色：正常状态浅灰色，聚焦状态主色调
- 高度44pt（最小触摸区域）
- 内边距12pt
- 占位符文字使用副标题样式，颜色为.secondary

**第四步：列表项设计**
- 使用List或自定义列表项
- 高度至少44pt
- 左右边距16pt
- 使用Divider分隔列表项
- 支持点击反馈（高亮效果）

**第五步：标签和徽章**
- **状态标签**：
  - 圆角4pt或6pt
  - 内边距4pt（水平）8pt（垂直）
  - 使用语义化颜色（成功-绿色、警告-橙色、错误-红色）
- **数字徽章**：
  - 圆形，最小尺寸20pt
  - 红色背景，白色文字
  - 用于未读消息数等

### 图标和图片

**第一步：使用SF Symbols**
- 优先使用Apple提供的SF Symbols图标库
- 确保图标风格统一
- 支持Dynamic Type和深色模式
- 自定义图标时，遵循SF Symbols的设计规范

**第二步：图片处理**
- 使用AsyncImage异步加载网络图片
- 显示占位图（使用系统图标或占位色）
- 图片圆角统一（如12pt）
- 支持图片缓存，避免重复下载
- 压缩大图片，优化加载速度

**第三步：头像设计**
- 圆形头像，使用.clipShape(Circle())
- 默认头像使用系统图标或占位图
- 支持不同尺寸（小32pt、中48pt、大64pt）

### 动画和过渡

**第一步：使用系统动画**
- 使用SwiftUI的默认动画（.animation(.default)）
- 过渡动画使用.transition()修饰符
- 遵循iOS系统动画时长和缓动曲线

**第二步：常见动画场景**
- **页面转场**：使用NavigationLink的默认转场
- **模态展示**：使用.sheet()的默认动画
- **列表操作**：删除、添加使用.withAnimation()
- **加载状态**：使用ProgressView的旋转动画
- **按钮反馈**：使用.scaleEffect()提供点击反馈

**第三步：动画时长**
- 快速动画：0.2秒（按钮反馈、小元素）
- 标准动画：0.3秒（页面转场、模态展示）
- 慢速动画：0.5秒（复杂动画、强调效果）

### 交互反馈

**第一步：触觉反馈**
- 使用UIImpactFeedbackGenerator提供触觉反馈
- 重要操作（如提交表单）使用中等强度反馈
- 次要操作使用轻强度反馈
- 错误操作使用通知型反馈

**第二步：视觉反馈**
- 按钮点击时使用.scaleEffect(0.95)提供视觉反馈
- 列表项点击时使用高亮效果
- 加载状态使用ProgressView或骨架屏
- 成功/失败操作显示Toast或Alert

**第三步：状态指示**
- 加载中：显示ProgressView
- 成功：显示绿色对勾或Toast提示
- 失败：显示红色错误提示
- 空状态：显示友好的空状态插图和文字

### 设计资源管理

**第一步：Assets管理**
- 在Assets.xcassets中组织所有设计资源
- 创建文件夹分类：Colors、Images、Icons等
- 使用有意义的命名（如button-primary、icon-home）
- 为图片提供@2x和@3x版本

**第二步：设计Token**
- 创建DesignToken文件，定义所有设计变量
- 包含：颜色、字体、间距、圆角、阴影等
- 方便统一修改和维护
- 示例：
  ```swift
  struct DesignToken {
      struct Color {
          static let primary = Color("Primary")
          static let error = Color("Error")
      }
      struct Spacing {
          static let small: CGFloat = 8
          static let medium: CGFloat = 16
          static let large: CGFloat = 32
      }
      struct CornerRadius {
          static let small: CGFloat = 8
          static let medium: CGFloat = 12
          static let large: CGFloat = 16
      }
  }
  ```

**第三步：组件库**
- 创建可复用的UI组件库
- 统一组件样式和行为
- 组件包括：Button、Card、TextField、Badge等
- 使用ViewModifier统一应用样式

### 设计检查清单

在开发每个界面时，检查以下项目：

**视觉一致性**
- [ ] 颜色使用是否正确（主色调、语义化颜色）
- [ ] 字体大小和权重是否符合规范
- [ ] 间距是否统一（8pt倍数）
- [ ] 圆角是否一致

**深色模式**
- [ ] 所有颜色都支持深色模式
- [ ] 文字对比度足够（至少4.5:1）
- [ ] 图片在深色模式下显示正常

**无障碍**
- [ ] 所有交互元素都有accessibilityLabel
- [ ] 支持Dynamic Type，文字不会被截断
- [ ] 支持VoiceOver导航

**交互反馈**
- [ ] 按钮点击有视觉反馈
- [ ] 重要操作有触觉反馈
- [ ] 加载状态有明确指示
- [ ] 错误状态有友好提示

**响应式**
- [ ] 适配不同屏幕尺寸
- [ ] 横屏和竖屏布局合理
- [ ] 安全区域处理正确

---

## 第四部分：工具类和基础服务开发

### 创建常量配置类

**第一步：创建Constants.swift**
- 在Utils文件夹中创建Constants.swift文件
- 定义API基础URL（从环境变量或配置读取，区分开发和生产环境）
- 定义WebSocket连接URL
- 定义应用常量（如分页大小、图片最大尺寸等）
- 定义错误消息常量

**第二步：配置环境变量**
- 创建Config.swift文件，用于读取配置
- **推荐使用.xcconfig文件管理多环境配置**：
  - 创建Debug.xcconfig、Staging.xcconfig、Release.xcconfig
  - 在不同配置文件中设置不同的API基础URL
  - 在项目设置中为不同Scheme选择对应的配置文件
- 或者使用Build Configuration区分Debug和Release环境
- 或者从Info.plist读取配置值

### 创建Keychain工具类

**第一步：创建KeychainHelper.swift**
- 在Utils文件夹中创建KeychainHelper类
- 实现保存Token的方法：将Token安全存储到Keychain
- 实现读取Token的方法：从Keychain读取Token
- 实现删除Token的方法：用户退出登录时清除Token
- 使用Security框架的Keychain Services API

**第二步：实现Token管理**
- Token存储时使用应用的Bundle Identifier作为服务标识
- 使用账户标识区分不同类型的Token（accessToken、refreshToken等）
- 实现错误处理，如果Keychain操作失败，返回错误信息

### 创建API服务类

**第一步：创建APIService.swift**
- 在Services文件夹中创建APIService类
- 使用单例模式，方便全局访问
- 使用URLSession进行网络请求
- 配置URLSession的timeoutInterval，设置合理的超时时间

**第二步：实现通用请求方法**
- 创建泛型请求方法，支持不同类型的响应模型
- 使用Combine框架的dataTaskPublisher处理异步请求
- 自动在请求头中添加Authorization Token（从Keychain读取）
- 统一处理HTTP状态码和网络错误（无网络、超时等）

**第三步：实现Token刷新策略（401错误处理标准流程）**
- **业务标准处理流程**：
  1. 请求返回401错误
  2. 检查本地是否有refreshToken
  3. 如果有refreshToken：
     - 调用/api/secure-auth/refresh接口刷新Token
     - 刷新成功：更新本地Token，重试一次原请求
     - 刷新失败：清除所有Token，返回登录界面
  4. 如果没有refreshToken：
     - 直接清除Token，返回登录界面
- 实现刷新锁机制：避免多个并发请求同时触发刷新
  - 使用DispatchSemaphore或Actor确保同一时间只有一个刷新请求
  - 其他请求等待刷新完成后再重试
- 如果refreshToken也过期，清除所有Token，返回登录界面

**第四步：实现具体API方法**
- 实现登录API：POST请求到/api/secure-auth/login，传递邮箱和密码
- 实现注册API：POST请求到/api/users/register，传递注册信息
- 实现获取任务列表API：GET请求到/api/tasks，支持分页和筛选参数
- 实现创建任务API：POST请求到/api/tasks，传递任务信息
- 实现上传图片API：POST请求到/api/upload/image，使用multipart/form-data格式
- 实现其他必要的API方法

**第五步：实现错误处理**
- 定义APIError枚举，包含各种错误类型（网络错误、服务器错误、认证错误等）
- 在请求方法中捕获错误，转换为APIError
- 在ViewModel中处理错误，显示友好的错误提示

### 创建WebSocket服务类

**第一步：创建WebSocketService.swift**
- 在Services文件夹中创建WebSocketService类
- 使用单例模式
- 使用URLSessionWebSocketTask建立WebSocket连接
- 连接URL格式：wss://your-backend-url/ws/chat/{userId}?token={token}

**第二步：实现连接管理**
- 实现连接方法：在用户登录后自动建立连接
- 实现断开方法：用户退出登录时断开连接
- 实现重连机制：连接断开时自动重连，最多重试5次，使用指数退避策略
- 实现心跳机制：定期发送ping消息保持连接活跃

**重要：前后台切换处理和数据一致性**
- 在应用进入后台时，WebSocket可能被系统挂起
- **从后台恢复时的标准流程**：
  1. 检查WebSocket连接状态
  2. 如果连接断开，强制重新连接
  3. 调用REST API拉取一次未读消息/会话列表做reconcile（数据一致性校验）
  4. 如果WebSocket收到和本地重复的消息（同一messageId），要去重
- **数据一致性策略**：
  - 前台时以WebSocket为主，REST做补偿
  - 不要过度依赖后台长连，可能出现"本地显示已连，实际上已断开"的情况
  - 约定：应用每次从后台回到前台时，都进行一次状态同步

**第三步：实现消息收发**
- 实现发送消息方法：将消息转换为JSON格式发送
- 实现接收消息方法：接收WebSocket消息，解析JSON
- 使用Combine的@Published属性发布收到的消息
- 实现消息队列：如果连接未建立，将消息加入队列，连接建立后发送

### 创建图片选择服务类

**第一步：创建ImagePickerService.swift**
- 在Services文件夹中创建ImagePickerService类
- **必须使用PHPickerViewController（iOS 14+）**，通过UIViewControllerRepresentable封装成SwiftUI View
- 支持从相机拍摄和从相册选择
- 统一约定：支持单张或多张选择，通过参数控制
- 返回选中的图片（UIImage格式）

**第二步：实现图片压缩**
- 在图片选择后，检查图片大小
- 如果图片过大（如超过2MB），进行压缩
- 使用UIImage的jpegData方法，设置压缩质量（0.7-0.8）
- 返回压缩后的Data，用于上传

**第三步：实现图片上传**
- 调用APIService的上传图片方法
- 显示上传进度（如果需要）
- 上传成功后返回图片URL
- 上传失败时显示错误提示


---

## 附录一：API接口总览表

为了方便快速了解所有需要对接的API接口，以下是按模块整理的接口总览：

| 模块 | 功能 | Method | Path | 说明 |
|------|------|--------|------|------|
| **认证** | 登录 | POST | /api/secure-auth/login | 返回accessToken和refreshToken |
| | 注册 | POST | /api/users/register | 需要邮箱验证码 |
| | 刷新Token | POST | /api/secure-auth/refresh | 使用refreshToken刷新 |
| | 退出登录 | POST | /api/secure-auth/logout | 清除服务端Token |
| **用户** | 获取用户信息 | GET | /api/users/profile/me | 获取当前用户信息 |
| | 更新用户信息 | PUT | /api/users/profile/me | 更新用户资料 |
| | 上传头像 | POST | /api/users/avatar | 上传用户头像 |
| **任务** | 获取任务列表 | GET | /api/tasks | 支持分页、筛选、搜索参数 |
| | 获取任务详情 | GET | /api/tasks/{id} | 获取单个任务详情 |
| | 创建任务 | POST | /api/tasks | 发布新任务 |
| | 更新任务 | PUT | /api/tasks/{id} | 更新任务信息 |
| | 申请任务 | POST | /api/tasks/{id}/accept | 申请执行任务 |
| | 完成任务 | POST | /api/tasks/{id}/complete | 标记任务完成 |
| | 取消任务 | POST | /api/tasks/{id}/cancel | 取消任务 |
| | 我的任务 | GET | /api/users/tasks | 获取用户相关任务 |
| **跳蚤市场** | 获取商品列表 | GET | /api/flea-market/items | 支持分页、筛选、搜索 |
| | 获取商品详情 | GET | /api/flea-market/items/{id} | 获取单个商品详情 |
| | 创建商品 | POST | /api/flea-market/items | 发布新商品 |
| | 更新商品 | PUT | /api/flea-market/items/{id} | 更新商品信息 |
| | 获取分类 | GET | /api/flea-market/categories | 获取商品分类列表 |
| | 我的发布 | GET | /api/users/flea-market/items | 获取用户发布的商品 |
| **消息** | 获取对话列表 | GET | /api/users/conversations | 获取所有对话 |
| | 获取对话消息 | GET | /api/users/messages | 获取指定对话的消息 |
| | 发送消息 | POST | /api/users/messages/send | 发送新消息 |
| | 标记已读 | PUT | /api/users/messages/{id}/read | 标记消息已读 |
| **文件上传** | 上传图片 | POST | /api/upload/image | 上传图片，返回URL |
| **WebSocket** | 实时消息 | WS | /ws/chat/{userId}?token={token} | 实时消息推送 |

**注意**：所有需要认证的接口都需要在请求头中携带Authorization: Bearer {token}

---

## 第五部分：数据模型开发

### 创建用户模型

**第一步：创建User.swift**
- 在Models文件夹中创建User结构体
- 实现Codable协议，用于JSON序列化和反序列化
- 定义用户属性：id、email、username、avatar、created_at等
- 使用CodingKeys处理JSON键名与Swift属性名的映射（如created_at映射到createdAt）

**第二步：创建登录响应模型**
- 创建LoginResponse结构体
- 包含accessToken、refreshToken（如果有）、user信息
- 实现Codable协议

### 创建任务模型

**第一步：创建Task.swift**
- 在Models文件夹中创建Task结构体
- 定义任务属性：id、title、description、category、city、price、status等
- 创建TaskStatus枚举：open、in_progress、completed、cancelled
- 实现Codable协议

**第二步：创建任务列表响应模型**
- 创建TaskListResponse结构体
- 包含tasks数组、total数量、page、page_size等分页信息
- 实现Codable协议

**第三步：创建任务创建请求模型**
- 创建CreateTaskRequest结构体
- 包含创建任务所需的所有字段
- 实现Codable协议，用于JSON编码

### 创建消息模型

**第一步：创建Message.swift**
- 在Models文件夹中创建Message结构体
- 定义消息属性：id、sender_id、receiver_id、content、type、created_at等
- 创建MessageType枚举：text、image、file等
- 实现Codable协议

**第二步：创建对话模型**
- 创建Conversation结构体
- 包含对方用户信息、最后一条消息、未读消息数等
- 实现Codable协议

### 创建跳蚤市场模型

**第一步：创建FleaMarketItem.swift**
- 在Models文件夹中创建FleaMarketItem结构体
- 定义商品属性：id、title、description、category、price、city、images等
- 创建商品状态枚举：available、sold、removed
- 实现Codable协议

---

## 第六部分：用户认证模块开发

### 创建登录界面

**第一步：创建LoginView.swift**
- 在Views/Auth文件夹中创建LoginView
- 使用SwiftUI的VStack布局，垂直排列元素
- 添加应用Logo或标题
- 添加邮箱输入框：使用TextField，设置键盘类型为emailAddress
- 添加密码输入框：使用SecureField，隐藏输入内容
- 添加"忘记密码"链接：点击后跳转到密码重置界面（如果实现）
- 添加登录按钮：使用Button，点击后调用登录方法
- 添加"注册"链接：点击后跳转到注册界面
- 添加加载指示器：登录过程中显示，使用ProgressView

**第二步：实现登录逻辑**
- 在ViewModels文件夹中创建AuthViewModel
- AuthViewModel继承ObservableObject
- 添加@Published属性：isLoading、errorMessage、isAuthenticated
- 实现login方法：调用APIService的登录API
- 登录成功：保存Token到Keychain，保存用户信息，设置isAuthenticated为true
- 登录失败：设置errorMessage显示错误提示

**第三步：连接View和ViewModel**
- 在LoginView中使用@StateObject创建AuthViewModel实例
- 将输入框的值绑定到ViewModel的属性
- 将按钮的点击事件绑定到ViewModel的login方法
- 使用@Published属性自动更新界面

### 创建注册界面

**第一步：创建RegisterView.swift**
- 在Views/Auth文件夹中创建RegisterView
- 布局类似LoginView，但包含更多输入框
- 添加邮箱输入框
- 添加密码输入框
- 添加确认密码输入框
- 添加验证码输入框
- 添加"发送验证码"按钮
- 添加注册按钮

**第二步：实现注册逻辑**
- 在AuthViewModel中添加register方法
- 实现发送验证码功能：调用后端API发送验证码到邮箱
- 实现注册功能：验证邮箱验证码后，调用注册API
- 注册成功后自动登录

**第三步：实现表单验证**
- 验证邮箱格式
- 验证密码强度（至少8位，包含字母和数字）
- 验证两次密码是否一致
- 验证验证码是否填写
- 验证通过后才允许提交

### 实现自动登录

**第一步：修改ContentView.swift**
- 在ContentView中检查是否有保存的Token
- 如果有Token，调用验证Token的API
- Token有效则显示主界面，无效则显示登录界面
- 使用@State管理登录状态

**第二步：实现Token验证**
- 在AuthViewModel中添加validateToken方法
- 调用后端API验证Token是否有效
- 如果Token过期，清除本地Token，返回登录界面

---

## 第七部分：主界面和导航开发

### 创建底部导航栏

**第一步：创建MainTabView.swift**
- 在Views文件夹中创建MainTabView
- **导航组件选择**：
  - 当前统一使用NavigationView（保证最低版本iOS 15兼容）
  - 新功能避免写死iOS 16特性（如NavigationStack、navigationDestination）
  - 等整体升级最低版本时统一重构为NavigationStack
- 使用TabView创建底部导航栏
- 添加五个标签：
  - 首页：使用house.fill图标
  - 任务：使用list.bullet图标
  - 跳蚤市场：使用storefront.fill图标
  - 消息：使用message.fill图标
  - 我的：使用person.fill图标
- 设置选中和未选中状态的颜色

**第二步：创建各个标签对应的视图**
- 创建HomeView、TasksView、FleaMarketView、MessageView、ProfileView
- 每个视图先创建基础框架，后续逐步实现功能

### 创建首页

**第一步：创建HomeView.swift**
- 在Views/Home文件夹中创建HomeView
- 使用ScrollView实现可滚动内容
- 顶部显示欢迎信息："欢迎回来，{用户名}"
- 添加快捷操作区域：
  - "发布任务"按钮：点击后跳转到发布任务界面
  - "发布商品"按钮：点击后跳转到发布商品界面
- 添加推荐任务区域：显示推荐的任务列表
- 添加最新任务区域：显示最新的任务列表

**第二步：实现数据加载**
- 创建HomeViewModel
- 实现加载推荐任务的方法：调用后端API获取推荐任务
- 实现加载最新任务的方法：调用后端API获取最新任务
- 使用@Published属性发布数据，View自动更新

**第三步：实现下拉刷新**
- 使用refreshable修饰符实现下拉刷新
- 刷新时重新加载推荐任务和最新任务

---

## 第八部分：任务模块开发

### 创建任务列表界面

**第一步：创建TasksView.swift**
- 在Views/Tasks文件夹中创建TasksView
- 使用NavigationView包装，支持导航（遵循项目统一的导航策略，详见"主界面和导航开发"章节）
- 顶部添加搜索栏：使用SearchBar组件，支持实时搜索
- 添加筛选栏：显示分类和城市筛选按钮
- 使用LazyVStack创建任务列表，支持滚动和懒加载
- 每个任务显示为卡片样式（Card组件）

**第二步：设计任务卡片**
- 创建TaskCard组件
- 卡片包含：任务标题、任务描述（截取前100字符）、价格、城市、发布时间
- 显示任务状态标签：使用不同颜色区分（开放-绿色、进行中-蓝色、已完成-灰色）
- 显示任务分类标签
- 点击卡片跳转到任务详情

**第三步：实现分页加载**
- 在TasksViewModel中管理分页状态：currentPage、hasMore
- 实现加载更多功能：滚动到底部时自动加载下一页
- 使用LazyVStack的onAppear检测是否到达底部

### 实现任务筛选功能

**第一步：创建筛选界面**
- 创建TaskFilterView作为筛选面板
- 支持按分类筛选：显示所有分类，支持多选
- 支持按城市筛选：显示城市列表，支持搜索城市
- 支持按价格范围筛选：使用Slider选择价格范围
- 支持按时间筛选：今天、本周、本月等选项

**第二步：实现筛选逻辑**
- 在TasksViewModel中管理筛选条件
- 筛选条件改变时，重置分页，重新加载任务列表
- 将筛选条件作为参数传递给API请求

### 实现任务搜索功能

**第一步：集成搜索功能**
- 在TasksView顶部添加搜索框
- 使用@State管理搜索关键词
- 实现防抖：用户停止输入0.5秒后才执行搜索

**第二步：实现搜索逻辑**
- 在TasksViewModel中实现搜索方法
- 调用后端搜索API，传递关键词
- 显示搜索结果
- 支持清空搜索，恢复显示全部任务

### 创建任务详情界面

**第一步：创建TaskDetailView.swift**
- 在Views/Tasks文件夹中创建TaskDetailView
- 使用ScrollView实现可滚动内容
- 显示任务完整信息：
  - 任务标题（大字体）
  - 任务描述（完整内容）
  - 任务图片（支持滑动浏览，使用TabView）
  - 价格、城市、截止时间
  - 任务状态
  - 发布时间

**第二步：显示发布者信息**
- 创建发布者信息卡片
- 显示发布者头像、昵称、评分
- 添加"联系发布者"按钮，跳转到消息界面

**第三步：实现任务操作**
- 如果用户未申请，显示"申请任务"按钮
- 如果用户已申请，显示"已申请"状态
- 如果用户是发布者，显示申请者列表
- 发布者可以接受申请、拒绝申请、标记任务完成

**第四步：实现申请任务功能**
- 创建TaskDetailViewModel
- 实现申请任务方法：调用后端API
- 申请成功后，更新按钮状态
- 显示申请成功提示

### 创建发布任务界面

**第一步：创建PublishTaskView.swift**
- 在Views/Tasks文件夹中创建PublishTaskView
- 使用Form或VStack创建表单
- 添加任务标题输入框：TextField，限制最大长度
- 添加任务描述输入框：使用TextEditor，支持多行输入
- 添加任务分类选择器：使用Picker组件
- 添加价格输入框：TextField，键盘类型为decimalPad
- 添加截止时间选择器：使用DatePicker
- 添加城市选择器：显示城市列表

**第二步：实现图片上传功能**
- 添加图片选择区域：显示已选图片的网格
- 添加"添加图片"按钮：点击后调用ImagePickerService
- 选择图片后，调用APIService上传图片
- 上传成功后，将图片URL添加到图片列表
- 支持删除已选图片：点击图片上的删除按钮

**第三步：实现表单验证**
- 验证标题是否填写
- 验证描述是否填写
- 验证分类是否选择
- 验证价格是否有效（大于0）
- 验证截止时间是否在未来
- 验证城市是否选择

**第四步：实现提交功能**
- 创建PublishTaskViewModel
- 实现发布任务方法：收集所有表单数据，调用后端API
- 显示加载状态：提交过程中显示ProgressView
- 提交成功后，返回任务列表并刷新
- 提交失败时，显示错误提示

### 实现我的任务管理

**第一步：创建MyTasksView.swift**
- 在Views/Profile或Views/Tasks文件夹中创建MyTasksView
- 使用TabView创建三个标签页：
  - 我发布的：显示用户发布的任务
  - 我申请的：显示用户申请的任务
  - 我完成的：显示用户完成的任务

**第二步：实现数据加载**
- 创建MyTasksViewModel
- 实现加载我发布的任务：调用后端API，传递用户ID
- 实现加载我申请的任务：调用后端API
- 实现加载我完成的任务：调用后端API

**第三步：实现任务管理操作**
- 对于我发布的任务：支持编辑、取消、查看申请者
- 对于我申请的任务：支持取消申请
- 对于已完成的任务：支持查看详情、评价

---

## 第九部分：跳蚤市场模块开发

### 创建商品列表界面

**第一步：创建FleaMarketView.swift**
- 在Views/FleaMarket文件夹中创建FleaMarketView
- 使用LazyVGrid创建网格布局，两列或三列显示
- 每个商品显示为卡片样式

**第二步：设计商品卡片**
- 创建FleaMarketItemCard组件
- 卡片包含：商品主图（第一张图片）、商品标题、价格、城市
- 显示商品状态标签（在售、已售、下架）
- 点击卡片跳转到商品详情

**第三步：实现分页和筛选**
- 实现分页加载，类似任务列表
- 添加分类筛选：显示商品分类列表
- 添加价格筛选：支持价格范围选择
- 添加搜索功能：支持关键词搜索

### 创建商品详情界面

**第一步：创建FleaMarketItemDetailView.swift**
- 在Views/FleaMarket文件夹中创建FleaMarketItemDetailView
- 使用ScrollView实现可滚动内容
- 顶部显示商品图片轮播：使用TabView，支持滑动浏览
- 显示商品标题、描述、价格、城市、发布时间
- 显示卖家信息：头像、昵称、评分

**第二步：实现商品操作**
- 添加"联系卖家"按钮：跳转到消息界面，自动创建与卖家的对话
- 添加收藏功能（如果后端支持）
- 如果是自己的商品，显示编辑和下架按钮

### 创建发布商品界面

**第一步：创建PublishFleaMarketView.swift**
- 在Views/FleaMarket文件夹中创建PublishFleaMarketView
- 创建商品发布表单，类似发布任务界面
- 包含：商品标题、商品描述、商品分类、价格、城市
- 实现图片上传功能：支持多张图片，显示图片预览

**第二步：实现发布逻辑**
- 创建PublishFleaMarketViewModel
- 实现发布商品方法：调用后端API
- 实现表单验证
- 发布成功后返回商品列表

### 实现我的发布管理

**第一步：创建MyFleaMarketView.swift**
- 在Views/Profile或Views/FleaMarket文件夹中创建MyFleaMarketView
- 显示用户发布的商品列表
- 支持编辑商品信息
- 支持下架商品（标记为已售或删除）

---

## 第十部分：实时消息模块开发

### 创建消息列表界面

**第一步：创建MessageView.swift**
- 在Views/Message文件夹中创建MessageView
- 使用List或LazyVStack显示对话列表
- 每个对话显示为一行，包含：
  - 对方头像（圆形）
  - 对方昵称
  - 最后一条消息预览（截取前50字符）
  - 未读消息数（红色徽章，如果有未读消息）
  - 最后消息时间

**第二步：实现数据加载**
- 创建MessageViewModel
- 实现加载对话列表方法：调用后端API获取所有对话
- 按最后消息时间排序，最新的在前
- 实现下拉刷新

### 创建聊天界面

**第一步：创建ChatView.swift**
- 在Views/Message文件夹中创建ChatView
- 使用VStack分为两部分：消息列表区域和输入区域
- 消息列表使用ScrollView，支持滚动
- 输入区域固定在底部，包含文本输入框和发送按钮

**第二步：设计消息气泡**
- 创建MessageBubble组件
- 自己的消息：靠右显示，使用主色调背景
- 对方的消息：靠左显示，使用灰色背景
- 显示消息内容、发送时间、消息状态（发送中、已发送、已读）

**第三步：实现消息发送**
- 在ChatViewModel中实现发送消息方法
- 先通过WebSocket发送消息（实时）
- 同时调用后端API保存消息（持久化）
- 发送成功后，更新消息列表
- 发送失败时，显示重试按钮

**第四步：实现消息接收**
- 在ChatViewModel中监听WebSocketService的@Published属性
- 收到新消息时，判断是否属于当前对话
- 如果是，添加到消息列表并滚动到底部
- 如果不是，更新对话列表的未读消息数

**第五步：实现图片发送**
- 在输入区域添加图片选择按钮
- 选择图片后，先上传图片获取URL
- 然后发送包含图片URL的消息
- 在消息气泡中显示图片（使用AsyncImage加载）

### 实现WebSocket集成

**第一步：在应用启动时连接WebSocket**
- 在用户登录成功后，自动调用WebSocketService的connect方法
- 传递用户ID和Token
- 连接成功后，开始接收消息

**第二步：实现消息状态更新**
- 发送消息后，先显示为"发送中"状态
- 收到服务器确认后，更新为"已发送"
- 收到对方已读回执后，更新为"已读"

**第三步：实现重连机制**
- 如果WebSocket连接断开，自动尝试重连
- 使用指数退避策略：第一次重连等待1秒，第二次2秒，第三次4秒，最多重试5次
- 重连成功后，恢复消息接收


---

## 第十一部分：个人中心模块开发

### 创建个人中心界面

**第一步：创建ProfileView.swift**
- 在Views/Profile文件夹中创建ProfileView
- 顶部显示用户信息卡片：
  - 用户头像（圆形，可点击更换）
  - 用户昵称
  - 用户邮箱
  - 用户等级、积分、VIP状态（如果有）

**第二步：添加功能入口**
- 使用List或VStack创建功能列表
- 添加"我的任务"入口：点击跳转到MyTasksView
- 添加"我的发布"入口：点击跳转到MyFleaMarketView
- 添加"钱包"入口：点击跳转到钱包界面（如果实现）
- 添加"设置"入口：点击跳转到设置界面

**第三步：实现退出登录**
- 添加"退出登录"按钮
- 点击后，清除Keychain中的Token
- 清除内存中的用户信息
- 断开WebSocket连接
- 返回登录界面

### 创建设置界面

**第一步：创建SettingsView.swift**
- 在Views/Profile文件夹中创建SettingsView
- 使用List创建设置选项列表
- 添加语言切换：中文/英文，使用Picker选择
- 添加通知设置：各类通知的开关
- 添加"关于我们"：显示应用版本、开发者信息等
- 添加"隐私政策"和"服务条款"链接

**第二步：实现设置保存**
- 使用UserDefaults保存用户设置
- 语言切换后，更新应用语言（需要实现国际化）
- 通知设置保存后，更新通知权限

### 实现资料编辑

**第一步：创建EditProfileView.swift**
- 在Views/Profile文件夹中创建EditProfileView
- 创建编辑表单：昵称、简介等可编辑字段
- 实现头像更换：选择图片后上传，更新头像URL
- 实现保存功能：调用后端API更新用户信息

---

## 第十二部分：原生功能集成

### 集成相机功能

**第一步：在需要的地方调用图片选择**
- 在发布任务、发布商品、更换头像等场景，调用ImagePickerService
- 使用sheet修饰符显示图片选择器
- 用户选择图片后，获取UIImage

**第二步：处理选中的图片**
- 检查图片大小，如果过大则压缩
- 调用APIService上传图片
- 上传成功后，将图片URL用于相应功能

### 集成定位功能

**第一步：请求位置权限**
- 在需要获取位置时（如选择城市），请求位置权限
- 使用CLLocationManager请求"使用中"权限即可

**第二步：获取用户位置**
- 使用CoreLocation框架获取当前位置
- 将坐标转换为城市名称（可以使用逆地理编码或城市列表匹配）
- 在城市选择时，自动填充当前城市
- **定位失败时的回退策略**：
  - 如果定位失败或用户拒绝权限，使用默认城市（如"北京"）
  - 或者显示城市选择器，让用户手动选择
  - 不要因为定位失败而阻塞用户使用应用

### 集成推送通知

**重要说明**：iOS的通知权限不需要在Info.plist中配置Usage Description。通知权限是通过代码请求的。

**第一步：请求通知权限**
- 在应用启动时（LinkUApp.swift），调用UNUserNotificationCenter.current().requestAuthorization()
- 请求权限时，系统会自动显示权限弹窗
- 用户授权后，可以发送本地通知
- 如果需要远程推送，还需要注册远程通知

**第二步：实现本地通知**
- 创建NotificationManager类，使用UserNotifications框架
- 实现UNUserNotificationCenterDelegate协议
- 当收到新消息且应用在后台时，显示本地通知
- 通知包含发送者名称和消息预览
- 点击通知时，打开应用并跳转到对应对话

**第三步：配置远程推送（可选）**
- 在Apple Developer网站配置推送证书
- 在Xcode中启用Push Notifications capability
- **SwiftUI生命周期下的AppDelegate接入**：
  - 创建AppDelegate类，实现UIApplicationDelegate协议
  - 在LinkUApp.swift中使用@UIApplicationDelegateAdaptor注入：
    ```swift
    @main
    struct LinkUApp: App {
        @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        // ...
    }
    ```
  - 在AppDelegate中实现didRegisterForRemoteNotificationsWithDeviceToken方法
  - 获取设备Token，发送到后端
  - 实现didReceiveRemoteNotification方法处理推送消息

**第四步：处理前台通知显示**
- 实现UNUserNotificationCenterDelegate的willPresent方法
- 如果应用在前台收到通知，可以选择显示banner、声音或badge
- 根据通知类型决定是否在前台显示

**第五步：处理通知点击跳转**
- 实现UNUserNotificationCenterDelegate的didReceive方法
- 根据通知的userInfo判断通知类型（新消息、任务更新等）
- 跳转到对应的页面（消息对话、任务详情等）

---

## 第十三部分：错误处理和用户体验优化

### 实现错误处理

**第一步：统一错误处理**
- 在APIService中统一处理HTTP错误码
- **401错误处理**：
  - 优先按「Token刷新策略」尝试刷新Token（详见APIService章节）
  - 刷新失败或无refreshToken时，清除Token，返回登录界面
- 404错误：显示"未找到"提示
- 500错误：显示"服务器错误"提示
- 网络错误：显示"网络连接失败"提示

**第二步：显示错误提示**
- 使用Alert显示错误信息
- 错误信息要友好，避免显示技术性错误
- 提供重试按钮（对于可重试的操作）

### 优化加载体验

**第一步：实现加载状态**
- 在数据加载时显示ProgressView
- 使用骨架屏（Skeleton View）显示加载占位
- 避免空白页面，始终显示内容或加载状态

**第二步：实现空状态**
- 当列表为空时，显示友好的空状态提示
- 提供操作建议（如"发布第一个任务"）

### 优化交互体验

**第一步：实现下拉刷新**
- 在列表界面实现下拉刷新功能
- 使用refreshable修饰符（iOS 15+）

**第二步：实现上拉加载更多**
- 检测滚动到底部时，自动加载更多数据
- 显示"加载中"提示

**第三步：优化图片加载**
- 使用AsyncImage异步加载图片
- 显示占位图，加载完成后显示实际图片
- 实现图片缓存，避免重复下载

---

## 第十四部分：编码规范和工程化

### 编码规范

**第一步：命名约定**
- **类名和结构体名**：使用大驼峰命名（PascalCase），如TaskViewModel、APIService
- **变量和函数名**：使用小驼峰命名（camelCase），如taskList、loadTasks()
- **常量**：使用大驼峰命名，如APIBaseURL、MaxImageSize
- **文件命名**：一个View一个文件，文件名与类名一致，如TasksView.swift
- **避免中英混用**：代码中统一使用英文，用户界面显示的内容可以使用中文

**第二步：代码组织**
- View、ViewModel、Service、Model分别放在对应文件夹
- 每个功能模块有独立的文件夹
- 工具类放在Utils文件夹
- 使用Markdown风格的注释标注关键流程

**第三步：代码质量工具**
- **推荐使用SwiftLint**：统一代码风格，避免格式问题
- 在Xcode中集成SwiftLint，在构建时自动检查
- 配置.swiftlint.yml文件，定义团队统一的规则
- 可选使用SwiftFormat进行自动格式化

**第四步：注释规范**
- 关键业务逻辑必须添加注释
- 复杂算法需要说明思路
- 公共API需要添加文档注释（使用///）
- 使用MARK注释分隔代码块

### 测试策略

**第一步：单元测试**
- 针对ViewModel层编写XCTest单元测试
- 针对Service层（APIService、WebSocketService等）编写测试
- 对APIService使用URLProtocol进行网络Mock，避免依赖真实网络
- 使用Mock对象隔离依赖，测试业务逻辑
- **覆盖率要求**：关键业务模块（认证、任务、消息）单测覆盖率不低于60%

**第二步：UI测试**
- 使用XCUITest编写UI测试
- 覆盖关键用户流程：
  - 登录流程：输入邮箱密码、点击登录、验证跳转
  - 发布任务流程：填写表单、上传图片、提交
  - 发送消息流程：选择对话、输入消息、发送
- 使用Page Object模式组织UI测试代码

**第三步：集成测试**
- 测试与后端API的集成（使用测试环境）
- 测试WebSocket连接和消息收发
- 测试文件上传功能

**第四步：性能测试**
- 使用Instruments测试内存泄漏
- 测试应用启动速度（冷启动、热启动）
- 测试不同网络环境下的表现
- 测试长时间使用后的内存占用

### CI/CD和自动化构建

**第一步：配置CI/CD（推荐方案）**
- 使用GitHub Actions、GitLab CI或Jenkins
- 每次push/PR自动执行：
  - SwiftLint代码检查
  - 单元测试
  - UI测试（可选）
- 打Tag时自动构建Beta版本并上传TestFlight

**第二步：使用Fastlane（推荐）**
- 配置Fastfile，实现自动化流程
- 一键命令：`fastlane beta`（构建并上传TestFlight）
- 一键命令：`fastlane release`（构建并提交App Store）
- 自动截图、自动上传、自动填写部分metadata
- 即使暂时不实现，文档中标注"推荐方案"为后续扩展留好位置

### 日志和崩溃收集

**第一步：客户端日志策略**
- 重要操作记录日志：登录、发布任务、支付类操作
- 使用统一的日志工具（如CocoaLumberjack或os.log）
- 调试环境开启详细日志，生产环境只记录关键日志
- 日志包含：时间戳、操作类型、用户ID、错误信息

**第二步：崩溃收集**
- **推荐接入Sentry或Firebase Crashlytics**
- 所有线上崩溃都应在平台上可见
- 崩溃报告包含：堆栈信息、设备信息、用户操作路径
- 设置告警：严重崩溃立即通知开发团队

**第三步：性能监控**
- 监控API请求成功率、响应时间
- 监控应用启动时间
- 监控内存使用情况
- 使用Firebase Performance或其他性能监控工具

### 无障碍和用户体验

**第一步：支持Dynamic Type**
- 所有Text组件使用系统字体，支持Dynamic Type
- 测试不同字体大小下的界面布局
- 确保文字不会被截断

**第二步：支持VoiceOver**
- 所有交互控件必须有可读的accessibilityLabel
- 使用accessibilityHint提供操作提示
- 测试VoiceOver下的导航和操作流程

**第三步：支持深色模式**
- 颜色使用Asset Catalog，支持Light/Dark变体
- 测试浅色和深色模式下的界面显示
- 确保文字和背景有足够的对比度

**第四步：本地化支持**
- 使用Localizable.strings管理多语言文本
- 支持中文和英文切换
- 测试不同语言下的界面布局

### 数据缓存和离线策略

**第一步：缓存策略**
- **明确约定**：暂不支持离线编辑，仅做简单缓存
- **约束**：所有会改变服务器状态的操作（发布任务、修改资料、发送消息）必须在线执行
- **禁止**：失败后不做本地排队重试，避免与服务器状态不一致
- 使用URLCache缓存API响应（对于不经常变化的数据）
- 图片使用NSCache或第三方库（如Kingfisher）缓存
- 任务列表、商品列表等可以缓存，但设置过期时间（如5分钟）

**第二步：弱网处理**
- 在弱网或无网情况下，显示上一次缓存的任务列表/消息列表
- 显示"网络连接失败"提示
- 提供"重试"按钮
- 不阻塞用户查看已缓存的内容

### 隐私与合规

**第一步：数据最小化原则**
- 只采集应用功能必需的信息
- 不收集不必要的用户数据
- 定期审查数据收集范围，删除不再需要的数据

**第二步：敏感信息保护**
- 日志中不打印敏感信息：
  - 不记录Token、密码、完整邮箱地址
  - 不记录精确的个人信息（如完整手机号、身份证号）
  - 使用脱敏处理（如只显示邮箱前3位）
- 使用Keychain存储敏感信息（Token、密码等）
- 内存中的敏感信息及时清理

**第三步：权限申请规范**
- 与隐私政策的映射关系：
  - **相机权限**：用于拍摄任务/商品图片
  - **相册权限**：用于选择任务/商品图片
  - **定位权限**：用于自动填充城市、显示附近任务
  - **通知权限**：用于接收任务更新、新消息提醒
- 在设计权限申请文案时，与法务/运营确认
- 用户拒绝权限后，提供替代方案（如手动选择城市、手动上传图片）

**第四步：隐私政策链接**
- 在设置页面提供隐私政策链接
- 在首次启动时（可选）显示隐私政策同意页面
- 确保隐私政策内容与实际数据收集行为一致

### 统计与埋点

**第一步：基础事件埋点**
- 定义关键业务事件：
  - 用户行为：登录成功、注册成功、退出登录
  - 任务相关：发布任务、申请任务、完成任务、取消任务
  - 跳蚤市场：发布商品、购买商品、下架商品
  - 消息相关：发送消息、接收消息
  - 页面访问：页面进入、页面停留时长
- 使用统一的埋点SDK（如Firebase Analytics、友盟等）

**第二步：转化路径追踪**
- 追踪关键转化路径：
  - 任务发布流程：进入发布页 → 填写信息 → 上传图片 → 提交成功
  - 任务申请流程：浏览任务 → 查看详情 → 申请任务 → 申请成功
  - 消息发送流程：进入对话 → 输入消息 → 发送成功
- 记录每个节点的转化率和流失原因

**第三步：事件属性规范**
- 与后端或数据平台约定：
  - 事件名称规范（统一命名，如task_publish、message_send）
  - 事件属性定义（userId、taskId、category等）
  - 用户ID对齐（确保移动端和Web端用户ID一致）
- 建立事件字典文档，方便后续分析

**第四步：埋点实现**
- 创建AnalyticsService统一管理埋点
- 在关键操作处调用埋点方法
- 支持开发环境关闭埋点（避免测试数据污染）
- 确保埋点不影响主流程性能

---

## 第十五部分：测试和调试

### 功能测试

**第一步：测试认证流程**
- 测试登录功能：正确邮箱密码、错误邮箱密码、网络错误等情况
- 测试注册功能：正常注册、邮箱已存在、验证码错误等情况
- 测试自动登录：应用重启后是否自动登录
- 测试Token刷新：Token过期时自动刷新

**第二步：测试任务功能**
- 测试任务列表加载、筛选、搜索
- 测试任务详情查看
- 测试任务发布：正常发布、表单验证、图片上传
- 测试任务申请和管理

**第三步：测试消息功能**
- 测试WebSocket连接和断开
- 测试消息发送和接收
- 测试消息状态更新
- 测试前后台切换时的WebSocket重连
- 测试推送通知

### 性能测试

**第一步：测试应用启动速度**
- 测量冷启动时间（应用完全关闭后启动）
- 测量热启动时间（应用在后台时启动）
- 优化启动时间，减少不必要的初始化

**第二步：测试内存使用**
- 使用Instruments检测内存泄漏
- 测试长时间使用后的内存占用
- 优化图片缓存和数据结构

**第三步：测试网络性能**
- 测试不同网络环境（WiFi、4G、5G）
- 测试弱网环境下的表现
- 优化请求超时和重试机制

### 真机测试

**第一步：在真实设备上测试**
- 连接iPhone或iPad进行测试
- 测试不同iOS版本（iOS 15、16、17等）
- 测试不同设备尺寸（iPhone SE、iPhone 14 Pro Max等）

**第二步：测试权限请求**
- 测试首次请求权限时的提示
- 测试用户拒绝权限后的处理
- 测试权限被禁用后的提示

---

## 第十六部分：发布准备

### 配置应用信息

**第一步：设置应用图标和启动画面**
- 准备应用图标：各种尺寸（20pt、29pt、40pt、60pt、76pt、83.5pt等）
- 准备启动画面：使用LaunchScreen.storyboard或Assets中的启动图片
- 在Assets.xcassets中配置图标和启动画面

**第二步：配置应用信息**
- 在项目设置中配置应用名称、版本号、构建号
- 设置应用分类和年龄分级
- 配置支持的设备方向

### 配置证书和描述文件

**第一步：创建App ID**
- 在Apple Developer网站创建App ID
- Bundle Identifier要与项目中的一致

**第二步：创建证书**
- 创建开发证书（用于开发测试）
- 创建发布证书（用于App Store发布）
- 在Xcode中配置自动签名，Xcode会自动管理证书

**第三步：创建描述文件**
- 如果使用自动签名，Xcode会自动创建描述文件
- 如果使用手动签名，需要手动创建描述文件

### 准备应用截图和描述

**第一步：准备应用截图**
- 准备各种设备尺寸的截图：
  - iPhone 6.7" (iPhone 14 Pro Max等)
  - iPhone 6.5" (iPhone 11 Pro Max等)
  - iPhone 5.5" (iPhone 8 Plus等)
- 截图要展示应用的主要功能
- 至少需要3-5张截图

**第二步：编写应用描述**
- 编写应用简介（最多4000字符）
- 编写关键词（最多100字符）
- 编写更新说明
- 准备隐私政策链接

### 构建和上传

**第一步：构建Archive**
- 在Xcode中选择Product > Archive
- 等待构建完成
- 如果构建失败，查看错误信息并修复

**第二步：验证Archive**
- 在Organizer中，选择Archive
- 点击"Validate App"
- 检查是否有错误或警告

**第三步：上传到App Store Connect**
- 在Organizer中，选择Archive
- 点击"Distribute App"
- 选择"App Store Connect"
- 按照向导完成上传

**第四步：提交审核**
- 在App Store Connect中，选择应用
- 填写应用信息、上传截图
- 选择构建版本
- 提交审核

---

## 开发注意事项

### 后端API兼容性

- 所有API调用都使用现有的后端接口，无需修改后端
- 确保API请求格式与Web端一致
- 确保Token认证方式一致
- 确保WebSocket消息格式一致

### 数据同步

- 移动端与Web端共享同一后端，数据自动同步
- 用户可以在移动端和Web端无缝切换
- WebSocket确保消息实时同步

### 用户体验

- 保持与Web端功能一致（用户端功能）
- 充分利用iOS原生特性（相机、定位、推送等）
- 遵循iOS设计规范（Human Interface Guidelines）
- 考虑不同屏幕尺寸和iOS版本

### 错误处理

- 网络错误时显示友好提示
- API错误时显示具体错误信息
- 实现重试机制（对于可重试的操作）
- 记录错误日志，便于问题排查

### 安全性

- Token安全存储（使用Keychain）
- 敏感信息加密存储
- 网络请求使用HTTPS
- 实现证书锁定（Certificate Pinning，可选）

### 性能优化

- 使用懒加载，只加载可见内容
- 实现图片缓存，避免重复下载
- 优化网络请求，减少不必要的请求
- 使用异步操作，避免阻塞主线程

---

---

## 开发优先级建议

为了更高效地完成开发，建议按照以下优先级顺序进行：

### 第一阶段：核心基础（1-2周）
1. **UI设计系统**（颜色、字体、组件库、设计Token）
2. **认证模块**（登录、注册、自动登录、Token管理、Token刷新策略）
3. **主框架**（Tab导航、AppState、基础路由、状态管理边界）
4. **API服务层**（APIService、Token刷新、统一错误处理）

### 第二阶段：核心功能（3-4周）
4. **任务模块**（列表、详情、发布、我的任务）
5. **消息模块**（WebSocket集成、聊天界面、消息收发）

### 第三阶段：扩展功能（2-3周）
6. **跳蚤市场模块**（列表、详情、发布、我的发布）
7. **个人中心**（用户信息、设置、资料编辑）

### 第四阶段：优化和上线（1-2周）
8. **原生功能集成**（相机、定位、推送通知）
9. **用户体验优化**（加载状态、错误处理、空状态）
10. **测试和修复**（功能测试、性能测试、真机测试）
11. **发布准备**（应用信息、截图、提交审核）

**总计预计时间**：7-11周（根据团队规模和经验调整）

---

## 总结

本指南详细描述了LinkU iOS应用的完整开发流程，从环境搭建到功能实现，再到测试和发布。开发过程中，主要工作是：

1. **复用后端API**：所有功能都调用现有的后端接口，无需修改后端代码
2. **实现用户端功能**：专注于普通用户需要的功能，不包含客服和管理员功能
3. **原生体验**：充分利用iOS原生特性，提供最佳用户体验
4. **实时同步**：通过WebSocket实现消息实时同步，确保移动端和Web端数据一致
5. **工程化规范**：遵循编码规范，建立测试体系，配置CI/CD，确保代码质量

按照本指南的步骤和优先级建议，可以逐步完成iOS应用的开发。开发过程中，要注重用户体验和错误处理，确保应用的稳定性和易用性。同时，要遵循iOS设计规范，支持无障碍功能，适配深色模式，提供最佳的用户体验。

