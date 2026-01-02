# Stripe Elements Appearance 自定义配置

## 概述

根据 Stripe 官方文档 [Elements Appearance API](https://docs.stripe.com/elements/appearance-api)，我们已经优化了 Payment Element 的外观配置，使其更好地匹配网站设计系统。

## 当前配置

### 主题选择
- **主题**: `stripe`（默认主题，提供最佳兼容性）

### 变量配置

我们根据网站设计系统（`frontend/src/styles/theme.ts`）配置了以下变量：

```typescript
variables: {
  colorPrimary: '#1890ff',        // 主色调（与网站主题一致）
  colorBackground: '#ffffff',      // 背景色
  colorText: 'rgba(0, 0, 0, 0.85)', // 文本颜色
  colorDanger: '#ff4d4f',          // 错误颜色
  colorSuccess: '#52c41a',         // 成功颜色
  fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, "Noto Sans", sans-serif', // 字体（与网站一致）
  fontSizeBase: '16px',            // 基础字体大小（确保移动端输入框至少 16px）
  spacingUnit: '4px',              // 基础间距单位
  borderRadius: '4px',             // 圆角（与网站一致）
}
```

### 输入框和标签配置

```typescript
inputs: 'spaced',  // 输入框之间有间距
labels: 'auto',    // 标签自动调整位置
```

## 设计系统对齐

### 颜色系统
- ✅ **主色调**: `#1890ff` - 与网站 `theme.colors.primary` 一致
- ✅ **背景色**: `#ffffff` - 与网站 `theme.colors.background.default` 一致
- ✅ **文本颜色**: `rgba(0, 0, 0, 0.85)` - 与网站 `theme.colors.text.primary` 一致
- ✅ **错误颜色**: `#ff4d4f` - 与网站 `theme.colors.error` 一致
- ✅ **成功颜色**: `#52c41a` - 与网站 `theme.colors.success` 一致

### 字体系统
- ✅ **字体族**: 系统字体栈 - 与网站 `theme.typography.fontFamily` 一致
- ✅ **基础字体大小**: `16px` - 确保移动端输入框至少 16px（避免 iOS Safari 自动缩放）

### 间距和圆角
- ✅ **基础间距单位**: `4px` - 与网站 `theme.spacing.xs` 一致
- ✅ **圆角**: `4px` - 与网站 `theme.borderRadius.small` 一致

## 实现位置

### PaymentModal.tsx
```typescript
<Elements 
  stripe={stripePromise} 
  options={{
    clientSecret: paymentData.client_secret,
    appearance: {
      theme: 'stripe',
      variables: { ... },
      inputs: 'spaced',
      labels: 'auto',
    },
    loader: 'auto',
  } as StripeElementsOptions}
>
```

### StripePaymentForm.tsx
```typescript
const options: StripeElementsOptions = {
  clientSecret: props.clientSecret,
  appearance: {
    theme: 'stripe',
    variables: { ... },
    inputs: 'spaced',
    labels: 'auto',
  },
  loader: 'auto',
};
```

## 优势

### 1. 视觉一致性
- ✅ Payment Element 的外观与网站整体设计保持一致
- ✅ 用户感觉支付表单是网站的一部分，而不是第三方组件

### 2. 用户体验
- ✅ 移动端输入框字体大小至少 16px，避免 iOS Safari 自动缩放
- ✅ 输入框间距合理，提高可读性
- ✅ 标签自动调整位置，适应不同输入框样式

### 3. 品牌一致性
- ✅ 使用网站主色调，强化品牌识别
- ✅ 字体和圆角与网站设计系统一致

## 未来优化建议

### 1. 使用 Rules 进行精细自定义

如果需要更精细的样式控制，可以使用 `rules` 选项：

```typescript
appearance: {
  theme: 'stripe',
  variables: { ... },
  rules: {
    '.Tab': {
      border: '1px solid #d9d9d9',
      borderRadius: '4px',
    },
    '.Tab--selected': {
      borderColor: '#1890ff',
      boxShadow: '0 0 0 2px var(--colorPrimary)',
    },
    '.Input--invalid': {
      boxShadow: '0 1px 1px 0 rgba(0, 0, 0, 0.07), 0 0 0 2px var(--colorDanger)',
    },
  },
}
```

### 2. 响应式设计

可以考虑根据屏幕尺寸调整配置：

```typescript
const appearance = {
  theme: 'stripe',
  variables: {
    ...baseVariables,
    fontSizeBase: window.innerWidth < 768 ? '16px' : '16px', // 移动端确保至少 16px
  },
};
```

### 3. 暗色模式支持

如果网站支持暗色模式，可以动态切换：

```typescript
const appearance = {
  theme: isDarkMode ? 'night' : 'stripe',
  variables: {
    ...(isDarkMode ? darkModeVariables : lightModeVariables),
  },
};
```

## 参考文档

- [Stripe Elements Appearance API](https://docs.stripe.com/elements/appearance-api)
- [网站设计系统](frontend/src/styles/theme.ts)

## 总结

我们已经成功将 Stripe Payment Element 的外观配置与网站设计系统对齐，提供了：
- ✅ 视觉一致性
- ✅ 品牌识别
- ✅ 良好的用户体验
- ✅ 移动端优化

所有配置都遵循 Stripe 官方最佳实践，并符合网站设计规范。

