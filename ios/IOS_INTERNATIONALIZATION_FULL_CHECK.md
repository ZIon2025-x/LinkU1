# iOS 国际化完整检查报告

检查时间：2026-02-04  
范围：枚举完善度、Localizable.strings key 完善度、硬编码文案

---

## 一、枚举完善度（LocalizationKey）

| 项目 | 结果 |
|------|------|
| **枚举 case 数量** | **1465** 个 |
| **en.lproj 有效 key 数** | **1466** 个 |
| **枚举与 en 一致性** | 基本一致 |

### 差异说明

- 枚举使用的 key 为 `stripe.connect_load_failed`，与代码一致。
- `en.lproj` / `zh-Hans.lproj` 中另存在历史 key **`stripe_connect.load_failed`**（未被枚举使用），建议在 .strings 中删除或保留仅作兼容，避免混淆。
- 枚举已覆盖当前代码中使用的全部本地化 key，**枚举本身是完善的**。

---

## 二、各语言 Localizable.strings Key 完善度

| 语言 | 有效 key 数量 | 与 en 对比 | 状态 |
|------|----------------|------------|------|
| **en** | 1466 | 基准 | ✅ 完善 |
| **zh-Hans** | 1513 | 无缺失（≥ en） | ✅ 完善 |
| **zh-Hant** | 1000 | **缺约 490 个** | ❌ 不完善 |

### zh-Hant 缺失 key 示例（部分）

以下 key 在 en / zh-Hans 中存在，在 zh-Hant 中缺失（共约 490 个）：

- `activity.apply_to_join`, `activity.confirm_apply`, `activity.continue_payment`, `activity.favorite`, `activity.person`, `activity.persons_booked`, `activity.poster`, `activity.preferred_date`, `activity.time_flexible`, `activity.time_flexible_message`, `activity.view_expert_profile`, `activity.waiting_expert_response`
- `app.about`, `app.privacy_policy`, `app.terms_of_service`, `app.version`
- `auth.countdown_seconds`
- `common.all`, `common.copied`, `common.copy`, `common.filter`, `common.load_more`, `common.long_press_to_copy`, `common.not_provided`, `common.please_select`, `common.submitting`, `common.tag_separator`, `common.tap`
- `coupon.*` 多个
- `create_task.*` 多个
- … 以及其余数百个 key

**建议**：以 `en.lproj/Localizable.strings` 为基准，对 `zh-Hant.lproj/Localizable.strings` 补全缺失 key（可先填繁体中文或暂时与 zh-Hans 同值）。

---

## 三、硬编码文案（未国际化）

以下文件中存在 **直接写在代码里的中文或英文用户可见文案**，未通过 `LocalizationKey` 或 `LocalizationHelper.localized` 使用。

### 3.1 严重（任务详情、退款、支付等核心流程）

| 文件 | 典型硬编码内容 |
|------|----------------|
| **TaskDetailView.swift** | 「确认截止时间」「支付平台服务费」「提交反驳证据」「查看历史」「查看历史记录」「任务未完成（申请退款）」「📋 退款历史」「退款原因/类型/管理员备注」「接单者反驳」「已上传 N 个证据文件」「暂无退款申请历史记录」「原因类型/退款类型/管理员备注」「审核时间/申请时间」「任务已完成」「您已完成此任务。请上传…」「文字说明不能超过500字」「单张图片不超过 5MB…」「添加图片」「上传进度」「上传中…」「确认完成任务」「确认任务完成」「您已确认此任务完成…」「申请退款」「请详细说明退款原因…」「退款原因类型 *」「退款原因详细说明 *」「退款原因至少需要10个字符」「退款类型 *」「全额退款」「部分退款」「退款金额或比例 *」「退款金额（£）」「或」「退款比例（%）」「任务金额/退款金额」「提交退款申请」「任务争议详情」「暂无争议记录」「反驳说明」「反驳说明至少需要10个字符」「最多上传5张…」「选择图片」「请确认任务完成」「即将自动确认…」「立即确认」「等待发布者确认」「（到期将自动确认）」；Section 标题：「文字说明（可选）」「证据图片（可选）」「证据文件（可选）」「完成证据（可选）」；UIAlert 标题/按钮：「撤销退款申请」「取消」「确定」「确认完成任务」「确认」等 |
| **TaskDetailCards.swift** | 「X 已完成」「截止时间」「发布时间」等 |
| **FleaMarketDetailView.swift** | 「正在准备支付…」「购买申请 (N)」「暂无购买申请」「等待卖家确认」「议价金额：£…」「议价金额:」「卖家议价:」「确定要拒绝这个购买申请吗？」 |
| **ApplePayNativeView.swift** | 「您的设备不支持 Apple Pay」「请使用其他支付方式」「支付成功」「您的支付已成功完成」「支付失败」「任务：」「申请者：」「支付金额」「优惠券折扣」 |
| **WeChatPayWebView.swift** | 「正在加载支付页面…」「加载失败」「重试」「返回」「取消后需要重新发起支付」 |

### 3.2 中等（VIP、客服、消息、通知等）

