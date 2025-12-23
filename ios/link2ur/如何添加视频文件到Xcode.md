# 如何在 Xcode 中添加 linker.mp4 视频文件

## 📋 步骤说明

### 方法一：通过拖拽添加（推荐）

1. **打开 Xcode 项目**
   - 在 Finder 中找到项目文件夹
   - 双击 `link2ur.xcodeproj` 文件（或 `.xcworkspace` 如果使用 CocoaPods）

2. **找到视频文件位置**
   - 视频文件已经在：`link2ur/link2ur/linker.mp4`
   - 在 Finder 中打开这个文件所在的文件夹

3. **在 Xcode 中添加文件**
   - 在 Xcode 左侧的**项目导航器**（Project Navigator）中
   - 找到 `link2ur` 文件夹（蓝色文件夹图标）
   - **右键点击** `link2ur` 文件夹
   - 选择 **"Add Files to 'link2ur'..."**（添加到项目）

4. **选择文件**
   - 在弹出的文件选择对话框中
   - 导航到 `link2ur/link2ur/` 文件夹
   - 选择 `linker.mp4` 文件
   - **重要选项**：
     - ✅ 勾选 **"Copy items if needed"**（如果需要复制文件）
     - ✅ 在 **"Add to targets"** 部分，确保勾选了 **"link2ur"** target
     - 选择 **"Create groups"**（不是 "Create folder references"）
   - 点击 **"Add"** 按钮

5. **验证文件已添加**
   - 在 Xcode 的项目导航器中，你应该能看到 `linker.mp4` 文件
   - 点击文件，在右侧的 **"File Inspector"**（文件检查器）中
   - 确认 **"Target Membership"** 中勾选了 **"link2ur"**

### 方法二：直接拖拽（更简单）

1. **打开 Xcode 和 Finder**
   - 在 Finder 中打开 `link2ur/link2ur/` 文件夹
   - 在 Xcode 中打开项目

2. **拖拽文件**
   - 从 Finder 中**拖拽** `linker.mp4` 文件
   - **拖到** Xcode 左侧项目导航器中的 `link2ur` 文件夹内
   - 释放鼠标

3. **确认选项**
   - 在弹出的对话框中：
     - ✅ 勾选 **"Copy items if needed"**
     - ✅ 勾选 **"Add to targets: link2ur"**
     - 选择 **"Create groups"**
   - 点击 **"Finish"**

## ✅ 验证是否成功

### 检查方法：

1. **在 Xcode 中查看**
   - 在项目导航器中能看到 `linker.mp4` 文件
   - 文件图标应该是视频图标（不是问号或红色）

2. **检查 Target Membership**
   - 点击 `linker.mp4` 文件
   - 在右侧面板的 **"File Inspector"** 标签中
   - 查看 **"Target Membership"** 部分
   - 确保 **"link2ur"** 被勾选 ✅

3. **运行应用测试**
   - 运行应用（⌘R 或点击运行按钮）
   - 在加载界面应该能看到视频播放
   - 如果看不到视频，检查 Xcode 控制台是否有错误信息

## 🔧 如果遇到问题

### 问题1：找不到文件
- **解决**：确保文件路径正确，文件确实存在于 `link2ur/link2ur/linker.mp4`

### 问题2：视频不播放
- **检查**：
  1. 文件是否添加到 Target Membership
  2. 文件大小是否过大（建议小于 10MB）
  3. 视频格式是否为 MP4（H.264 编码）

### 问题3：文件显示为红色（找不到）
- **解决**：
  1. 删除项目中的引用（右键 → Delete → Remove Reference）
  2. 重新按照步骤添加文件

## 📝 注意事项

- 视频文件会被包含在应用的 Bundle 中，会增加应用大小
- 建议视频文件大小控制在 5-10MB 以内
- 视频会自动循环播放，并且是静音的
- 如果视频文件很大，考虑压缩视频或使用更短的视频

## 🎬 视频要求

- **格式**：MP4（H.264 编码）
- **大小**：建议 5-10MB 以内
- **分辨率**：建议 1080p 或更低（以减小文件大小）
- **时长**：建议 3-10 秒（循环播放）

---

**完成这些步骤后，视频就会在应用的加载界面中播放了！** 🎉

