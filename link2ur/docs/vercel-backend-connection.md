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

## 小结

| 现象 | 原因 | 处理 |
|------|------|------|
| Vercel 打开后显示 error_network_connection / 连不上后端 | 后端 CORS 未放行你的 Vercel 域名 | 在 Railway 的 `ALLOWED_ORIGINS` 中加入该 Vercel 域名并重新部署后端 |
| 控制台报「x-app-platform is not allowed by Access-Control-Allow-Headers」 | 后端未允许该自定义请求头 | 使用已包含 `X-App-Platform` 等头的后端配置并重新部署 |

## 可选：用自定义域名避免改 CORS

若你在 Vercel 上为 Flutter Web 配置了自定义域名（例如 `https://app.link2ur.com`），并且该域名已在后端 `ALLOWED_ORIGINS` 中，则无需再改 CORS，部署后即可直接连上后端。
