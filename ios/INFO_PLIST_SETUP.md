# Info.plist 配置说明 - 分享功能

## 问题说明

**不是开发者账号的问题！** 分享功能不工作是因为缺少 `LSApplicationQueriesSchemes` 配置。

iOS 9+ 要求应用在 `Info.plist` 中声明要查询的 URL Schemes，才能检测其他应用是否已安装。

## 解决方案

### 方法一：在 Xcode 项目设置中添加（推荐）

1. 打开 Xcode 项目
2. 选择项目 → 选择 Target `Link²Ur`
3. 点击 **Info** 标签页
4. 找到 **Custom iOS Target Properties** 部分
5. 点击 **+** 按钮添加新项
6. 输入键名：`LSApplicationQueriesSchemes`
7. 类型选择：**Array**
8. 展开这个数组，添加以下字符串项：
   - `weixin` (微信)
   - `mqqapi` (QQ)
   - `instagram` (Instagram)
   - `fb` (Facebook)
   - `twitter` (X/Twitter)
   - `weibosdk` (微博)

### 方法二：创建 Info.plist 文件

如果方法一不行，可以创建一个 Info.plist 文件：

1. 在 Xcode 中，右键点击 `link2ur` 文件夹
2. 选择 **New File...**
3. 选择 **Property List**
4. 命名为 `Info.plist`
5. 添加以下内容：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>weixin</string>
        <string>mqqapi</string>
        <string>instagram</string>
        <string>fb</string>
        <string>twitter</string>
        <string>weibosdk</string>
    </array>
</dict>
</plist>
```

6. 在项目设置中，将 `GENERATE_INFOPLIST_FILE` 设置为 `NO`
7. 在 **Info** 标签页的 **Custom iOS Target Properties** 中，设置 `INFOPLIST_FILE` 为 `link2ur/Info.plist`

## 验证配置

配置完成后：

1. 清理项目：**Product → Clean Build Folder** (Shift + Command + K)
2. 重新编译运行
3. 测试分享功能

## 为什么需要这个配置？

- iOS 9+ 的安全限制：应用不能随意查询其他应用是否已安装
- 必须在 `Info.plist` 中声明要查询的 URL Schemes
- 没有这个配置，`canOpenURL()` 会返回 `false`，即使应用已安装
- **这与开发者账号无关**，所有应用都需要这个配置

## 常见问题

**Q: 为什么微信和QQ点击没反应？**  
A: 因为没有配置 `LSApplicationQueriesSchemes`，系统无法检测这些应用是否已安装，URL Scheme 调用失败。

**Q: 为什么系统分享面板出现又消失？**  
A: 可能是因为分享内容格式问题，或者缺少必要的配置。配置了 `LSApplicationQueriesSchemes` 后应该能正常工作。

**Q: 需要开发者账号吗？**  
A: **不需要！** 这个配置与开发者账号无关，所有应用都需要。
