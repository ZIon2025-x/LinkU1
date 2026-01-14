# APNs 推送通知配置指南（Railway）

本指南将帮助你配置 APNs 推送通知到 Railway 后端服务器。

## 前提条件

1. ✅ 已从 Apple Developer 下载 `.p8` 密钥文件
2. ✅ 已记录 Key ID（10位字符，如 `ABC123DEFG`）
3. ✅ 已记录 Team ID（可在 Apple Developer 账号首页查看）

## 步骤 1：将 .p8 文件转换为 Base64 编码

### macOS/Linux 方法：

```bash
# 在终端中运行（替换为你的实际文件路径）
base64 -i AuthKey_XXX.p8 | tr -d '\n'
```

### Windows 方法：

使用 PowerShell：
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXX.p8"))
```

### 在线工具（不推荐，安全性较低）：

如果无法使用命令行，可以使用在线 Base64 编码工具，但**不推荐**，因为会暴露密钥内容。

## 步骤 2：在 Railway 中配置环境变量

1. 登录 [Railway Dashboard](https://railway.app)
2. 选择你的项目
3. 进入 **Variables** 标签页
4. 添加以下环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `APNS_KEY_ID` | `你的Key ID` | 10位字符，如 `ABC123DEFG` |
| `APNS_TEAM_ID` | `你的Team ID` | 可在 Apple Developer 账号首页查看 |
| `APNS_BUNDLE_ID` | `com.link2ur.app` | 你的 App Bundle ID |
| `APNS_KEY_CONTENT` | `Base64编码的密钥内容` | 从步骤1获取的完整Base64字符串 |
| `APNS_USE_SANDBOX` | `false` | 生产环境设为 `false`，开发/测试环境设为 `true` |

### 示例配置：

```
APNS_KEY_ID=ABC123DEFG
APNS_TEAM_ID=XYZ789TEAM
APNS_BUNDLE_ID=com.link2ur.app
APNS_KEY_CONTENT=LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRRG5uV...
APNS_USE_SANDBOX=false
```

## 步骤 3：验证配置

配置完成后，Railway 会自动重新部署。检查日志确认：

1. 在 Railway Dashboard 中查看 **Deployments** 标签页
2. 查看最新部署的日志
3. 确认没有 APNs 相关的错误信息

## 步骤 4：测试推送通知

配置完成后，可以通过以下方式测试：

1. 在 iOS 应用中注册推送通知
2. 触发一个需要发送推送通知的操作（如任务申请、消息等）
3. 检查设备是否收到推送通知

## 常见问题

### Q: 如何查看 Team ID？

A: 登录 [Apple Developer](https://developer.apple.com/account)，在右上角可以看到 Team ID。

### Q: 如何查看 Key ID？

A: 在创建 APNs Key 时，Key ID 会显示在页面上。如果忘记了，可以在 [Keys 列表](https://developer.apple.com/account/resources/authkeys/list) 中查看。

### Q: 生产环境和沙盒环境的区别？

A:
- **沙盒环境** (`APNS_USE_SANDBOX=true`): 用于开发和测试，使用 `api.sandbox.push.apple.com`
- **生产环境** (`APNS_USE_SANDBOX=false`): 用于正式发布，使用 `api.push.apple.com`

### Q: 如何确认配置是否正确？

A: 查看 Railway 日志，如果看到 "已从环境变量加载 APNs 密钥" 的日志，说明配置成功。

### Q: 密钥文件安全吗？

A: 
- ✅ 密钥内容存储在 Railway 的环境变量中，是加密的
- ✅ 代码会在运行时创建临时文件，并设置严格的权限（600）
- ✅ 临时文件在服务器重启后会自动清理

## 注意事项

1. **不要**将 `.p8` 文件提交到 Git 仓库
2. **不要**在代码中硬编码密钥内容
3. **不要**在日志中输出密钥内容
4. 如果密钥泄露，立即在 Apple Developer 中撤销并重新创建

## 相关文件

- `backend/app/push_notification_service.py` - 推送通知服务实现
- `backend/production.env.template` - 环境变量模板
