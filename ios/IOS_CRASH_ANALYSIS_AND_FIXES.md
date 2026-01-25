# iOS 闪退原因分析与修复

## 一、已修复的高风险项

### 1. QQShareManager — `as!` 强制转型导致闪退 ✅

**位置**：`ios/link2ur/link2ur/Core/Utils/QQShareManager.swift`

**原因**：`QQApiNewsObject.object(...) as! QQApiNewsObject` 在 SDK 返回 `nil` 或非预期类型时会直接崩溃。

**修复**：改为 `as?` 并用 `guard let` 判空，失败时走 `completion(false, "创建分享对象失败")`。两处（带图片 / 无图片）均已修改。

---

### 2. FleaMarketDetailView — 异步更新 @State 时页面已退出 ✅

**位置**：`ios/link2ur/link2ur/Views/FleaMarket/FleaMarketDetailView.swift`，「继续支付」按钮

**原因**：`DispatchQueue.main.async { [self] in ... }` 和 `asyncAfter` 在用户快速返回、页面已销毁后仍更新 `paymentTaskId`、`showPaymentView` 等 `@State`，可能访问已释放的视图状态导致闪退。

**修复**：
- 外层 `DispatchQueue.main.async` 改为 `[weak viewModel]`，开头 `guard viewModel != nil else { return }`，用 viewModel 是否存活作为「页面是否还在」的参考。
- 内层 `DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)` 同样加上 `[weak viewModel]` 和 `guard viewModel != nil else { return }`。

---

## 二、中低风险与需关注点

### 3. AppState — `guard self != nil` 写法

**位置**：`AppState.swift` 预加载、Banner、活动等 `receiveValue` 中。

**说明**：在 `[weak self]` 下使用 `guard self != nil else { return }` 只做「self 是否存在」的早退，后面未再使用 `self`，逻辑正确，不会因此闪退。若改为 `guard let self = self else { return }` 可更符合习惯，但不修也不会导致崩溃。

---

### 4. TaskDetailView — `receiveCompletion: { [self] result in }`

**位置**：`ApplicationMessageModal` 中 `APIService.shared.sendApplicationMessage(...).sink(receiveCompletion: { [self] ... })`

**说明**：订阅放在 `cancellables` 中，页面销毁时会取消，`receiveCompletion` 多数情况下不会在页面已销毁后执行。极少数在取消与完成之间的竞态下，仍有机会在已拆解的 View 上更新 `@State`，属中低风险。若要加强，可把该逻辑放到 ViewModel，用 `[weak viewModel]` 并在主线程回调前做 `viewModel == nil` 判断。

---

### 5. FleaMarketDetailView — `directPurchase` 的 `[self]`

**位置**：`FleaMarketDetailView` 的购买底部 sheet 中  
`viewModel.directPurchase(itemId:itemId, completion: { [self] purchaseData in ... }, onError: { [self] errorMsg in ... })`

**说明**：`completion` / `onError` 由 ViewModel 在请求完成时回调，若用户已下拉关闭 sheet，子 View 可能已销毁，此时再写 `isSubmitting`、`errorMessage` 等 `@State` 有闪退风险。  
可靠修复需要：在 sheet 的 `onDisappear` 里把「仍可见」标记置为 false，在 completion/onError 里先查该标记再更新状态；或把这段逻辑抽到 ViewModel，用 `[weak viewModel]` 和空判断。当前仅作记录，建议后续迭代时改。

---

### 6. APIService — `.data(using: .utf8)!`

**位置**：`APIService.swift` 的 multipart 构建，如  
`"--\(boundary)\r\n".data(using: .utf8)!` 等。

**说明**：当前 `boundary`、`filename` 等均为 ASCII/数字，`.data(using: .utf8)` 实际不会返回 `nil`，风险低。若日后允许文件名或字段含复杂 Unicode，建议改为 `if let d = "...".data(using: .utf8) { body.append(d) } else { ... }` 等安全写法。

---

### 7. Notification / Task 等模型中的 `!`

**位置**：  
- `Notification.swift`：`titleZh?.isEmpty == false ? titleZh! : title`，以及 `fallbackContent!`（在 `!= nil` 分支内使用），逻辑上安全。  
- `Task.swift`：同类的 `titleZh!` / `descriptionZh!` 等。

**说明**：均在「已确认非 nil / 非空」的分支内 force unwrap，不会增加额外闪退风险，可保持现状；若希望消除 `!`，可改为 `titleZh ?? title` 等。

---

### 8. 键盘与 Auto Layout

**参考**：`IOS_ISSUES_ANALYSIS.md`、`TASK_CHAT_CRITICAL_FIXES.md`

- 键盘与 `SystemInputAssistantView` 等的约束冲突，多来自系统，应用侧已通过 `KeyboardHeightObserver` 等方式做了缓解。
- 任务聊天等处的 `[weak viewModel]`、防抖、`scrollDismissesKeyboard` 等已按 `TASK_CHAT_CRITICAL_FIXES.md` 处理，有利于减少异常状态下的崩溃和卡顿。

---

## 三、建议的预防措施

1. **异步 / 延迟闭包**  
   - 对 `DispatchQueue.main.async`、`asyncAfter`、`sink` 等，若闭包内会改 `@State` 或调用 UI，优先 `[weak viewModel]` 或 `[weak self]`，并在使用前做 `guard`，避免在已销毁的 View 上更新。
2. **强制转型**  
   - 对 SDK、系统 API 的返回值，尽量用 `as?` + `guard let` 或 `if let`，避免 `as!`。
3. **强制解包 `!`**  
   - 仅在逻辑上能保证非 `nil` 的路径使用；对网络、编码、文件等可能失败的调用，改用 `if let` / `guard let` 或 `??`。
4. **Instruments**  
   - 用 Allocations、Leaks、Zombies 检查：  
     - 从任务/跳蚤/支付等页面进入再退出，反复数次；  
     - 在分享到 QQ、支付、购买等流程中快速返回或关闭 sheet，观察是否仍能稳定复现闪退。

---

## 四、修改文件一览

| 文件 | 修改内容 |
|------|----------|
| `QQShareManager.swift` | 两处 `as! QQApiNewsObject` 改为 `as?` + `guard let`，失败时调用 `completion(false, "创建分享对象失败")` |
| `FleaMarketDetailView.swift` | 「继续支付」的 `DispatchQueue.main.async` 与 `asyncAfter` 改为 `[weak viewModel]` + `guard viewModel != nil`，避免页面退出后更新 `@State` |

---

**文档更新时间**：2025-01
