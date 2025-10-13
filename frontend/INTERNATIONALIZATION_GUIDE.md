# 国际化功能使用指南 / Internationalization Guide

## 概述 / Overview

本网站现在支持完整的国际化功能，包括语言后缀URL（如 `/en`、`/zh`）和自动语言检测。

This website now supports full internationalization features, including language suffix URLs (like `/en`, `/zh`) and automatic language detection.

## 功能特性 / Features

### 1. 语言后缀URL / Language Suffix URLs
- 英文页面：`/en/`、`/en/tasks`、`/en/about` 等
- 中文页面：`/zh/`、`/zh/tasks`、`/zh/about` 等
- 自动重定向：访问 `/tasks` 会自动重定向到 `/en/tasks`（默认语言）

### 2. 自动语言检测 / Automatic Language Detection
- 根据浏览器语言设置自动选择语言
- 支持中文（zh）和英文（en）
- 默认语言为英文

### 3. 语言切换 / Language Switching
- 用户可以通过语言切换器更改语言
- 切换语言时会保持当前页面路径
- 语言设置会保存到本地存储

## 使用方法 / Usage

### 1. 使用本地化链接 / Using Localized Links

```tsx
import LocalizedLink from '../components/LocalizedLink';

// 自动添加当前语言前缀
<LocalizedLink to="/tasks">任务页面</LocalizedLink>
// 在英文环境下会渲染为：<a href="/en/tasks">任务页面</a>
// 在中文环境下会渲染为：<a href="/zh/tasks">任务页面</a>
```

### 2. 使用本地化导航 / Using Localized Navigation

```tsx
import { useLocalizedNavigation } from '../hooks/useLocalizedNavigation';

const MyComponent = () => {
  const { navigate } = useLocalizedNavigation();
  
  const handleClick = () => {
    // 自动添加当前语言前缀
    navigate('/tasks');
    // 在英文环境下会导航到：/en/tasks
    // 在中文环境下会导航到：/zh/tasks
  };
};
```

### 3. 使用本地化Navigate组件 / Using Localized Navigate Component

```tsx
import LocalizedNavigate from '../components/LocalizedNavigate';

// 自动添加当前语言前缀
<LocalizedNavigate to="/about" replace />
```

### 4. 获取语言切换URL / Getting Language Switch URLs

```tsx
import { getLanguageSwitchUrl } from '../utils/i18n';
import { useLocation } from 'react-router-dom';

const MyComponent = () => {
  const location = useLocation();
  
  const switchToEnglish = () => {
    const newUrl = getLanguageSwitchUrl(location.pathname, 'en');
    window.location.href = newUrl;
  };
  
  const switchToChinese = () => {
    const newUrl = getLanguageSwitchUrl(location.pathname, 'zh');
    window.location.href = newUrl;
  };
};
```

## 技术实现 / Technical Implementation

### 1. 路由结构 / Route Structure
- 所有路由都支持语言前缀
- 旧链接会自动重定向到带语言前缀的新链接
- 根路径 `/` 会重定向到默认语言首页

### 2. 语言检测 / Language Detection
- 从URL路径中提取语言代码
- 支持浏览器语言检测
- 回退到默认语言（英文）

### 3. 状态管理 / State Management
- LanguageContext 从URL检测语言
- 语言切换时自动更新URL
- 本地存储语言偏好

## 测试 / Testing

访问 `/en/i18n-test` 或 `/zh/i18n-test` 来测试国际化功能：

Visit `/en/i18n-test` or `/zh/i18n-test` to test the internationalization features:

- 语言切换测试
- 翻译功能测试
- 本地化链接测试
- 编程式导航测试

## 支持的页面 / Supported Pages

所有主要页面都支持国际化：

All major pages support internationalization:

- `/en/` 或 `/zh/` - 首页 / Home
- `/en/tasks` 或 `/zh/tasks` - 任务页面 / Tasks
- `/en/about` 或 `/zh/about` - 关于页面 / About
- `/en/join-us` 或 `/zh/join-us` - 加入我们 / Join Us
- `/en/profile` 或 `/zh/profile` - 个人资料 / Profile
- 等等... / And more...

## 注意事项 / Notes

1. **SEO友好**：每个语言版本都有独立的URL，有利于搜索引擎优化
2. **用户体验**：语言切换时保持当前页面路径
3. **向后兼容**：旧链接会自动重定向到新格式
4. **性能优化**：语言检测和切换都经过优化

## 开发指南 / Development Guide

### 添加新页面 / Adding New Pages

1. 在 `App.tsx` 中添加新路由，支持语言前缀
2. 使用 `LocalizedLink` 或 `useLocalizedNavigation` 进行导航
3. 确保所有文本都使用翻译函数 `t()`

### 添加新语言 / Adding New Languages

1. 在 `frontend/src/utils/i18n.ts` 中添加新语言代码
2. 创建对应的翻译文件（如 `fr.json`）
3. 更新 `LanguageContext` 和 `LanguageSwitcher`

---

*最后更新：2024年12月 / Last Updated: December 2024*
