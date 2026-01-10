# 自定义分享面板配置说明

## 概述

已实现类似小红书的自定义分享面板，支持分享到微信、朋友圈、QQ、Instagram、Facebook、Twitter、微博等平台。

## 功能特性

1. **自定义分享面板**：在预览框中直接显示分享按钮，无需使用系统分享面板
2. **应用检测**：自动检测已安装的应用，只显示可用的分享选项
3. **多平台支持**：支持微信、朋友圈、QQ、QQ空间、Instagram、Facebook、Twitter、微博等
4. **智能降级**：如果应用未安装，自动使用网页分享或系统分享面板

## 配置要求

### 1. 添加 URL Scheme 查询权限

由于 iOS 9+ 的安全限制，需要在 `Info.plist` 中添加 `LSApplicationQueriesSchemes` 来查询其他应用是否已安装。

**在 Xcode 中配置：**

1. 打开项目设置
2. 选择 Target → Info
3. 添加 `LSApplicationQueriesSchemes` (Array)
4. 添加以下 URL Schemes：

```
weixin
mqqapi
instagram
fb
twitter
weibosdk
```

**或者直接在 Info.plist 中添加：**

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>weixin</string>
    <string>mqqapi</string>
    <string>instagram</string>
    <string>fb</string>
    <string>twitter</string>
    <string>weibosdk</string>
</array>
```

### 2. 微信分享说明

微信分享使用系统分享面板（`UIActivityViewController`），因为：
- 微信 SDK 需要注册 AppID 和配置
- 系统分享面板会自动识别微信，并提供微信和朋友圈选项
- 这是最可靠的方式，确保分享内容正确显示（包括图片、标题、描述等）

### 3. 其他平台分享

- **QQ/QQ空间**：使用 URL Scheme `mqqapi://`
- **Instagram**：图片分享需要先保存到相册，然后打开 Instagram
- **Facebook/Twitter/微博**：优先使用 App，未安装则使用网页分享
- **复制链接**：直接复制到剪贴板
- **更多**：使用系统分享面板

## 使用方式

分享面板会在任务详情页和活动详情页的分享预览框中自动显示。用户点击分享按钮后：

1. 显示预览卡片（图片、标题、描述）
2. 显示自定义分享面板（4列网格布局）
3. 用户选择分享平台
4. 自动执行分享并关闭面板

## 代码结构

- `CustomShareHelper.swift`：分享逻辑和平台检测
- `CustomSharePanel.swift`：分享面板 UI 组件
- `TaskShareSheet.swift`：任务分享预览框（已集成自定义分享面板）
- `ActivityShareSheet.swift`：活动分享预览框（已集成自定义分享面板）

## 注意事项

1. **微信分享**：由于微信 SDK 的限制，微信分享仍使用系统分享面板，但会在自定义面板中显示"微信"和"朋友圈"按钮
2. **应用检测**：如果应用未安装，按钮会显示为半透明状态，点击后会使用网页分享或系统分享面板
3. **图片分享**：Instagram 分享图片需要先保存到相册，需要相册访问权限
4. **URL Scheme**：某些平台的 URL Scheme 可能会变化，如果分享失败，请检查并更新

## 测试建议

1. 在不同设备上测试（已安装/未安装相关应用）
2. 测试各个平台的分享功能
3. 测试图片加载和分享
4. 测试网络异常情况下的降级处理
