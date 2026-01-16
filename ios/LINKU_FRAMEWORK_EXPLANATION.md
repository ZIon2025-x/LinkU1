# Link²Ur Framework 说明

## 📦 什么是 LinkU Framework？

**Link²Ur** 是一个**本地 Swift Package**（本地框架），包含了应用的共享代码模块。

## 🏗️ 项目架构

项目采用了**模块化架构**设计：

```
ios/
├── link2ur/                    # 主应用（实际运行的 App）
│   └── link2ur/               # 主应用代码
│       ├── link2urApp.swift   # App 入口（@main）
│       ├── Views/             # 主应用专用视图
│       └── ...
│
└── LinkU/                      # Swift Package（共享代码库）
    ├── Package.swift           # Package 定义
    ├── Models/                 # 数据模型（共享）
    ├── Views/                  # 视图组件（共享）
    ├── ViewModels/             # 视图模型（共享）
    ├── Services/               # 服务层（共享）
    └── Utils/                  # 工具类（共享）
```

## 🔗 关系说明

### 主应用引用 LinkU Package

在 `link2urApp.swift` 中：

```swift
import LinkU  // 导入 LinkU Package
```

在 `project.pbxproj` 中：

```swift
// Link²Ur 作为 Swift Package 依赖被添加到 Frameworks
1491C6B62EDF931E0054DEAA /* LinkU in Frameworks */
```

## 🎯 LinkU 的作用

### 1. **代码复用**
- 将通用的 Models、Views、ViewModels、Services 等代码打包成模块
- 主应用通过 `import LinkU` 使用这些共享代码（框架名仍为 LinkU）

### 2. **模块化管理**
- 清晰的代码组织结构
- 便于维护和测试
- 可以独立开发 LinkU Package

### 3. **架构设计**
- 分离关注点：主应用专注于应用特定的逻辑
- LinkU 提供可复用的业务逻辑和组件

## 📁 LinkU Package 包含的内容

根据 `LinkU/` 目录结构，包含：

- **Models/**: 数据模型（Task, User, Forum, Leaderboard 等）
- **Views/**: 视图组件（登录、注册、任务列表等）
- **ViewModels/**: 视图模型（业务逻辑）
- **Services/**: 服务层（API 服务、WebSocket 服务）
- **Utils/**: 工具类（常量、日期格式化、设计系统等）

## 🔍 为什么有两个 App 入口？

### LinkU/App/LinkUApp.swift
- 这是 Link²Ur Package 中的示例/测试 App
- **不是实际运行的 App**
- 可能用于：
  - Package 的独立测试
  - 开发时的预览
  - 文档示例

### link2ur/link2ur/link2urApp.swift
- **这是实际运行的 App 入口**
- 标记了 `@main`
- 导入了 `LinkU` Package 来使用共享代码

## ⚙️ 配置说明

### Package.swift

```swift
let package = Package(
    name: "LinkU",  // 框架名仍为 LinkU（技术标识符）
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "LinkU", targets: ["LinkU"])
    ],
    targets: [
        .target(name: "LinkU", path: "LinkU")
    ]
)
```

这定义了一个名为 "LinkU" 的 Swift Package，可以被其他项目引用。

### Xcode 项目配置

在 Xcode 中，LinkU 被添加为：
- **Swift Package Dependency**（本地包）
- 添加到 **Frameworks, Libraries, and Embedded Content**

## 💡 使用场景

这种架构设计适用于：

1. **多应用共享代码**
   - 如果有多个应用需要共享相同的业务逻辑
   - LinkU 可以作为共享库

2. **模块化开发**
   - 团队可以独立开发和测试 LinkU Package
   - 主应用专注于应用特定的功能

3. **代码组织**
   - 清晰的代码结构
   - 便于维护和重构

## 🔄 与主应用代码的关系

### 主应用代码（link2ur/link2ur/）
- 应用入口和生命周期管理
- 应用特定的视图和逻辑
- 配置和初始化代码

### LinkU Package（LinkU/）
- 可复用的业务逻辑
- 通用的视图组件
- 共享的数据模型和服务

## ❓ 常见问题

### Q: 为什么需要 Link²Ur Framework？
A: 这是模块化架构设计，便于代码复用和维护。如果项目只有一个应用，也可以将所有代码放在主应用中。

### Q: 可以删除 LinkU Framework 吗？
A: 可以，但需要：
1. 将 LinkU 中的代码移动到主应用
2. 移除 `import LinkU`
3. 从 Xcode 项目中移除 LinkU 依赖

### Q: LinkU 和 link2ur 有什么区别？
A: 
- **link2ur**: 主应用（实际运行的 App）
- **LinkU（框架名）**: 共享代码库（Swift Package），框架名仍为 LinkU（技术标识符）

### Q: 为什么有两个 App 文件？
A: 
- `LinkU/App/LinkUApp.swift`: Package 中的示例 App（不运行）
- `link2ur/link2ur/link2urApp.swift`: 实际运行的 App 入口

## 📚 相关文件

- `Package.swift` - LinkU Package 定义
- `link2ur/link2ur/link2urApp.swift` - 主应用入口
- `LinkU/App/LinkUApp.swift` - Package 示例 App（不运行）

---

**总结**: Link²Ur 使用名为 "LinkU" 的本地 Swift Package（框架名仍为 LinkU，技术标识符），提供共享代码给主应用使用。这是模块化架构设计，便于代码组织和复用。
