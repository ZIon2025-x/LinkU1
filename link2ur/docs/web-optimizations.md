# Web 端优化说明

本文档汇总 Flutter Web（app.link2ur.com）已做和可选的优化项。

---

## 已做优化

### 1. 外部链接 / 跳转网页
- **问题**：应用内 WebView 在 Web 上用 iframe 嵌入，多数站点禁止被嵌入（X-Frame-Options），导致灰屏。
- **处理**：`ExternalWebView.openInApp`、`ExternalWebView.showAsSheet` 在 **Web 平台**改为 `launchUrl` 在浏览器中打开，移动端仍用应用内 WebView。
- **位置**：`lib/core/widgets/external_web_view.dart`。

### 2. 桌面端抽屉菜单 hover 闪烁
- **问题**：汉堡菜单项用 `MouseRegion` + `setState` 做 hover，鼠标在项之间移动时易触发 enter/exit 抖动，导致闪烁。
- **处理**：菜单项和顶部图标改为 **InkWell**（Material 的 hover 反馈），不再用 `MouseRegion` + 自管状态。
- **位置**：`lib/core/widgets/desktop_sidebar.dart`（`_MenuItem`、`_HoverIconButton`）。

### 3. 图片 / 文件跨域（CORS）
- **方案**：在 Cloudflare 为 cdn/www 配置 `Access-Control-Allow-Origin: https://app.link2ur.com`，使 Web 直连 CDN；Flutter 端直接使用 cdn/www 的 URL，不走后端代理。
- **说明**：见 [cdn-cors-setup.md](cdn-cors-setup.md)。

### 4. 滚动与首帧
- **ScrollBehavior**：Web 使用 `ClampingScrollPhysics`，贴近浏览器原生滚动。
- **首帧**：Web 上延迟 2 秒再移除 splash，避免阻塞首帧；非关键 BLoC 延迟加载。
- **位置**：`lib/core/design/scroll_behavior.dart`、`lib/app.dart`。

### 5. 平台差异处理（已有）
- **支付**：Apple Pay 仅移动端；Web 上微信支付仍用 WebView（Stripe Checkout 一般允许 iframe）。
- **推送 / 角标 / 生物认证 / 备份**：Web 上已跳过或提示不可用。
- **API**：`X-App-Platform: web`，后端可区分 Web 请求。

---

## 可选 / 后续优化

| 项 | 说明 |
|----|------|
| **微信支付 WebView 在 Web 上灰屏** | 若 Stripe Checkout 在 iframe 内被拦截，可改为 Web 上 `launchUrl` 打开支付页，再通过 redirect 或轮询判断支付结果。 |
| **验证码 CaptchaWebView 在 Web 上异常** | 当前用 `loadHtmlString` 内嵌 reCAPTCHA/hCaptcha。若 Web 上出现域名或 iframe 限制，可考虑 Web 专用方案（如单独打开验证页或使用支持 Web 的验证码包）。 |
| **桌面布局断点** | `Breakpoints.desktopShellMinWidth = 1400`，≥1400px 才用桌面外壳；可根据实际设备再微调。 |
| **后端图片代理** | 若暂时无法配置 CDN CORS，可重新启用 Flutter 中对 cdn/www 的 URL 重写为 `/api/proxy/resource`（后端保留 `image_proxy_routes.py`）。 |

---

## 验证建议

- **Web 链接**：在 app 内点击「跳转网页」类入口，应在新标签或当前标签打开目标页，而不是灰屏。
- **抽屉菜单**：桌面宽度打开汉堡菜单，鼠标在菜单项上移动，hover 高亮应稳定、无闪烁。
- **图片**：首页/列表等来自 cdn 或 www 的图片在 Web 上能正常显示（依赖 CDN CORS 配置）。
