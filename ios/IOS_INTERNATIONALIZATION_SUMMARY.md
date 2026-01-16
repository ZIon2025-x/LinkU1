# iOS 国际化（i18n）实现总结

## ✅ 已完成的工作

### 1. 添加本地化键（LocalizationKey）

**文件**: `ios/link2ur/link2ur/Core/Utils/LocalizationHelper.swift`

**新增键**：
- **Onboarding（引导教程）**: 18 个键
  - `onboarding.skip` - 跳过
  - `onboarding.welcome_title` - 欢迎标题
  - `onboarding.welcome_subtitle` - 欢迎副标题
  - `onboarding.welcome_description` - 欢迎描述
  - `onboarding.publish_task_title` - 发布任务标题
  - `onboarding.publish_task_subtitle` - 发布任务副标题
  - `onboarding.publish_task_description` - 发布任务描述
  - `onboarding.accept_task_title` - 接受任务标题
  - `onboarding.accept_task_subtitle` - 接受任务副标题
  - `onboarding.accept_task_description` - 接受任务描述
  - `onboarding.secure_payment_title` - 安全支付标题
  - `onboarding.secure_payment_subtitle` - 安全支付副标题
  - `onboarding.secure_payment_description` - 安全支付描述
  - `onboarding.community_title` - 社区互动标题
  - `onboarding.community_subtitle` - 社区互动副标题
  - `onboarding.community_description` - 社区互动描述
  - `onboarding.personalization_title` - 个性化设置标题
  - `onboarding.personalization_subtitle` - 个性化设置副标题
  - `onboarding.preferred_city` - 常用城市
  - `onboarding.preferred_task_types` - 感兴趣的任务类型
  - `onboarding.preferred_task_types_optional` - 感兴趣的任务类型（可选）
  - `onboarding.enable_notifications` - 启用通知
  - `onboarding.enable_notifications_description` - 启用通知描述
  - `onboarding.get_started` - 开始使用
  - `onboarding.previous` - 上一步

- **Spotlight（搜索）**: 4 个键
  - `spotlight.task` - 任务
  - `spotlight.tasks` - 任务（复数）
  - `spotlight.expert` - 任务达人
  - `spotlight.quick_action` - 快速操作

- **Shortcuts（快捷指令）**: 12 个键
  - `shortcuts.publish_task` - 发布任务
  - `shortcuts.publish_task_description` - 发布任务描述
  - `shortcuts.view_my_tasks` - 查看我的任务
  - `shortcuts.view_my_tasks_description` - 查看我的任务描述
  - `shortcuts.view_messages` - 查看消息
  - `shortcuts.view_messages_description` - 查看消息描述
  - `shortcuts.search_tasks` - 搜索任务
  - `shortcuts.search_tasks_description` - 搜索任务描述
  - `shortcuts.view_flea_market` - 查看跳蚤市场
  - `shortcuts.view_flea_market_description` - 查看跳蚤市场描述
  - `shortcuts.view_forum` - 查看论坛
  - `shortcuts.view_forum_description` - 查看论坛描述

### 2. 更新本地化文件

**文件**：
- `ios/link2ur/link2ur/en.lproj/Localizable.strings` - 英文
- `ios/link2ur/link2ur/zh-Hans.lproj/Localizable.strings` - 简体中文
- `ios/link2ur/link2ur/zh-Hant.lproj/Localizable.strings` - 繁体中文

**内容**：
- 所有新功能相关的文本都已添加到三个语言文件中
- 支持英文、简体中文、繁体中文

### 3. 更新代码使用本地化

**文件**: `ios/link2ur/link2ur/Views/Onboarding/OnboardingView.swift`
- ✅ 所有硬编码的中文文本已替换为本地化字符串
- ✅ 使用 `LocalizationKey` 枚举访问本地化字符串
- ✅ 任务类型列表使用本地化的任务类型

**文件**: `ios/link2ur/link2ur/Core/Intents/AppShortcuts.swift`
- ✅ 所有 `AppIntent` 的 `title` 和 `description` 使用 `LocalizedStringResource`
- ✅ `AppShortcut` 的 `phrases` 包含中英文短语，支持多语言 Siri 识别
- ✅ `shortTitle` 使用 `LocalizedStringResource`

**文件**: `ios/link2ur/link2ur/Core/Utils/SpotlightIndexer.swift`
- ✅ 关键词使用本地化字符串
- ✅ 搜索索引的描述文本支持多语言

---

## 📋 支持的语言

- ✅ **英文** (en)
- ✅ **简体中文** (zh-Hans)
- ✅ **繁体中文** (zh-Hant)

---

## 🔧 使用方法

### 在代码中使用本地化

```swift
// 方式1：使用 LocalizationKey 枚举
Text(LocalizationKey.onboardingSkip.localized)

// 方式2：使用 LocalizationHelper
Text(LocalizationHelper.localized("onboarding.skip"))

// 方式3：使用 LocalizedStringResource（App Intents）
static var title: LocalizedStringResource = LocalizedStringResource(
    "shortcuts.publish_task",
    defaultValue: "Publish Task"
)
```

### 添加新的本地化字符串

1. **在 `LocalizationKey` 枚举中添加新键**：
```swift
case newFeatureTitle = "new_feature.title"
```

2. **在三个本地化文件中添加翻译**：
```strings
// en.lproj/Localizable.strings
"new_feature.title" = "New Feature";

// zh-Hans.lproj/Localizable.strings
"new_feature.title" = "新功能";

// zh-Hant.lproj/Localizable.strings
"new_feature.title" = "新功能";
```

3. **在代码中使用**：
```swift
Text(LocalizationKey.newFeatureTitle.localized)
```

---

## 📝 注意事项

1. **App Shortcuts 短语**：
   - `phrases` 参数需要包含多种语言的短语
   - Siri 会根据用户的语言环境自动识别
   - 建议同时包含中英文短语，提高识别率

2. **Spotlight 搜索**：
   - 关键词会自动使用本地化字符串
   - 搜索结果会根据用户语言环境显示

3. **引导教程**：
   - 所有文本都已本地化
   - 任务类型使用系统已有的任务类型本地化

4. **测试建议**：
   - 在不同语言环境下测试应用
   - 测试 Siri 快捷指令的多语言识别
   - 测试 Spotlight 搜索的多语言显示

---

## ✅ 完成状态

- ✅ 引导教程（Onboarding）完全国际化
- ✅ Spotlight 搜索集成国际化
- ✅ 快捷指令（Shortcuts）国际化
- ✅ 所有新功能的文本都已本地化
- ✅ 支持英文、简体中文、繁体中文

---

## 🎯 下一步

如果需要添加更多语言支持：

1. 创建新的 `.lproj` 文件夹（如 `fr.lproj` 用于法语）
2. 复制 `Localizable.strings` 文件
3. 翻译所有字符串
4. 在 `LocalizationHelper` 的 `supportedLanguages` 中添加新语言
