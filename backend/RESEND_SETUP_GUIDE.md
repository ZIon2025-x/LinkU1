# 📧 Resend邮件服务配置指南

## 🎯 问题解决

**问题**：Railway已永久阻止出站SMTP连接，导致邮件发送失败
**解决方案**：使用Resend邮件服务（Railway官方推荐）

## 🚀 快速设置

### 步骤1：注册Resend账户

1. **访问Resend官网**：https://resend.com
2. **注册免费账户**：每月3000封邮件免费
3. **验证邮箱**：完成账户验证

### 步骤2：获取API Key

1. **登录Resend控制台**
2. **进入API Keys页面**
3. **创建新的API Key**
4. **复制API Key**（只显示一次）

### 步骤3：配置Railway环境变量

在Railway控制台设置以下环境变量：

```env
# Resend配置
USE_RESEND=true
RESEND_API_KEY=your-resend-api-key-here
EMAIL_FROM=zixiong316@gmail.com

# 其他邮件配置
EMAIL_VERIFICATION_EXPIRE_HOURS=24
SKIP_EMAIL_VERIFICATION=false
```

### 步骤4：重新部署应用

1. **在Railway控制台点击"Redeploy"**
2. **等待部署完成**
3. **测试邮件功能**

## 🔧 技术实现

### 邮件发送优先级

系统会按以下优先级选择邮件服务：

1. **Resend**（推荐）- 如果配置了RESEND_API_KEY
2. **SendGrid** - 如果配置了SENDGRID_API_KEY
3. **SMTP** - 作为最后备选（在Railway上不可用）

### 代码实现

```python
def send_email(to_email, subject, body):
    """智能邮件发送 - 优先使用Resend"""
    
    # 检查是否使用Resend
    if Config.USE_RESEND and Config.RESEND_API_KEY:
        print("使用Resend发送邮件")
        return send_email_resend(to_email, subject, body)
    
    # 检查是否使用SendGrid
    if Config.USE_SENDGRID and Config.SENDGRID_API_KEY:
        print("使用SendGrid发送邮件")
        return send_email_sendgrid(to_email, subject, body)
    
    # 回退到SMTP
    print("使用SMTP发送邮件")
    return send_email_smtp(to_email, subject, body)
```

## 📋 环境变量说明

### 必需的环境变量

```env
# Resend配置
USE_RESEND=true
RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EMAIL_FROM=zixiong316@gmail.com
```

### 可选的环境变量

```env
# 邮件验证配置
EMAIL_VERIFICATION_EXPIRE_HOURS=24
SKIP_EMAIL_VERIFICATION=false

# 基础URL配置
BASE_URL=https://linku1-production.up.railway.app
FRONTEND_URL=https://link-u1.vercel.app
```

## 🎯 优势对比

### Resend vs SMTP

| 特性 | Resend | SMTP |
|------|--------|------|
| Railway支持 | ✅ 完全支持 | ❌ 被阻止 |
| 网络连接 | ✅ HTTPS API | ❌ 端口阻塞 |
| 配置复杂度 | ✅ 简单 | ❌ 复杂 |
| 可靠性 | ✅ 高 | ❌ 低 |
| 免费额度 | ✅ 3000封/月 | ❌ 无限制 |

### Resend vs SendGrid

| 特性 | Resend | SendGrid |
|------|--------|----------|
| Railway推荐 | ✅ 官方推荐 | ⚠️ 支持 |
| 免费额度 | ✅ 3000封/月 | ✅ 100封/月 |
| 配置简单 | ✅ 简单 | ✅ 简单 |
| 性能 | ✅ 优秀 | ✅ 优秀 |

## 🔍 故障排除

### 常见问题

1. **API Key无效**
   - 检查API Key是否正确复制
   - 确认API Key有发送权限

2. **邮件未发送**
   - 检查USE_RESEND是否为true
   - 检查RESEND_API_KEY是否设置
   - 查看Railway部署日志

3. **邮件被过滤**
   - 检查邮箱垃圾邮件文件夹
   - 确认EMAIL_FROM域名已验证

### 调试步骤

1. **检查环境变量**：
   ```bash
   echo $USE_RESEND
   echo $RESEND_API_KEY
   ```

2. **查看应用日志**：
   - 在Railway控制台查看部署日志
   - 查找"使用Resend发送邮件"消息

3. **测试邮件发送**：
   - 使用忘记密码功能
   - 检查是否收到邮件

## 📋 总结

**Resend是Railway平台的最佳邮件解决方案**：

- ✅ 完全兼容Railway平台
- ✅ 配置简单，只需API Key
- ✅ 免费额度充足（3000封/月）
- ✅ 性能稳定可靠
- ✅ Railway官方推荐

完成配置后，邮件发送功能应该可以正常工作了！
