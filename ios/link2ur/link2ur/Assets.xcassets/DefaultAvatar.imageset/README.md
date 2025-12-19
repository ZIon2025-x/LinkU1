# 默认头像图片添加说明

## 如何添加默认头像图片

1. 将你选择的头像图片重命名为 `DefaultAvatar.png`
2. 将图片文件放到这个目录：`Assets.xcassets/DefaultAvatar.imageset/`
3. 在 Xcode 中：
   - 打开项目
   - 在左侧文件导航器中找到 `Assets.xcassets` → `DefaultAvatar`
   - 将图片拖拽到 1x 的位置
   - 如果需要，也可以添加 2x 和 3x 版本（用于高分辨率屏幕）

## 图片要求

- 格式：PNG（推荐）或 JPG
- 尺寸：建议 200x200 像素或更大（正方形）
- 内容：圆形头像，背景透明或纯色

## 使用方式

代码已经配置好，当用户没有头像 URL 时，会自动使用这个默认头像。
