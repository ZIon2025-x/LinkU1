# Logger 当前状态说明

## 当前行为

### 开发环境（npm start）

**会显示在开发者工具控制台的日志**：
- ✅ `logger.log()` - 会显示
- ✅ `logger.debug()` - 会显示
- ✅ `logger.info()` - 会显示
- ✅ `logger.warn()` - 会显示
- ✅ `logger.error()` - 会显示
- ✅ `console.error()` - 会显示（用于错误追踪）
- ✅ `console.warn()` - 会显示（用于警告）

### 生产环境（npm run build）

**会显示在开发者工具控制台的日志**：
- ❌ `logger.log()` - **不会显示**
- ❌ `logger.debug()` - **不会显示**
- ❌ `logger.info()` - **不会显示**
- ✅ `logger.warn()` - **会显示**（重要警告）
- ✅ `logger.error()` - **会显示**（错误信息）
- ✅ `console.error()` - **会显示**（错误追踪）
- ✅ `console.warn()` - **会显示**（警告信息）

**注意**：`console.log` 和 `console.debug` 在生产环境被覆盖为空函数，即使代码中直接调用也不会输出。

## 当前代码中的 console.error/warn

以下位置仍在使用 `console.error` 和 `console.warn`（这些会显示）：

1. `src/pages/Login.tsx` - 2 处 `console.error`（登录错误）
2. `src/components/Captcha.tsx` - 2 处 `console.error`（CAPTCHA 重置错误）
3. `src/components/payment/StripePaymentForm.tsx` - 1 处 `console.error`（支付错误）
4. `src/components/stripe/StripeConnectOnboarding.tsx` - 1 处 `console.error`（账户状态检查错误）
5. `src/api.ts` - 使用 `logger.error/warn`（会显示）
6. 其他错误处理代码中的 `console.error`

## 总结

### 开发环境
- **有日志**：所有 `logger.log/debug/info` 和 `console.error/warn` 都会显示

### 生产环境
- **部分日志**：
  - ❌ `logger.log/debug/info` - **不显示**
  - ✅ `logger.warn/error` - **显示**
  - ✅ `console.error/warn` - **显示**

## 如果需要完全禁用所有日志

如果你希望在生产环境**完全没有任何日志**（包括 error 和 warn），可以修改 `logger.ts`：

```typescript
// 完全禁用所有日志（生产环境）
if (isProduction && typeof window !== 'undefined') {
  console.log = () => {};
  console.debug = () => {};
  console.info = () => {};
  console.warn = () => {};  // 可选：也禁用警告
  console.error = () => {};  // 可选：也禁用错误（不推荐）
}
```

**注意**：完全禁用 `console.error` 不推荐，因为：
1. 错误信息对调试很重要
2. 错误监控服务可能需要这些信息
3. 用户报告问题时，错误日志很有帮助

## 建议

**当前配置是最佳实践**：
- ✅ 生产环境禁用调试日志（log/debug/info）
- ✅ 保留错误和警告日志（error/warn）
- ✅ 开发环境保留所有日志用于调试
