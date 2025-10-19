# Railway环境变量设置指南

## 问题描述

客服登录成功后，前端检测不到Cookie，原因是Cookie的Domain字段为空。

从日志可以看到：
```
INFO:app.service_auth:[SERVICE_AUTH] 客服Cookie设置成功: session_id=service_..., service_id=CS8888, refresh_token=是, 移动端: False, 隐私模式: False, SameSite: lax, Secure: True, Domain: , Path: /
```

**Domain字段为空**，导致Cookie无法在跨域环境中正确设置。

## 解决方案

### 1. 在Railway中设置环境变量

登录Railway控制台，在项目设置中添加以下环境变量：

```bash
IS_PRODUCTION=true
# COOKIE_DOMAIN=.link2ur.com  # 已移除 - 现在只使用当前域名
COOKIE_SECURE=true
COOKIE_SAMESITE=lax
ALLOWED_ORIGINS=https://www.link2ur.com,https://api.link2ur.com
```

### 2. 环境变量说明

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `IS_PRODUCTION` | `true` | 标识生产环境，启用生产配置 |
| ~~`COOKIE_DOMAIN`~~ | ~~`.link2ur.com`~~ | ~~已移除 - 现在只使用当前域名~~ |
| `COOKIE_SECURE` | `true` | 启用安全Cookie（HTTPS） |
| `COOKIE_SAMESITE` | `lax` | SameSite策略，支持跨域 |
| `ALLOWED_ORIGINS` | `https://www.link2ur.com,https://api.link2ur.com` | CORS允许的源 |

### 3. 设置步骤

1. **登录Railway控制台**
   - 访问 https://railway.app
   - 选择你的项目

2. **进入环境变量设置**
   - 点击项目设置
   - 选择 "Variables" 标签

3. **添加环境变量**
   - 点击 "New Variable"
   - 逐个添加上述环境变量

4. **重新部署**
   - 保存环境变量后
   - Railway会自动重新部署应用

### 4. 验证设置

部署完成后，检查日志中是否显示正确的Cookie域名：

```
INFO:app.service_auth:[SERVICE_AUTH] 客服Cookie设置成功: session_id=service_..., service_id=CS8888, refresh_token=是, 移动端: False, 隐私模式: False, SameSite: lax, Secure: True, Domain: .link2ur.com, Path: /
```

**注意**: Domain字段应该显示 `.link2ur.com` 而不是空的。

### 5. 测试客服登录

1. 访问 `https://www.link2ur.com/customer-service/login`
2. 使用客服账号登录
3. 检查浏览器开发者工具中的Cookie
4. 确认页面成功跳转到客服管理页面

## 技术细节

### Cookie设置逻辑

```python
# 修复后的Cookie域名设置
cookie_domain = None
if settings.IS_PRODUCTION:
    cookie_domain = settings.COOKIE_DOMAIN  # .link2ur.com
elif settings.COOKIE_DOMAIN:
    cookie_domain = settings.COOKIE_DOMAIN
```

### Cookie属性

```python
response.set_cookie(
    key="service_authenticated",
    value="true",
    max_age=SERVICE_SESSION_EXPIRE_HOURS * 3600,
    httponly=False,  # 前端需要读取
    secure=True,     # HTTPS安全
    samesite="lax",  # 支持跨域
    path="/",
    domain=".link2ur.com"  # 支持子域名
)
```

## 故障排除

### 如果Cookie仍然检测不到

1. **检查环境变量**
   ```bash
   # 在Railway控制台检查环境变量是否正确设置
   echo $IS_PRODUCTION
   echo $COOKIE_DOMAIN
   ```

2. **检查Cookie设置**
   - 打开浏览器开发者工具
   - 查看Network标签中的登录请求
   - 检查Response Headers中的Set-Cookie

3. **检查域名配置**
   - 确认前端在 `www.link2ur.com`
   - 确认后端在 `api.link2ur.com`
   - 确认Cookie域名是 `.link2ur.com`

### 如果仍然有问题

1. **清除浏览器Cookie**
   - 清除所有 `link2ur.com` 相关的Cookie
   - 重新尝试登录

2. **检查HTTPS配置**
   - 确认两个域名都使用HTTPS
   - 检查SSL证书是否有效

3. **检查CORS配置**
   - 确认后端CORS配置包含前端域名
   - 检查预检请求是否成功

## 总结

通过正确设置Railway环境变量，特别是 `COOKIE_DOMAIN=.link2ur.com`，可以解决跨域Cookie设置问题，使客服登录功能正常工作。
