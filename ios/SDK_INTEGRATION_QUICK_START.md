# 微信和QQ SDK集成快速开始

## ✅ 代码已准备完成

所有代码已经准备好，现在只需要完成以下步骤即可使用SDK分享功能。

## 📋 必须完成的步骤

### 1. 注册开发者账号并获取AppID（免费）

#### 微信开放平台
1. 访问 [微信开放平台](https://open.weixin.qq.com/)
2. 注册并创建移动应用
3. 获取 **AppID** 和 **Universal Link**
4. 配置Universal Link域名（必需）

#### QQ互联平台
1. 访问 [QQ互联](https://connect.qq.com/)
2. 注册并创建移动应用
3. 获取 **AppID**

### 2. 下载并添加SDK到项目

#### 下载SDK
- **微信SDK**: [下载地址](https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html)
- **QQ SDK**: [下载地址](https://wiki.connect.qq.com/ios_sdk%E4%B8%8B%E8%BD%BD)

#### 添加到Xcode项目
1. 将下载的 `WechatOpenSDK.framework` 拖拽到项目中
2. 将下载的 `TencentOpenAPI.framework` 拖拽到项目中
3. 在 Target → General → Frameworks, Libraries, and Embedded Content 中：
   - 确保两个Framework都设置为 **"Embed & Sign"**

### 3. 配置Build Settings

在 Xcode 中：
1. 选择 Target → Build Settings
2. 搜索 "Other Linker Flags"
3. 添加：`-ObjC` 和 `-all_load`

### 4. 配置URL Types（在Xcode中）

1. 选择 Target → Info
2. 展开 **URL Types**
3. 添加两个URL Type：

   **微信URL Type:**
   - Identifier: `com.link2ur.wechat`
   - URL Schemes: `YOUR_WECHAT_APPID`（替换为实际的微信AppID）

   **QQ URL Type:**
   - Identifier: `com.link2ur.qq`
   - URL Schemes: `tencentYOUR_QQ_APPID`（替换为实际的QQ AppID，注意前面要加"tencent"）

### 5. 配置Universal Link（微信必需）

1. 在 Xcode 中，选择 Target → Signing & Capabilities
2. 点击 "+ Capability"
3. 添加 "Associated Domains"
4. 添加：`applinks:yourdomain.com`（替换为你的域名）

5. 在服务器上创建 `/.well-known/apple-app-site-association` 文件
   - 参考微信开放平台文档配置格式

### 6. 初始化SDK

在 `link2urApp.swift` 中，找到以下代码并替换：

```swift
#if canImport(WechatOpenSDK)
// 注意：需要替换为实际的微信AppID和Universal Link
// WXApi.registerApp("YOUR_WECHAT_APPID", universalLink: "https://yourdomain.com/wechat/")
#endif
```

替换为：

```swift
#if canImport(WechatOpenSDK)
WXApi.registerApp("你的微信AppID", universalLink: "https://你的域名.com/wechat/")
#endif
```

## 🎉 完成！

完成以上步骤后，重新编译运行项目，分享功能就会使用SDK了！

## ⚠️ 注意事项

1. **Universal Link是必需的**：微信分享必须配置Universal Link，否则无法正常工作
2. **真机测试**：分享功能必须在真机上测试，模拟器无法测试
3. **审核要求**：分享功能需要通过微信和QQ的审核才能正式使用
4. **降级处理**：如果SDK未集成或分享失败，代码会自动降级使用系统分享面板

## 🔍 验证

1. 运行应用
2. 点击分享按钮
3. 选择"微信"或"朋友圈"
4. 应该直接打开微信并显示分享内容（而不是系统分享面板）

## 📚 详细文档

更多详细信息请参考：`WECHAT_QQ_SDK_INTEGRATION.md`
