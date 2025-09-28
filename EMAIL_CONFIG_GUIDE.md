# 📧 邮箱配置指南

## 概述
LinkU 平台使用邮箱验证机制确保用户账户安全。本指南将帮助您配置邮箱服务。

## 🔧 必需的环境变量

### 基本邮箱配置
```env
# 发件人邮箱地址
EMAIL_FROM=noreply@yourdomain.com

# SMTP服务器配置
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password

# 连接安全配置
SMTP_USE_TLS=true
SMTP_USE_SSL=false

# 验证令牌过期时间（小时）
EMAIL_VERIFICATION_EXPIRE_HOURS=24
```

## 📮 支持的邮箱服务商

### 1. Gmail (推荐)
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password  # 使用应用专用密码
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

**Gmail 设置步骤：**
1. 启用两步验证
2. 生成应用专用密码
3. 使用应用专用密码作为 `SMTP_PASS`

### 2. Outlook/Hotmail
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_USER=your-email@outlook.com
SMTP_PASS=your-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

### 3. QQ邮箱
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp.qq.com
SMTP_PORT=587
SMTP_USER=your-email@qq.com
SMTP_PASS=your-authorization-code  # 使用授权码
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

### 4. 163邮箱
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp.163.com
SMTP_PORT=465
SMTP_USER=your-email@163.com
SMTP_PASS=your-authorization-code  # 使用授权码
SMTP_USE_TLS=false
SMTP_USE_SSL=true
```

### 5. 企业邮箱 (Exchange)
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=mail.yourdomain.com
SMTP_PORT=587
SMTP_USER=your-email@yourdomain.com
SMTP_PASS=your-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
```

## 🚀 部署配置

### Railway 部署
在 Railway 项目设置中添加环境变量：
```env
EMAIL_FROM=noreply@yourdomain.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false
EMAIL_VERIFICATION_EXPIRE_HOURS=24
```

### Vercel 部署
在 Vercel 项目设置中添加环境变量（与 Railway 相同）。

## 🔒 安全建议

### 1. 使用应用专用密码
- **Gmail**: 启用两步验证后生成应用专用密码
- **QQ邮箱**: 使用授权码而非登录密码
- **163邮箱**: 使用授权码而非登录密码

### 2. 环境变量安全
- 永远不要在代码中硬编码邮箱密码
- 使用环境变量存储敏感信息
- 定期轮换密码

### 3. 域名配置
- 使用您自己的域名作为发件人地址
- 配置SPF、DKIM、DMARC记录提高邮件送达率

## 🧪 测试邮箱配置

### 本地测试
```bash
# 启动后端服务
cd backend
python main.py

# 测试注册功能
curl -X POST http://localhost:8000/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "testuser",
    "email": "test@example.com",
    "password": "testpassword123"
  }'
```

### 检查日志
查看后端日志确认邮件发送状态：
```
send_email called: to=test@example.com, subject=LinkU 邮箱验证
Email sent successfully
```

## ❗ 常见问题

### 1. 邮件发送失败
**错误**: `Email send failed: (535, b'5.7.8 Username and Password not accepted')`
**解决**: 检查用户名和密码，确保使用应用专用密码

### 2. 连接超时
**错误**: `Email send failed: [Errno 11001] getaddrinfo failed`
**解决**: 检查SMTP服务器地址和端口

### 3. TLS/SSL错误
**错误**: `Email send failed: [SSL: WRONG_VERSION_NUMBER]`
**解决**: 检查 `SMTP_USE_TLS` 和 `SMTP_USE_SSL` 配置

### 4. 邮件被标记为垃圾邮件
**解决**: 
- 配置SPF记录
- 使用专业邮箱服务
- 避免使用免费邮箱作为发件人

## 📋 配置检查清单

- [ ] 邮箱服务商账户已设置
- [ ] 应用专用密码已生成
- [ ] 环境变量已正确配置
- [ ] SMTP服务器和端口正确
- [ ] TLS/SSL配置正确
- [ ] 本地测试通过
- [ ] 生产环境测试通过

## 🔗 相关文档

- [Gmail SMTP 设置](https://support.google.com/mail/answer/7126229)
- [QQ邮箱 SMTP 设置](https://service.mail.qq.com/cgi-bin/help?subtype=1&id=28&no=1001256)
- [163邮箱 SMTP 设置](https://help.mail.163.com/faqDetail.do?code=d7a5dc2feb103dc6656932b06f681a13)
- [Railway 环境变量设置](https://docs.railway.app/guides/environment-variables)
