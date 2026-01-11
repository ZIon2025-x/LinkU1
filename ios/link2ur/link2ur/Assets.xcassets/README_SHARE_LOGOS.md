# 分享平台 Logo 说明

## 需要添加的 Logo 图片

为了让分享预览显示真实的平台 logo，需要在以下目录中添加对应的 PNG 图片文件：

### 微信相关
- `WeChatLogo.imageset/WeChatLogo.png` - 微信 logo（建议尺寸：120x120px，透明背景）
- `WeChatMomentsLogo.imageset/WeChatMomentsLogo.png` - 微信朋友圈 logo（建议尺寸：120x120px，透明背景）

### QQ 相关
- `QQLogo.imageset/QQLogo.png` - QQ logo（建议尺寸：120x120px，透明背景）
- `QZoneLogo.imageset/QZoneLogo.png` - QQ空间 logo（建议尺寸：120x120px，透明背景）

### 其他社交平台
- `WeiboLogo.imageset/WeiboLogo.png` - 微博 logo（建议尺寸：120x120px，透明背景）
- `FacebookLogo.imageset/FacebookLogo.png` - Facebook logo（建议尺寸：120x120px，透明背景）
- `XLogo.imageset/XLogo.png` - X logo（原 Twitter，建议尺寸：120x120px，透明背景）
- `InstagramLogo.imageset/InstagramLogo.png` - Instagram logo（建议尺寸：120x120px，透明背景）

## 获取 Logo 的方式

1. **官方渠道**（强烈推荐）：
   - **微信**：访问 [微信开放平台](https://open.weixin.qq.com/) 的品牌资源中心
   - **QQ**：访问 [QQ 开放平台](https://open.qq.com/) 的品牌资源中心
   - **微博**：访问 [微博开放平台](https://open.weibo.com/) 的品牌资源中心
   - **Facebook**：访问 [Facebook 品牌资源中心](https://en.facebookbrand.com/) 下载官方 logo
   - **X (原 Twitter)**：访问 [X 品牌资源中心](https://about.x.com/en/who-we-are/brand-toolkit) 或 [X 开发者文档](https://developer.x.com/) 下载官方 logo
   - **Instagram**：访问 [Instagram 品牌资源中心](https://en.instagram-brand.com/) 下载官方 logo

2. **注意事项**：
   - ⚠️ **必须使用官方提供的 logo**，符合品牌规范
   - ⚠️ 使用非官方 logo 可能导致：
     - 违反品牌使用规范
     - 用户识别度降低
     - 版权问题
   - 建议使用透明背景的 PNG 格式
   - 图片尺寸建议为 120x120px（1x），系统会自动适配 2x 和 3x

3. **如何添加图片**：
   - 在 Xcode 中打开项目
   - 找到 `Assets.xcassets` → 对应的图片集（如 `WeChatMomentsLogo`）
   - 将 PNG 图片拖拽到 1x 位置
   - 系统会自动适配 2x 和 3x 版本

## 图片要求

- 格式：PNG（支持透明背景）
- 尺寸：建议 120x120px（1x），系统会自动生成 2x 和 3x 版本
- 背景：透明
- 内容：仅包含 logo，无多余装饰

## 代码说明

代码已经配置为优先使用自定义 logo，如果图片不存在，会自动回退到系统图标。因此：
- 如果添加了 logo 图片，会显示真实的平台 logo
- 如果没有添加，会显示系统图标作为后备方案