| 文件 | 典型硬编码内容 |
|------|----------------|
| **VIPPurchaseView.swift** | 「升级VIP会员」「选择适合您的会员套餐」「暂无可用的VIP产品」「请稍后再试或联系客服」「恢复购买」「购买说明」及条款、「恭喜您成为VIP会员！…」「已购买」 |
| **VIPView.swift** | 「升级VIP会员」「您已是VIP会员」「感谢您的支持…」「到期时间：」「将自动续费」「已取消自动续费」 |
| **ServiceDetailView.swift** | 「暂无图片」「服务详情」「暂无详细描述」「可选」「申请留言」「我想议价」「灵活时间」「期望完成日期」「提交」 |
| **NotificationListView.swift** | 「查看全文」「过期时间: …」「通知内容」 |
| **MessageGroupBubble.swift** / **ChatView.swift** | 「无法翻译此消息，请检查网络连接后重试」 |
| **TaskChatMessageListView.swift** | 「证据文件」 |
| **Customer Service / 客服** | （若还有未列出的中文提示，也建议统一走 LocalizationKey） |

### 3.3 其他（组件、调试、示例）

| 文件 | 典型硬编码内容 |
|------|----------------|
| **NetworkStatusBanner.swift** | 「重试」「离线」 |
| **OfflineManager.swift** | 「离线模式」「(N 待同步)」 |
| **TasksView.swift** | 「确定要将此任务标记为不感兴趣吗？」 |
| **CreateTaskView.swift** / **LocationPickerView.swift** | 「搜索结果」 |
| **TaskExpertDetailView.swift** | 「加载中…」「专家信息加载失败」 |
| **ExternalWebView.swift** | 「加载中…」 |
| **LoadingView.swift** | 「标准加载」「简洁加载」「点状加载」「骨架加载」「成功动画」「错误动画」 |
| **RefreshEnhancements.swift** | 「刷新增强组件示例」 |
| **InteractionEnhancements.swift** | 「列表入场动画」「脉冲效果」「页面入场动画」 |
| **SkeletonView.swift** | 「任务卡片骨架屏」「活动卡片骨架屏」等 |
| **TaskDetailView (UIAlert)** | `UIAlertController` 中 title: "撤销退款申请", "取消", "确定", "确认完成任务", "确认" 等 |

说明：若部分组件仅用于开发/调试、不对外展示，可保留英文或注释说明“仅调试”，其余用户可见文案建议全部改为本地化 key。

---

## 四、Key 与枚举建议

1. **枚举**  
   - 当前 **LocalizationKey 已覆盖所有在用的 .strings key**，枚举完善度良好。  
   - 可选：在 `LocalizationHelper` 或文档中注明 `stripe_connect.load_failed` 已废弃，统一使用 `stripe.connect_load_failed`。

2. **.strings key**  
   - **zh-Hant**：按 en 的 1466 个 key 补全约 490 条缺失项，保证三语 key 一致。  
   - 可选：从 en/zh-Hans 中删除或标注废弃 `stripe_connect.load_failed`，避免与 `stripe.connect_load_failed` 混用。

3. **硬编码**  
   - 优先处理 **TaskDetailView、TaskDetailCards、FleaMarketDetailView、ApplePayNativeView、WeChatPayWebView** 中的任务/退款/支付相关文案。  
   - 为每条需国际化的文案在 `LocalizationKey` 中新增 case，并在 en / zh-Hans / zh-Hant 的 `Localizable.strings` 中补全翻译。  
   - 所有 `UIAlertAction` / `Alert` 的 title 和 button 文案也应使用 `LocalizationKey`。

---

## 五、总结

| 检查项 | 状态 | 说明 |
|--------|------|------|
| **枚举完善度** | ✅ 完善 | 1465 个 case，与当前使用的 key 一致 |
| **en key** | ✅ 完善 | 1466 个 key |
| **zh-Hans key** | ✅ 完善 | 无缺失 |
| **zh-Hant key** | ❌ 不完善 | 缺约 490 个 key，需补全 |
| **硬编码文案** | ❌ 未完全国际化 | 多份视图存在大量中/英硬编码，需逐步改为 LocalizationKey |

**结论**：iOS 端**尚未完全国际化**。枚举和 en/zh-Hans 的 key 较完善，主要缺口为：  
1）**zh-Hant 缺少约 490 个 key**；  
2）**多处界面仍使用硬编码中文/英文**，尤其是任务详情、退款、支付、VIP、客服与消息等模块。建议先补全 zh-Hant，再按模块将硬编码替换为 `LocalizationKey` 并补全三语 .strings。

---

## 六、2026-02-04 完善进度

- **zh-Hant**：已补全约 490 条缺失 key（从 zh-Hans 同步，部分暂用简体）。
- **LocalizationKey**：新增任务详情/截止时间/证据/完成、退款扩展、common.or、rebuttal/history sheet 等约 80+ key。
- **TaskDetailView**：退款、争议、证据上传、确认完成、倒计时、Alert、Section 标题等硬编码已改为 `LocalizationKey`。
- **TaskDetailCards**：`X 已完成`、发布者/接单者、截止时间、发布时间已本地化。
- **TasksView**：「确定要将此任务标记为不感兴趣吗？」已本地化。
- **仍待处理**：FleaMarketDetailView、ApplePayNativeView、WeChatPayWebView、VIP 相关、ServiceDetailView、NotificationListView、部分 Message/客服等界面中的硬编码可继续按同一方式替换。
