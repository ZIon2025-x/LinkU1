# iOS 加急审核（Expedited Review）申请指南

当提交的版本包含**关键 bug 修复**（如聊天记录无法加载）时，可向 Apple 申请加急审核，通常 24–48 小时内会有结果。

## 适用场景

- 严重功能缺陷（如本版本：任务聊天往上滑无法查看历史，只能刷新）
- 安全或合规问题
- 已上架版本导致大量用户无法正常使用

## 申请步骤

1. **登录 App Store Connect**  
   https://appstoreconnect.apple.com

2. **进入加急审核申请页**  
   - 方式一：底部或页面中的 **「联系我们」/ Contact Us**  
   - 方式二：直接打开  
     https://developer.apple.com/contact/app-store/?topic=expedite  

3. **选择请求类型**  
   - 选择 **「Request an Expedited App Review」**（申请加急 App 审核）

4. **填写表单**  
   - **App 名称 / Bundle ID**：你的应用名称和 Bundle ID（如 Link²Ur / com.link2ur.xxx）  
   - **版本号**：当前提交待审核的版本号（如 1.2.3）  
   - **理由（必填，建议英文）**：简明说明为何需要加急，例如：

   ```
   We have submitted a critical bug fix (version X.X.X). In the current live version, 
   users cannot load older chat messages in task conversations—scrolling up only 
   triggers a refresh and shows the same latest messages. This affects all users 
   who need to refer to earlier conversation history. The fix (cursor-based 
   pagination) is already implemented in the submitted build. We request 
   expedited review so users can get the fix as soon as possible.
   ```

   中文大意：当前线上版本存在严重问题：任务聊天中用户无法查看更早的聊天记录，往上滑只会刷新并重复显示最新消息。已提交的版本中已修复该问题（游标分页加载历史）。请求加急审核以便用户尽快获得修复。

5. **提交**  
   提交后 Apple 会发确认邮件，审核团队通常会在 1–2 个工作日内处理。若理由充分，会安排加急审核。

## 审核通过前可做的用户沟通

- **应用内**：若已有「公告 / 客服 / 帮助」入口，可写一句：「查看完整任务聊天记录请使用网页版或更新至最新版 App（审核通过后即可更新）。」
- **邮件 / 推送**：向近期使用过任务聊天的用户发简短说明 + 网页版链接。
- **客服话术**：统一回复「该问题已修复并提交 App Store，请留意更新；在更新前可先用网页版查看完整记录。」

## 参考

- [Apple – Request an Expedited App Review](https://developer.apple.com/contact/app-store/?topic=expedite)
- 加急审核**不能保证一定通过**，但针对明确的关键 bug 修复，通过概率较高。
