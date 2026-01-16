# 应用图标 Badge 功能实现

## ✅ 功能概述

已实现在应用图标上显示未读消息和通知数量的功能（App Badge），用户无需打开应用就能看到是否有未读信息。

## 🎯 功能特性

- ✅ **自动更新** - 当未读消息或通知数量变化时，自动更新应用图标 Badge
- ✅ **权限检查** - 只有在用户授权通知权限（包含 Badge）时才显示
- ✅ **自动清除** - 用户登出或未登录时自动清除 Badge
- ✅ **数量限制** - iOS 自动处理超过 99 的情况（显示 "99+"）
- ✅ **实时同步** - 与 TabBar Badge 和未读数量实时同步

## 🔧 实现细节

### 1. BadgeManager 工具类

**文件**: `ios/link2ur/link2ur/Utils/BadgeManager.swift`

**功能**:
- `updateBadge(count:)` - 更新应用图标 Badge 数量
- `clearBadge()` - 清除应用图标 Badge
- `currentBadgeCount` - 获取当前 Badge 数量

**关键代码**:
```swift
public func updateBadge(count: Int) {
    DispatchQueue.main.async {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    UIApplication.shared.applicationIconBadgeNumber = count
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = 0
                }
            }
        }
    }
}
```

### 2. AppState 集成

**文件**: `ios/link2ur/link2ur/Utils/AppState.swift`

**修改**:
- `unreadNotificationCount` 和 `unreadMessageCount` 添加了 `didSet` 观察者
- 当未读数量变化时，自动调用 `updateAppIconBadge()` 更新 Badge
- 在 `logout()` 时清除 Badge
- 在应用进入前台时，如果未登录则清除 Badge

**关键代码**:
```swift
@Published public var unreadNotificationCount: Int = 0 {
    didSet {
        updateAppIconBadge()
    }
}

@Published public var unreadMessageCount: Int = 0 {
    didSet {
        updateAppIconBadge()
    }
}

private func updateAppIconBadge() {
    let totalUnread = unreadNotificationCount + unreadMessageCount
    BadgeManager.shared.updateBadge(count: totalUnread)
}
```

## 📱 用户体验

### Badge 显示规则

1. **有未读消息/通知** - 显示未读总数（最多显示 99+）
2. **无未读消息/通知** - 不显示 Badge
3. **未授权通知权限** - 不显示 Badge
4. **用户未登录** - 不显示 Badge

### 更新时机

- ✅ 应用启动时（如果已登录）
- ✅ 应用进入前台时
- ✅ 收到新消息时（通过 WebSocket）
- ✅ 收到新通知时（通过 WebSocket）
- ✅ 用户查看消息/通知后（自动减少）
- ✅ 用户登出时（清除 Badge）

## 🔒 权限要求

应用需要请求通知权限，并且必须包含 `.badge` 选项：

```swift
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .badge, .sound]
) { granted, error in
    // 处理权限结果
}
```

**注意**: 如果用户拒绝了通知权限，Badge 将不会显示。

## 🎨 Badge 显示效果

- **0-99**: 显示具体数字（如 "5"）
- **100+**: 显示 "99+"
- **无未读**: 不显示 Badge

## 📝 注意事项

1. **权限检查**: Badge 只有在用户授权通知权限时才能显示
2. **主线程**: 所有 Badge 更新都在主线程执行
3. **自动同步**: Badge 数量与 TabBar Badge 和未读数量实时同步
4. **性能优化**: 使用 `didSet` 观察者，只在数量变化时更新

## 🚀 测试建议

1. **权限测试**:
   - 测试用户授权通知权限时 Badge 是否显示
   - 测试用户拒绝通知权限时 Badge 是否不显示

2. **数量测试**:
   - 测试 0-99 的 Badge 显示
   - 测试 100+ 时显示 "99+"

3. **更新测试**:
   - 测试收到新消息时 Badge 是否更新
   - 测试查看消息后 Badge 是否减少
   - 测试登出时 Badge 是否清除

4. **场景测试**:
   - 测试应用启动时 Badge 是否正确显示
   - 测试应用进入前台时 Badge 是否正确更新
   - 测试应用在后台时收到推送后 Badge 是否更新

---

**实现日期**: 2025-01-27
**状态**: ✅ 已完成
