# 后端错误码与 iOS 国际化说明

本文档说明后端错误响应如何与 iOS 等客户端配合，实现多语言错误展示。

## 响应格式

后端统一返回如下 JSON 格式：

```json
{
  "error": true,
  "message": "可选的兜底文案（供未实现 i18n 的客户端使用）",
  "error_code": "STRIPE_SETUP_REQUIRED",
  "status_code": 428
}
```

- `error_code`：稳定错误标识，供客户端查表展示本地化文案
- `message`：兜底文案，建议客户端优先使用 `error_code` 对应的本地化字符串

## 推荐用法

### 1. 显式传递 error_code（推荐）

新业务错误应使用 `raise_http_error_with_code`：

```python
from app.error_handlers import raise_http_error_with_code

raise_http_error_with_code(
    message="您的收款账户尚未完成设置。请先完成收款账户设置。",
    status_code=428,
    error_code="STRIPE_SETUP_REQUIRED"
)
```

### 2. 隐式推断（兼容旧代码）

沿用 `HTTPException(detail="...")` 时，`get_error_code_from_detail` 会根据 `detail` 内容推断 `error_code`。常见映射示例：

| 文案关键词 | 推断的 error_code |
|-----------|-------------------|
| 收款账户、Stripe Connect | STRIPE_SETUP_REQUIRED |
| 请通知接受人、请联系卖家/任务达人 | STRIPE_OTHER_PARTY_NOT_SETUP |
| 任务尚未支付 | TASK_NOT_PAID |
| 已经申请过 | TASK_ALREADY_APPLIED |
| 该邮箱已被注册 | EMAIL_ALREADY_EXISTS |
| ... | 见 `error_handlers.py` 中 `get_error_code_from_detail` |

## iOS 客户端对接

1. 解析响应中的 `error_code`
2. 在 `LocalizationHelper.forErrorCode()` 中查找对应 `LocalizationKey`
3. 若找到，使用 `Localizable.strings` 中的本地化文案
4. 若未找到，使用 `message` 作为兜底

## 已支持的 error_code（Stripe/收款相关）

| error_code | 含义 |
|------------|------|
| STRIPE_SETUP_REQUIRED | 当前用户需完成收款账户设置 |
| STRIPE_OTHER_PARTY_NOT_SETUP | 对方（接受人/卖家/达人）需完成收款账户设置 |
| STRIPE_ACCOUNT_NOT_VERIFIED | 收款账户未完成验证 |
| STRIPE_ACCOUNT_INVALID | 收款账户无效 |
| STRIPE_VERIFICATION_FAILED | 收款账户验证失败 |
| STRIPE_DISPUTE_FROZEN | 任务因 Stripe 争议已冻结 |

## 新增 error_code 步骤

1. **后端**：在 `raise_http_error_with_code` 中使用新 `error_code`，或在 `get_error_code_from_detail` 中增加推断规则
2. **iOS**：在 `LocalizationHelper.swift` 中增加 `LocalizationKey` 和 `forErrorCode` 映射
3. **iOS**：在 `zh-Hans`、`zh-Hant`、`en` 的 `Localizable.strings` 中添加对应文案
