# 测试环境图片 URL 配置

## 问题

在 Railway 测试环境（如 `perfect-joy.railway.internal` / `linktest.up.railway.app`）上传的跳蚤市场等公开图片，返回的 URL 错误指向生产域名 `https://www.link2ur.com/uploads/...`，导致：

- 图片无法显示（生产环境没有该文件）
- 或显示错误内容（命中生产缓存）

## 原因

`LocalStorageBackend` 默认使用 `Config.FRONTEND_URL` 构建图片 URL。当测试环境未设置 `FRONTEND_URL` 时，会 fallback 到生产默认值 `https://www.link2ur.com`。

## 解决方案

在 Railway 测试/预发环境的**环境变量**中增加：

```
UPLOAD_PUBLIC_URL=https://linktest.up.railway.app
```

（替换为你的测试后端对外可访问 URL，即能访问 `/uploads/` 的域名）

优先级：`UPLOAD_PUBLIC_URL` > `FRONTEND_URL`

## 相关配置

| 环境变量 | 说明 | 测试环境示例 |
|---------|------|-------------|
| `UPLOAD_PUBLIC_URL` | 图片/上传文件访问的基础 URL | `https://linktest.up.railway.app` |
| `FRONTEND_URL` | 前端主站 URL（未设 UPLOAD_PUBLIC_URL 时作为图片 base） | 可不设或同 UPLOAD_PUBLIC_URL |
| `BASE_URL` | 后端 API 地址 | `https://linktest.up.railway.app` |

## 验证

上传跳蚤市场图片后，接口返回的 `url` 应为：

- ✅ `https://linktest.up.railway.app/uploads/flea_market/30/xxx.jpg`
- ❌ ~~`https://www.link2ur.com/uploads/flea_market/30/xxx.jpg`~~
