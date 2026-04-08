# Social Crawler SSR Wiring — Design

**日期**: 2026-04-08
**作者**: Ryan + Claude
**状态**: Approved by user (verbal), pending spec review

## 背景

Google Search Console 报告 link2ur.com 大量 5xx 错误。根因排查：

1. `frontend/middleware.ts` (Vercel Edge Middleware) 将所有爬虫请求代理到 prerender.io
2. prerender.io 试用结束，token 失效，所有 bot 请求返回 `503 Service Unavailable` (`x-prerender-reject-reason: invalid-x-prerender-token-provided`)
3. middleware 的 `catch` 只处理 `fetch` 异常，不处理上游 5xx，导致 503 直接透传给 Googlebot
4. 普通用户访问正常，只有爬虫看到 5xx——所以 Search Console 报警但用户无感

**短期止血**已完成：在 middleware.ts 中加入 fallback——`PRERENDER_TOKEN` 为空或 prerender.io 返回非 2xx 时回退到 SPA。

## 重大发现

后端 `backend/app/ssr_routes.py` (1183 行) **早已实现完整的 SSR 系统**：

| 能力 | 行号 |
|---|---|
| Non-JS 社交爬虫 UA 检测 (微信/FB/Twitter/WhatsApp/Telegram/Discord/LinkedIn/Slack/Pinterest/百度等) | 27-44 |
| iOS 链接预览检测 (CFNetwork/Darwin/LinkPresentation 等) | 56-91 |
| JS-capable 爬虫白名单 (Googlebot/Bingbot/GPTBot/PerplexityBot 等) | 95-108 |
| 主页 SSR `/`, `/zh`, `/en` | 385-466 |
| 任务详情 SSR `/tasks/{id}`, `/zh/tasks/{id}`, `/en/tasks/{id}` | 471-698 |
| 排行榜详情 SSR `/leaderboard/custom/{id}` | 703-829 |
| 论坛帖子详情 SSR `/forum/post/{id}` | 832-969 |
| 活动详情 SSR `/activities/{id}` | 972+ |
| HTML escape + XSS 防护 | 188-193 |
| Schema.org 结构化数据 (JobPosting 等) | 631-673 |
| 已注册到 main.py | `main.py:369-370` |

但这些端点注册在 `api.link2ur.com`，而真实分享链接是 `www.link2ur.com/tasks/123`——爬虫的请求永远到不了 backend。

**结论**: 这不是新功能，而是**接通一根从未连接的线**——让 Vercel 前端把社交爬虫请求转发到 backend SSR。

## 目标

社交分享卡片爬虫 (微信/朋友圈/Facebook/Twitter/WhatsApp/Telegram/Discord/LinkedIn/Slack 等) 在抓取以下 URL 时拿到正确的 OG/Twitter Card meta，使分享卡片显示真实标题、描述、封面图：

- `https://www.link2ur.com/tasks/{id}`、`/zh/tasks/{id}`、`/en/tasks/{id}`
- `https://www.link2ur.com/forum/post/{id}`、`/zh/forum/post/{id}`、`/en/forum/post/{id}`
- `https://www.link2ur.com/leaderboard/custom/{id}`、`/zh/leaderboard/custom/{id}`、`/en/leaderboard/custom/{id}`
- `https://www.link2ur.com/activities/{id}`、`/zh/activities/{id}`、`/en/activities/{id}`
- `https://www.link2ur.com/`、`/zh`、`/en`

## 非目标

- ❌ 不为 Googlebot/Bingbot 等 JS-capable 爬虫做 SSR (Google 自己跑 JS，SSR 与 SPA 内容差异会被判 cloaking)
- ❌ 不修改 `backend/app/ssr_routes.py`（已经写好）
- ❌ 不修改 `frontend/public/index.html` 那段动态 meta 注入 JS (仍服务于 SPA 浏览器用户)
- ❌ 不引入新的预渲染服务、不重新付费 prerender.io
- ❌ 不在 backend 加缓存层（Vercel 自动缓存 200 响应；后续如需可单独做）
- ❌ 不重写 Vercel rewrites (维持现有 SPA 路由)

