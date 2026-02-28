# Vercel 部署后连不上后端（error_network_connection）

## 原因

Flutter Web 部署到 Vercel 后，页面运行在 `https://xxx.vercel.app` 域名下。浏览器会向**后端 API**（如 `https://api.link2ur.com`）发请求。这是**跨域请求**，后端必须在响应头里声明允许你的前端来源，否则浏览器会拦截响应，前端拿不到数据，表现为「连不上后端」或 `error_network_connection`。

也就是说：**不是后端宕机，而是后端的 CORS 白名单里没有包含你的 Vercel 域名。**

## 解决步骤

### 1. 确认你的 Vercel 访问地址

部署后你会得到类似：

- 生产：`https://你的项目名.vercel.app`
- 或自定义域名：`https://app.link2ur.com`

### 2. 在后端（Railway）里把该域名加入 CORS

后端使用环境变量 **`ALLOWED_ORIGINS`** 控制允许的来源（见 `backend/app/config.py`）。

在 **Railway** 上打开你的后端项目 → **Variables** → 找到或新增 `ALLOWED_ORIGINS`，在列表里**追加**你的 Vercel 地址（多个用英文逗号分隔，不要空格）：

```env
ALLOWED_ORIGINS=https://www.link2ur.com,https://link2ur.com,https://app.link2ur.com,https://admin.link2ur.com,https://service.link2ur.com,https://你的项目.vercel.app
```

例如部署到 `https://link2ur-web.vercel.app`，就加上：

```env
...,https://link2ur-web.vercel.app
```

如果有预览部署（如 `https://link2ur-web-git-xxx.vercel.app`），也需要把用到的预览域名一并加进去，或使用通配符（若后端支持）。

### 3. 保存并重新部署后端

在 Railway 保存环境变量后，触发一次重新部署，让新 CORS 配置生效。

### 4. 确认 Flutter 使用的 API 地址

- **Release 构建**（如 `flutter build web`）默认走生产环境，请求的是 `https://api.link2ur.com`（见 `lib/core/config/app_config.dart`）。
- 若希望 Vercel 上的前端连**测试后端**，可在构建时加：  
  `--dart-define=ENV=development`  
  此时会请求 `https://linktest.up.railway.app`，需确保该后端的 `ALLOWED_ORIGINS` 也包含你的 Vercel 域名。

## 若报错「Request header field xxx is not allowed by Access-Control-Allow-Headers」

Flutter 请求会带多种自定义头，后端 CORS 的 **Access-Control-Allow-Headers** 必须全部允许，否则浏览器预检会拒绝。

**后端已与 Flutter 对齐**（`backend/app/config.py` → `ALLOWED_HEADERS`）包含：

| 头名 | 来源 |
|------|------|
| Content-Type, Accept, Accept-Language, Origin | 通用 / ApiConfig |
| Authorization, X-Session-ID, X-Refresh-Token | 认证与刷新 |
| X-App-Platform, X-Platform, X-App-Version | api_config.dart defaultHeaders |
| X-App-Signature, X-App-Timestamp | api_service 签名（MOBILE_APP_SECRET） |
| X-Request-ID | api_service _onRequest 拦截器 |
| X-CSRF-Token, X-Requested-With, X-User-ID, Cache-Control, Pragma, Expires | 其它 |

**若 Flutter 新增自定义请求头**：须同步在 `backend/app/config.py` 的 `ALLOWED_HEADERS` 中加入该头名，否则 Web 端 CORS 预检会报错。

## 图片/文件跨域（Access to image at 'xxx' has been blocked by CORS policy）

当 Flutter Web 运行在 `https://app.link2ur.com` 时，若图片或文件 URL 来自**其它域名**（如 `https://www.link2ur.com`、`https://cdn.link2ur.com`），浏览器会按 CORS 检查响应头。若响应里没有 `Access-Control-Allow-Origin: https://app.link2ur.com`，资源会被拦截，表现为裂图、文件打不开或控制台报错：

```text
Access to image at 'https://cdn.link2ur.com/...' from origin 'https://app.link2ur.com' has been blocked by CORS policy: No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

### 为什么 www 能直接访问 cdn，而 app 不能？

CORS 是按**页面来源（Origin）**控制的：

- 主站 **www.link2ur.com** 和 CDN **cdn.link2ur.com** 往往在同一套 Cloudflare/配置下，CDN 可能只对 `www` 或同域返回了 `Access-Control-Allow-Origin`，所以主站页面加载 cdn 资源没问题。
- Flutter Web 部署在 **app.link2ur.com**，是**另一个 Origin**。若 CDN 未配置允许 `https://app.link2ur.com`，浏览器就会拦截 app 页面对 cdn 的请求。

### 推荐方案：在 CDN 上配置 CORS

在 **Cloudflare**（或实际提供图片/文件的 CDN）上，为来自 app.link2ur.com 的请求在响应中增加：

- `Access-Control-Allow-Origin: https://app.link2ur.com`

这样 Flutter Web 直接请求 cdn/www，无需经后端中转，延迟和带宽更优。

**操作步骤**：见 **[link2ur/docs/cdn-cors-setup.md](cdn-cors-setup.md)**（Cloudflare Transform Rules、Page Rules、源站 Nginx 三种方式）。

### 备选：后端资源代理

若暂时无法改 CDN 配置，可启用后端代理：保留 `backend/app/image_proxy_routes.py` 中的 `/api/proxy/resource`，并在 Flutter 的 `Helpers.getImageUrl` / `getResourceUrl` 中，对 Web 且 host 为 cdn/www 的 URL 重写为 `{apiBase}/api/proxy/resource?url=...`（当前已改为直连 CDN，不再做此重写）。

## 控制台「Refused to set unsafe header 'Accept-Encoding' / 'User-Agent'」

在浏览器里，部分请求头由浏览器控制，不能由前端脚本设置。Flutter Web 若通过 Dio 设置 `Accept-Encoding`、`User-Agent` 等，控制台会打印上述警告；**请求仍会发出**，浏览器会使用自己的值。  
项目已在 Web 构建中不设置这两项，以减轻控制台噪音；若仍看到旧构建的警告，重新部署前端即可。

## 小结

| 现象 | 原因 | 处理 |
|------|------|------|
| Vercel 打开后显示 error_network_connection / 连不上后端 | 后端 CORS 未放行你的 Vercel 域名 | 在 Railway 的 `ALLOWED_ORIGINS` 中加入该 Vercel 域名并重新部署后端 |
| 控制台报「x-app-platform is not allowed by Access-Control-Allow-Headers」 | 后端未允许该自定义请求头 | 使用已包含 `X-App-Platform` 等头的后端配置并重新部署 |
| 图片/文件裂图或无法加载、报「Access to image at 'xxx' blocked by CORS」 | cdn/www 未对 app.link2ur.com 返回 CORS 头 | 在 CDN（如 Cloudflare）上为响应添加 `Access-Control-Allow-Origin: https://app.link2ur.com`，详见 [cdn-cors-setup.md](cdn-cors-setup.md) |

## 可选：用自定义域名避免改 CORS

若你在 Vercel 上为 Flutter Web 配置了自定义域名（例如 `https://app.link2ur.com`），并且该域名已在后端 `ALLOWED_ORIGINS` 中，则无需再改 CORS，部署后即可直接连上后端。
