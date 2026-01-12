# 微信和QQ SDK集成指南

## 📋 前置要求

### 1. 注册开发者账号（免费）

#### 微信开放平台
1. 访问 [微信开放平台](https://open.weixin.qq.com/)
2. 注册开发者账号（需要企业认证或个人认证）
3. 创建移动应用，获取：
   - **AppID**（应用ID）
   - **AppSecret**（应用密钥）
   - **Universal Link**（通用链接）

#### QQ互联平台
1. 访问 [QQ互联](https://connect.qq.com/)
2. 注册开发者账号
3. 创建移动应用，获取：
   - **AppID**（应用ID）
   - **AppKey**（应用密钥）

### 2. 下载SDK

#### 微信SDK
- 下载地址：[微信iOS SDK](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)
- 下载 `WechatOpenSDK.framework`

#### QQ SDK
- 下载地址：[QQ iOS SDK](https://wiki.connect.qq.com/ios_sdk%E4%B8%8B%E8%BD%BD)
- 下载 `TencentOpenAPI.framework` 和相关文件

## 🔧 集成步骤

### 步骤1：添加SDK到项目

#### 方法A：手动添加（推荐）

1. **添加微信SDK**
   - 将下载的 `WechatOpenSDK.framework` 拖拽到 Xcode 项目中
   - 选择 "Copy items if needed"
   - 在 Target → General → Frameworks, Libraries, and Embedded Content 中，确保 `WechatOpenSDK.framework` 设置为 "Embed & Sign"

2. **添加QQ SDK**
   - 将下载的 `TencentOpenAPI.framework` 和相关文件拖拽到 Xcode 项目中
   - 选择 "Copy items if needed"
   - 在 Target → General → Frameworks, Libraries, and Embedded Content 中，确保 `TencentOpenAPI.framework` 设置为 "Embed & Sign"

#### 方法B：使用CocoaPods（可选）

如果项目支持CocoaPods，可以添加：

```ruby
pod 'WechatOpenSDK'
pod 'TencentOpenAPI'
```

### 步骤2：配置Build Settings

在 Xcode 项目设置中：

1. 选择 Target → Build Settings
2. 搜索 "Other Linker Flags"
3. 添加 `-ObjC` 和 `-all_load`

### 步骤3：更新Info.plist

在 `Link-Ur-Info.plist` 中添加以下配置：

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <!-- 微信 -->
    <string>weixin</string>
    <string>weixinULAPI</string>
    <!-- QQ -->
    <string>mqq</string>
    <string>mqqapi</string>
    <string>mqqopensdkapiV2</string>
    <string>mqqopensdkapiV3</string>
    <string>mqqopensdkapiV4</string>
    <string>mqqopensdknopasteboard</string>
    <string>mqqopensdknopasteboardios16</string>
    <string>mqzone</string>
    <string>mqqopensdklaunchminiapp</string>
    <string>tim</string>
</array>

<key>CFBundleURLTypes</key>
<array>
    <!-- 微信 URL Scheme -->
    <dict>
        <key>CFBundleURLName</key>
        <string>com.link2ur.wechat</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_WECHAT_APPID</string>
        </array>
    </dict>
    <!-- QQ URL Scheme -->
    <dict>
        <key>CFBundleURLName</key>
        <string>com.link2ur.qq</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>tencentYOUR_QQ_APPID</string>
        </array>
    </dict>
</array>
```

**重要**：将 `YOUR_WECHAT_APPID` 和 `YOUR_QQ_APPID` 替换为你在开放平台获取的实际AppID。

### 步骤4：配置Universal Link（微信必需）

1. **在微信开放平台配置Universal Link**
   - 格式：`https://yourdomain.com/wechat/`
   - 确保域名已通过验证

2. **在项目中配置Associated Domains**
   - 在 Xcode 中，选择 Target → Signing & Capabilities
   - 点击 "+ Capability"
   - 添加 "Associated Domains"
   - 添加：`applinks:yourdomain.com`

3. **创建apple-app-site-association文件**
   - 在服务器上创建 `/.well-known/apple-app-site-association` 文件
   - 配置格式参考微信开放平台文档

### 步骤5：初始化SDK

在 `link2urApp.swift` 或 `AppDelegate` 中初始化：

```swift
import WechatOpenSDK
import TencentOpenAPI

@main
struct Link2UrApp: App {
    init() {
        // 初始化微信SDK
        WXApi.registerApp("YOUR_WECHAT_APPID", universalLink: "https://yourdomain.com/wechat/")
        
        // 初始化QQ SDK（可选，如果需要登录功能）
        // TencentOAuth 会在需要时自动初始化
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 步骤6：处理回调

在 `link2urApp.swift` 中添加URL处理：

```swift
import SwiftUI

@main
struct Link2UrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 处理微信回调
        if WXApi.handleOpen(url, delegate: WeChatShareManager.shared) {
            return true
        }
        
        // 处理QQ回调
        if TencentOAuth.handleOpen(url) {
            return true
        }
        
        return false
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // 处理Universal Link（微信）
        if WXApi.handleOpenUniversalLink(userActivity, delegate: WeChatShareManager.shared) {
            return true
        }
        return false
    }
}
```

## 📝 使用说明

集成完成后，`CustomShareHelper` 会自动使用SDK进行分享，无需修改调用代码。

分享功能会自动：
- ✅ 直接分享到微信好友
- ✅ 直接分享到朋友圈
- ✅ 直接分享到QQ好友
- ✅ 直接分享到QQ空间
- ✅ 传递完整的标题、描述、图片和链接

## ⚠️ 注意事项

1. **AppID配置**：确保在代码和Info.plist中使用正确的AppID
2. **Universal Link**：微信分享必须配置Universal Link，否则无法正常工作
3. **测试环境**：在真机上测试，模拟器无法测试分享功能
4. **审核要求**：分享功能需要通过微信和QQ的审核才能正式使用

## 🔍 故障排查

### 问题1：分享后没有反应
- 检查AppID是否正确
- 检查Universal Link是否配置正确
- 检查Info.plist中的URL Scheme配置

### 问题2：朋友圈分享失败
- 确保使用微信SDK而不是URL Scheme
- 检查分享内容格式是否正确

### 问题3：编译错误
- 确保SDK已正确添加到项目
- 检查Other Linker Flags设置
- 确保Framework设置为"Embed & Sign"

## 📚 参考文档

- [微信开放平台文档](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)
- [QQ互联文档](https://wiki.connect.qq.com/)
