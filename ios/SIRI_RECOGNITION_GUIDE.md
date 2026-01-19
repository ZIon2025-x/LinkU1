# Siri 识别应用名称指南

## 问题描述

1. **当您对 Siri 说 "打开 link to you"** 时，Siri 可能会问您选择哪一个应用（包括 LinkedIn、Trolink 等），无法直接识别到 Link²Ur 应用。

2. **当您对 Siri 说 "打开 Link²Ur"** 时，Siri 可能无法识别，因为特殊字符²在语音识别中无法被正确识别。

## 原因分析

1. **应用名称是 "Link²Ur"**（包含特殊字符²）
2. **特殊字符²无法通过语音识别** - Siri 无法理解 "²" 这个字符的发音
3. **用户说的是 "link to you"**（发音变体），但 Siri 无法自动匹配到应用名称
4. **Apple 要求** App Shortcuts 短语必须包含 `${applicationName}`，不能直接写 "打开 link to you"

## 解决方案

### 方案 1：使用更容易识别的说法（强烈推荐）✅

**重要**：由于 "Link²Ur" 包含特殊字符²，Siri 无法识别。请使用以下更容易识别的说法：

**中文**：
- ✅ **"打开 link2ur"**（使用数字2，最推荐）
- ✅ **"打开 link 2 u r"**（分开念，也很容易识别）
- ❌ "打开 Link²Ur"（不推荐，Siri 无法识别特殊字符²）

**英文**：
- ✅ **"Open link2ur"**（使用数字2，最推荐）
- ✅ **"Open link 2 u r"**（分开念，也很容易识别）
- ❌ "Open Link²Ur"（不推荐，Siri 无法识别特殊字符²）

### 方案 2：在 Shortcuts 应用中手动创建快捷指令 ✅

1. 打开 **Shortcuts（快捷指令）** 应用
2. 点击右上角的 **"+"** 创建新快捷指令
3. 添加操作：**"打开 App"**
4. 选择 **Link²Ur** 应用
5. 点击快捷指令名称，设置为 **"打开 link to you"**
6. 点击右上角的 **"..."** → **"添加到 Siri"**
7. 录制语音指令：**"打开 link to you"**

现在您就可以对 Siri 说 **"打开 link to you"** 了！

### 方案 3：训练 Siri 识别（需要时间，不推荐）

**注意**：由于 "Link²Ur" 包含特殊字符，Siri 无法识别，此方案效果有限。

1. 多次对 Siri 说 **"打开 link2ur"**（使用数字2）
2. 当 Siri 询问时，明确选择 **Link²Ur** 应用
3. 经过一段时间的学习，Siri 可能会更好地识别 "link2ur" 这个说法

### 方案 4：使用 Spotlight 搜索

如果 Siri 无法识别，可以使用 Spotlight 搜索：

1. **下拉主屏幕**打开 Spotlight
2. 输入 **"link2ur"** 或 **"link to you"**
3. 点击应用图标打开

## 当前配置

### App Shortcuts 已配置的短语

以下短语已经配置，可以直接使用：

**中文**：
- "打开 ${applicationName}"
- "启动 ${applicationName}"
- "运行 ${applicationName}"
- "使用 ${applicationName}"

**英文**：
- "Open ${applicationName}"
- "Launch ${applicationName}"
- "Start ${applicationName}"
- "Use ${applicationName}"

注意：`${applicationName}` 会被替换为 "Link²Ur"

### Info.plist 搜索关键词

已配置以下关键词，有助于 Spotlight 搜索：
- link2ur
- link to you
- link 2 u r
- link²ur

## 最佳实践建议

### 对于用户

1. **强烈推荐使用**："打开 link2ur"（使用数字2，Siri 最容易识别）
2. **备选方案**："打开 link 2 u r"（分开念）
3. **如果想使用** "link to you"，建议在 Shortcuts 应用中手动创建快捷指令
4. **使用 Spotlight 搜索**作为备选方案
5. **避免使用**："打开 Link²Ur"（Siri 无法识别特殊字符²）

### 对于开发者

1. **应用名称**保持为 "Link²Ur"（品牌一致性）
2. **搜索关键词**已包含 "link to you"（帮助 Spotlight 搜索）
3. **App Shortcuts** 已配置标准短语（符合 Apple 要求）

## 技术限制

根据 Apple 的 App Shortcuts 规范：

1. ✅ **每个短语必须包含** `${applicationName}`
2. ❌ **不能直接写** "打开 link to you"（不包含 `${applicationName}`）
3. ✅ **`${applicationName}` 会被替换**为实际应用名称 "Link²Ur"

因此，无法在代码中直接添加 "打开 link to you" 这样的短语，需要通过 Shortcuts 应用手动创建。

## 测试步骤

### 测试标准短语

1. 对 Siri 说：**"打开 link2ur"**（使用数字2）
2. 应该能直接打开应用 ✅

**注意**：说 "打开 Link²Ur" 可能无法识别，因为 Siri 无法识别特殊字符²

### 测试手动创建的快捷指令

1. 在 Shortcuts 应用中创建快捷指令
2. 对 Siri 说：**"打开 link to you"**
3. 应该能打开应用 ✅

### 测试 Spotlight 搜索

1. 下拉主屏幕打开 Spotlight
2. 输入：**"link2ur"** 或 **"link to you"**
3. 应该能看到应用 ✅

## 总结

- ✅ **强烈推荐**："打开 link2ur"（使用数字2，Siri 最容易识别）
- ✅ **备选方案**："打开 link 2 u r"（分开念）
- ✅ **如果想用 "link to you"**：在 Shortcuts 应用中手动创建快捷指令
- ✅ **搜索功能**：使用 Spotlight 搜索应用
- ❌ **避免使用**："打开 Link²Ur"（Siri 无法识别特殊字符²）
- ❌ **代码限制**：无法在 App Shortcuts 中直接添加不包含 `${applicationName}` 的短语

## 关键要点

**最重要**：由于应用名称包含特殊字符²，Siri 无法识别 "Link²Ur" 这个名称。请使用 **"link2ur"**（数字2）来与 Siri 交互，这是最可靠的方式。

---

**最后更新**：2026年1月18日
