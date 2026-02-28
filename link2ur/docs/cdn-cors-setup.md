# CDN 配置 CORS（让 app 和 www 一样直连 cdn）

**目标**：和以前主站 **www** 一样，让 **app.link2ur.com** 也能直接请求 cdn/www 的图片和文件，不走后端代理。

Flutter 已按 www 方式：直接使用 cdn/www 的 URL。只需在 **Cloudflare** 上为响应加上允许 `https://app.link2ur.com` 的 CORS 头（和 www 同源或已放行的做法一致），app 就能像 www 一样直连 cdn。

---

## 方式一：Transform Rules（推荐，灵活）

1. 登录 [Cloudflare Dashboard](https://dash.cloudflare.com/) → 选择你要配置的域名（**link2ur.com**；若图片在 cdn/www 且是单独站点，先切到对应站点）。
2. **找 Transform Rules**（你当前左侧 Rules 下只有 Overview、Snippets、Page Rules 等，没有「Transform Rules」时）：
   - 点左侧 **Rules** 或 **Overview**（Rules 下的第一项），进入规则总览页；
   - 看**中间主内容区**（不是左侧菜单）：是否有 **Transform rules**、**Modify response header** 的入口或 Tab；
   - 或点顶部 **Rules** 大标题下的 **Create rule**，看下拉里是否有「Transform rule」→「Modify response header」。
3. 若**始终没有** Transform Rules 入口，直接改用下方 **方式三**（在源站 Nginx 加 CORS），效果相同。
4. 若有，则：选 **Modify Response Header** → **Create rule**，名称如 `CORS for app.link2ur.com`。
5. **When to apply**（匹配条件）：
   - 若只对图片/文件加 CORS，可设：
     - Field: `URI Path`，Operator: `starts with`，Value: `/uploads/` 或 `/public/`（按你 CDN 实际路径）。
     - 或对全部响应加：留空或匹配所有请求。
   - 建议至少包含：`(URI Path starts with /uploads/) or (URI Path starts with /public/)`。
6. **Then**（要改的响应头）：
   - **Set static header**：
     - Header name: `Access-Control-Allow-Origin`
     - Value: `https://app.link2ur.com`
   - 若需要带 cookie 或自定义头，可再加：
     - `Access-Control-Allow-Credentials`: `true`（仅当确实需要且与 `Access-Control-Allow-Origin` 非 `*` 时）
7. 保存并 **Deploy**（部署）。

对 **www.link2ur.com** 或 **cdn.link2ur.com** 若在 Cloudflare 里是**另一个站点**，需切到该站点再按同样步骤建一条规则。

---

## 方式二：Page Rules（旧版，仍可用）

1. 域名 → **Rules** → **Page Rules** → **Create Page Rule**。
2. URL 模式，例如：`*cdn.link2ur.com/uploads/*` 或 `*www.link2ur.com/uploads/*`。
3. 添加设置：**Add a setting** → **Custom header**（若存在）；或使用 **Cache Level** 等，但**添加响应头**在 Page Rules 里可能需用 **Transform Rules** 才能实现。
4. 若当前 Cloudflare 版本里 Page Rules 不能直接加响应头，请用上面的 **Transform Rules**。

---

## 方式三：在源站（Origin）加 CORS 头

若 CDN 只是回源到你的服务器（Nginx / 后端），也可以在**源站**对图片/文件响应加头，例如 Nginx：

```nginx
location /uploads/ {
    add_header Access-Control-Allow-Origin "https://app.link2ur.com";
    # 其他配置...
}
```

保存后重载 Nginx。这样经过 Cloudflare 回源的响应也会带上该头。

---

## 验证

配置生效后，在浏览器打开 **https://app.link2ur.com**，F12 → Network，点开一张来自 cdn 或 www 的图片请求，在 **Response Headers** 里应能看到：

```text
Access-Control-Allow-Origin: https://app.link2ur.com
```

若没有，说明规则未命中或未生效，检查域名、路径和规则顺序。

---

## 多来源时

若除 app 外还有别的来源（如测试环境 `https://xxx.vercel.app`），可以：

- 在 Transform Rules 里用 **Set dynamic header**，根据请求头 `Origin` 回填 `Access-Control-Allow-Origin`（需 Cloudflare 支持表达式）；或  
- 在允许列表里写多个规则，按 `Origin` 分别返回对应值；或  
- 临时用 `*`（不推荐生产环境，仅测试）。

生产环境建议只放行需要的来源，例如：`https://app.link2ur.com`。
