# Spotlight 和 Siri 搜索问题修复

## 问题描述

1. **Spotlight 搜索问题**：在手机搜索中搜索 "link2ur" 搜不出来应用
2. **Siri 问题**：和 Siri 说"打开 link to you"无法打开应用

## 问题原因

### 1. Spotlight 搜索问题

- 应用名称是 **"Link²Ur"**（包含特殊字符²）
- 用户搜索 **"link2ur"**（没有²）可能无法匹配
- Spotlight 索引可能需要时间更新

### 2. Siri 问题

- 应用名称是 **"Link²Ur"**，但用户说 **"link to you"**
- Siri 无法识别"link to you"这个发音
- 之前没有配置"打开应用"的 Siri Shortcut

## 已实施的修复

### 1. 添加了"打开应用"的 Siri Shortcut ✅

在 `AppShortcuts.swift` 中添加了 `OpenAppIntent`，支持以下说法：

**中文**：
- "打开 Link²Ur"
- "打开 link to you"
- "打开 link2ur"
- "打开 link 2 u r"
- "启动 Link²Ur"
- "运行 Link²Ur"

**英文**：
- "Open Link²Ur"
- "Open link to you"
- "Open link2ur"
- "Open link 2 u r"
- "Launch Link²Ur"
- "Start Link²Ur"

### 2. 添加了 Spotlight 搜索关键词 ✅

在 `Link-Ur-Info.plist` 中添加了 `CFBundleKeywords`，包含：
- link2ur
- link to you
- link 2 u r
- link²ur
- 任务、跳蚤市场、论坛（中文关键词）
- task、flea market、forum（英文关键词）

## 使用方法

### 使用 Siri 打开应用

现在你可以对 Siri 说：
- **"打开 link to you"** ✅
- **"打开 link2ur"** ✅
- **"打开 Link²Ur"** ✅
- **"启动 link to you"** ✅

### 使用 Spotlight 搜索应用

1. **下拉主屏幕**或**向右滑动**打开 Spotlight 搜索
2. 输入以下任一关键词：
   - `link2ur`
   - `link to you`
   - `link²ur`
   - `任务`、`跳蚤市场`、`论坛`

## 注意事项

### 1. 需要重新构建应用

修复后需要：
1. 在 Xcode 中重新构建应用
2. 安装到设备上
3. 等待 Spotlight 索引更新（可能需要几分钟）

### 2. Spotlight 索引更新

如果搜索仍然不工作：
1. **重启设备**（强制重新索引）
2. **等待几分钟**（让 Spotlight 重新索引应用）
3. **尝试搜索完整名称**："Link²Ur"（包含特殊字符）

### 3. Siri 可能需要学习

首次使用新的 Siri Shortcut 时：
1. Siri 可能需要一些时间来学习新的短语
2. 如果第一次不工作，多试几次
3. 确保设备语言设置与应用语言匹配

## 测试步骤

### 测试 Siri

1. 按住 Home 键或说"Hey Siri"
2. 说："打开 link to you"
3. 应该能打开应用 ✅

### 测试 Spotlight

1. 下拉主屏幕打开 Spotlight
2. 输入 "link2ur"
3. 应该能看到应用 ✅

## 如果仍然不工作

### 检查清单

- [ ] 应用已重新构建并安装
- [ ] 设备已重启（可选，但推荐）
- [ ] 等待了几分钟让索引更新
- [ ] 尝试搜索完整名称 "Link²Ur"
- [ ] 检查应用是否真的安装在设备上

### 手动重建 Spotlight 索引

如果问题持续存在：

1. **设置** → **Siri 与搜索**
2. 找到 **Link²Ur** 应用
3. 确保以下选项已开启：
   - ✅ 在搜索中显示
   - ✅ 建议 App
   - ✅ 锁定屏幕建议

### 联系支持

如果问题仍然存在，可能需要：
1. 检查 Xcode 项目配置
2. 确认 Info.plist 配置正确
3. 检查应用是否正确签名和安装

---

**最后更新**：2025年1月27日