## 设计

### 唯一改动文件

**`frontend/middleware.ts`** (~80 行) — 完整重写，移除 prerender.io 逻辑。

### 行为

```
请求到达 Vercel Edge Middleware
   │
   ├─ pathname 是静态资源 / API 路由 / 文件后缀? ──→ 放行 (return)
   │
   ├─ pathname 不匹配已知 SSR 路径? ──────────────→ 放行 (return)
   │   (匹配清单: /, /zh, /en, /[lang]/tasks/N,
   │    /[lang]/forum/post/N, /[lang]/leaderboard/custom/N,
   │    /[lang]/activities/N — lang 可选)
   │
   ├─ User-Agent 不是 non-JS 社交爬虫? ────────────→ 放行 (return)
   │   (匹配 NON_JS_CRAWLERS 列表)
   │
   ▼
fetch https://api.link2ur.com${pathname}${search}
   ├─ 转发原始 User-Agent 头
   ├─ 5 秒 timeout (AbortController)
   │
   ├─ response.ok && content-type 包含 text/html?
   │   ├─ 是 → 返回 backend HTML，状态码 200，加 X-SSR: backend 头
   │   └─ 否 → 放行 (return)
   │
   └─ fetch 抛异常? → 放行 (return)
```

### NON_JS_CRAWLERS 列表 (与 backend 对齐)

```ts
const NON_JS_CRAWLERS = [
  /MicroMessenger/i, /WeChat/i, /Weixin/i, /WeChatShareExtension/i,
  /facebookexternalhit/i, /Facebot/i,
  /Twitterbot/i,
  /LinkedInBot/i,
  /Slackbot/i,
  /TelegramBot/i,
  /WhatsApp/i,
  /Discordbot/i,
  /Pinterest/i,
  /Baiduspider/i,
  /YandexBot/i,
  /CCBot/i,
];
```

**注意**: Googlebot、Bingbot、GPTBot 等不在此列——它们走 SPA。

### 路径白名单 (避免对每个 404 都打 backend)

```ts
const SSR_PATH_PATTERNS = [
  /^\/(zh|en)?\/?$/,                                    // home
  /^\/(zh\/|en\/)?tasks\/\d+\/?$/,
  /^\/(zh\/|en\/)?forum\/post\/\d+\/?$/,
  /^\/(zh\/|en\/)?leaderboard\/custom\/\d+\/?$/,
  /^\/(zh\/|en\/)?activities\/\d+\/?$/,
];
```

### 后端兼容性验证

`ssr_routes.py:484-509` 的逻辑对 non-JS 爬虫 UA 的处理路径**不依赖** `is_request_from_frontend()`：

```python
if is_js_capable_crawler(user_agent) and not is_from_frontend:  # → 跳过 (不是 JS 爬虫)
    return RedirectResponse(...)
if not is_non_js_crawler(user_agent) and not is_from_frontend:  # → 跳过 (是 non-JS 爬虫)
    return RedirectResponse(...)
# 直接渲染 SSR HTML
```

所以 fetch 时 Host 头是 `api.link2ur.com` 也无所谓，只要 UA 是 non-JS 爬虫就能拿到 HTML。**不需要改 backend，也不需要 X-Forwarded-Host header**。

### 错误处理 / Fallback

绝不让 backend 的 5xx 透传给爬虫——避免重蹈 prerender.io 覆辙。但 backend 对不存在/已取消的任务返回 `404`/`410` + 合法 HTML，这种状态码透传反而对 SEO 有利（让搜索引擎尽快移除索引），所以保留。

最终规则：

