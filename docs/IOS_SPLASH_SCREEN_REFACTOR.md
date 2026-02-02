# iOS 启动屏重构开发文档

本文档描述将 iOS 应用启动视频替换为静态启动图 + Logo + 平台介绍文案 + 加载动画的开发方案，供设计与开发协作使用。

---

## 一、背景与目标

### 1.1 当前实现

| 项目 | 说明 |
|------|------|
| 展示形式 | `VideoLoadingView` 全屏循环播放视频 |
| 视频文件 | linker1.mp4、linker2.mp4、linker3.mp4、linker4.mp4（随机选择） |
| 展示时机 | `appState.isCheckingLoginStatus == true` 时显示 |
| 交互 | 右上角「跳过」按钮；左下角 Logo；中部「Link to your world」文案 |

### 1.2 目标方案

| 项目 | 说明 |
|------|------|
| 展示形式 | 静态背景图 + Logo + 平台介绍文案 + 加载动画 |
| 目的 | 在后台检查登录状态时提供加载反馈，加载完成后自动进入主界面 |
| 优势 | 包体更小、加载更快、体验更可控 |

---

## 二、设计规范

### 2.1 启动图内容

启动图（或背景 + 叠加元素）应包含：

1. **背景**
   - 建议：品牌主色、浅色渐变或纯色
   - 可选：若品牌有统一背景图，可使用单张静态图

2. **Logo**
   - 位置：居中偏上，或沿用当前左下角
   - 资源：使用现有 `Logo` 图集（Assets.xcassets/Logo.imageset）

3. **平台介绍文案**
   - 示例：`Link to your world`（英文）或自定义 Slogan
   - 样式：与当前设计保持一致（蓝色主色，「world」部分可带底色）

### 2.2 图片规格建议

| 用途 | 建议尺寸 | 格式 | 说明 |
|------|----------|------|------|
| 全屏背景图（可选） | 1284 × 2778（6.5 寸屏） | PNG / JPEG | 按最大分辨率准备，系统会缩放 |
| Logo | 按 Assets 中 Logo 图集 | PNG（透明） | 已有资源 |
| @2x / @3x | 视具体资源而定 | PNG | 若单独做启动图，需提供多倍图 |

### 2.3 加载动画

| 类型 | 说明 | 实现方式 |
|------|------|----------|
| 环形进度条 | Logo 下方环形旋转 | SwiftUI `ProgressView(style: .circular)` 或自定义 |
| 线性进度条 | 底部细长进度条 | `ProgressView(style: .linear)` 或自定义 |
| 脉冲/呼吸 | 小圆点或 Logo 淡入淡出 | `Animation.repeatForever` |
| 骨架屏 | 简化版骨架 | 可选，与品牌风格统一 |

推荐：Logo 下方环形加载动画，颜色与品牌主色一致。

---

## 三、技术实现

### 3.1 涉及文件

| 文件 | 说明 |
|------|------|
| `ios/link2ur/link2ur/App/ContentView.swift` | 启动屏展示逻辑，需替换 VideoLoadingView |
| `ios/link2ur/link2ur/Views/Components/VideoPlayerView.swift` | 含 VideoLoadingView，可保留或移除相关引用 |
| `ios/link2ur/link2ur/Assets.xcassets/` | 新增启动背景图（SplashBackground.imageset） |
| `ios/link2ur/link2ur/en.lproj/Localizable.strings` | 文案多语言（如有） |
| `ios/link2ur/link2ur/zh-Hans.lproj/Localizable.strings` | 同上 |

### 3.2 核心逻辑

```
appState.isCheckingLoginStatus == true
    → 显示 SplashView（静态图 + Logo + 文案 + 加载动画）
    → AppState.checkLoginStatus() 完成后置为 false
    → 自动切换至 MainTabView
```

- 无需倒计时，加载完成即切换。
- 可设置最小展示时间（如 0.5–1 秒），避免一闪而过。

### 3.3 新增组件结构

```swift
// SplashView 结构示意
struct SplashView: View {
    var body: some View {
        ZStack {
            // 1. 背景（纯色 / 渐变 / 图片）
            SplashBackgroundView()
            
            // 2. Logo
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
            
            // 3. 平台介绍文案
            VStack {
                // "Link to your world" 或自定义
            }
            
            // 4. 加载动画
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.primary))
                .scaleEffect(1.2)
        }
    }
}
```

### 3.4 ContentView 修改要点

**当前代码（需替换部分）：**

```swift
if appState.isCheckingLoginStatus {
    ZStack {
        VideoLoadingView(...)
        // 跳过按钮、文案、Logo 等
    }
}
```

**修改后：**

```swift
if appState.isCheckingLoginStatus {
    SplashView()
    // 移除「跳过」按钮（加载完成自动进入）
    // 或保留，用于网络异常时手动进入
}
```

### 3.5 状态与生命周期

| 状态 | 说明 |
|------|------|
| `isCheckingLoginStatus = true` | App 启动，检查 Keychain + 可选网络校验 |
| `isCheckingLoginStatus = false` | 检查完成，进入主界面 |
| `onChange(of: appState.isCheckingLoginStatus)` | 切换完成后可在此调用 `requestNotificationPermissionAfterVideo()` 等逻辑 |

---

## 四、资源清单

### 4.1 需准备资源

| 资源 | 类型 | 是否必选 |
|------|------|----------|
| 启动背景图 | 图片 | 可选（可用纯色/渐变代替） |
| Logo | 已有 | 必选 |
| 平台介绍文案 | 文案 | 必选 |

### 4.2 可移除资源（实施后）

| 资源 | 说明 |
|------|------|
| linker1.mp4 ~ linker4.mp4 | 启动视频文件 |
| linker.mp4 | 备用视频（若仅启动使用可移除） |

移除视频可显著减小 App 体积（通常数 MB 至数十 MB）。

---

## 五、可选增强

### 5.1 最小展示时间

```swift
@State private var minDisplayElapsed = false

// 启动时启动 0.8 秒定时器
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        minDisplayElapsed = true
    }
}

// 切换条件：isCheckingLoginStatus == false && minDisplayElapsed
```

### 5.2 网络异常处理

- 若登录检查依赖网络，可设置超时（如 5 秒）。
- 超时后可显示「跳过」或「重试」，允许用户手动进入。

### 5.3 多语言

平台介绍文案若需多语言，使用 `Localizable.strings`：

```
// en
"splash.slogan" = "Link to your world";

// zh-Hans
"splash.slogan" = "连接你的世界";
```

---

## 六、验收要点

- [ ] 启动时展示静态启动图（或纯色/渐变背景）+ Logo + 文案
- [ ] 加载动画可见且与品牌风格一致
- [ ] 登录检查完成后自动进入主界面，无额外倒计时
- [ ] （可选）最小展示时间避免一闪而过
- [ ] 已移除或停用启动视频相关代码与资源
- [ ] App 体积有可感知的减小

---

## 七、参考

- 当前启动逻辑：`ContentView.swift` 第 14–96 行
- 登录状态检查：`AppState.swift` 中 `checkLoginStatus()` 与 `isCheckingLoginStatus`
- 视频相关组件：`VideoPlayerView.swift` 中 `VideoLoadingView`