| backend 响应 | middleware 行为 |
|---|---|
| `2xx` HTML | 透传，加 `X-SSR: backend` 头 |
| `404` / `410` HTML | 透传 status code 与 body (backend 已生成合法 "不存在/已取消" HTML) |
| `5xx` 或其他 status | fall through 到 SPA |
| 非 HTML content-type | fall through 到 SPA |
| fetch 异常 / 5 秒超时 | fall through 到 SPA |
| pathname 不在白名单 | 不发起 fetch，直接放行 |
| UA 不在 NON_JS_CRAWLERS | 不发起 fetch，直接放行 |

### 性能 & 风险

| 项 | 评估 |
|---|---|
| 延迟 | Vercel Edge → Railway 多一跳，~150-400ms。爬虫不在乎。 |
| Vercel Edge Function 调用次数 | 仅 non-JS 爬虫 + 白名单路径才触发 fetch，量极小 |
| Backend 负载 | 同上，量极小；现有 SSR routes 已做 DB 查询 |
| 死循环 | backend 不会再回调前端 (HTML 直接返回)，无循环风险 |
| og:url 一致性 | URL 始终保持 www.link2ur.com，分享卡片点击落地 SPA 正常 ✓ |
| 缓存 | 在响应头加 `Cache-Control: public, s-maxage=3600, stale-while-revalidate=86400`，让 Vercel Edge 缓存 1 小时，stale 24 小时 |

## 实现影响

| 文件 | 改动 |
|---|---|
| `frontend/middleware.ts` | 完整重写 (~80 行) |
| `backend/app/ssr_routes.py` | 不动 |
| `frontend/vercel.json` | 不动 |
| `frontend/public/index.html` | 不动 |
| Vercel 环境变量 `PRERENDER_TOKEN` | 部署后从 dashboard 删除 (清理) |

## 测试 / 验证

部署后用以下命令验证：

```bash
# 微信爬虫 → 应返回 200 + backend 渲染的 HTML，含正确 og:title
curl -sI -A "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36 MicroMessenger/6.5.2.501 NetType/WIFI WindowsWechat" \
  https://www.link2ur.com/zh/tasks/1
# Expected: HTTP/1.1 200, X-SSR: backend

# Facebook 爬虫
curl -sI -A "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)" \
  https://www.link2ur.com/en/tasks/1
# Expected: HTTP/1.1 200, X-SSR: backend

# Twitter 爬虫
curl -sI -A "Twitterbot/1.0" https://www.link2ur.com/en/forum/post/1
# Expected: HTTP/1.1 200, X-SSR: backend

# Googlebot → 应直接走 SPA (不走 backend)，无 X-SSR 头
curl -sI -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
  https://www.link2ur.com/en/tasks/1
# Expected: HTTP/1.1 200, no X-SSR header

# 普通浏览器 → 应直接走 SPA
curl -sI -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Chrome/120.0.0.0 Safari/537.36" \
  https://www.link2ur.com/en/tasks/1
# Expected: HTTP/1.1 200, no X-SSR header
```

后续手动验证（需要部署后）：
- Facebook Sharing Debugger: https://developers.facebook.com/tools/debug/
- Twitter Card Validator: https://cards-dev.twitter.com/validator
- 微信开发者工具内 webview 抓 OG 标签
- Google Search Console → 几天内 5xx 报错应清零

## 上线步骤

1. 编辑 `frontend/middleware.ts`
2. `git commit && git push` → Vercel 自动部署
3. 跑上述 curl 验证
4. 进 Vercel Dashboard → Settings → Environment Variables → 删除 `PRERENDER_TOKEN`
5. (可选) 在 Search Console 对受影响 URL 点 "请求编入索引"

## 回滚预案

回滚一行命令：`git revert HEAD && git push`。中间状态没有数据迁移、没有 schema 变更、没有 backend 改动，回滚零成本。

如果发现某类爬虫 SSR 输出有 bug，可以临时在 `NON_JS_CRAWLERS` 中注释掉对应正则——爬虫立即回退到 SPA，不影响其他爬虫。
