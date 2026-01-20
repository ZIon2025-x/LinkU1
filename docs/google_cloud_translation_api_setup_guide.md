# Google Cloud Translation API 完整配置指南

本指南将详细说明如何在 Google Cloud Platform (GCP) 上配置 Translation API，以便在应用中使用。

## 📋 目录

1. [创建 Google Cloud 项目](#1-创建-google-cloud-项目)
2. [启用 Translation API](#2-启用-translation-api)
3. [创建服务账号（推荐方式）](#3-创建服务账号推荐方式)
4. [创建 API 密钥（简单方式）](#4-创建-api-密钥简单方式)
5. [配置环境变量](#5-配置环境变量)
6. [验证配置](#6-验证配置)
7. [费用说明](#7-费用说明)
8. [故障排查](#8-故障排查)

---

## 1. 创建 Google Cloud 项目

### 步骤 1.1: 访问 Google Cloud Console

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 使用您的 Google 账号登录

### 步骤 1.2: 创建新项目

1. 点击页面顶部的项目选择器
2. 点击 **"新建项目"** (New Project)
3. 输入项目名称，例如：`link2ur-translation`
4. 选择组织（如果有）
5. 点击 **"创建"** (Create)

### 步骤 1.3: 选择项目

创建完成后，确保在项目选择器中选择了新创建的项目。

---

## 2. 启用 Translation API

### 步骤 2.1: 导航到 API 库

1. 在左侧菜单中，点击 **"API 和服务"** (APIs & Services) > **"库"** (Library)
2. 或者直接访问：https://console.cloud.google.com/apis/library

### 步骤 2.2: 搜索并启用 Translation API

1. 在搜索框中输入 **"Cloud Translation API"**
2. 点击 **"Cloud Translation API"** 结果
3. 点击 **"启用"** (Enable) 按钮
4. 等待几秒钟，直到 API 启用完成

### 步骤 2.3: 验证启用状态

启用后，您应该看到 **"API 已启用"** (API enabled) 的提示。

---

## 3. 创建服务账号（推荐方式）

服务账号是生产环境推荐的方式，更安全且易于管理。

### 步骤 3.1: 创建服务账号

1. 在左侧菜单中，点击 **"IAM 和管理"** (IAM & Admin) > **"服务账号"** (Service Accounts)
2. 点击页面顶部的 **"创建服务账号"** (Create Service Account)
3. 填写服务账号详情：
   - **服务账号名称**：`translation-service`
   - **服务账号 ID**：会自动生成（例如：`translation-service@your-project.iam.gserviceaccount.com`）
   - **说明**：`用于 Translation API 的服务账号`
4. 点击 **"创建并继续"** (Create and Continue)

### 步骤 3.2: 授予权限

1. 在 **"授予此服务账号对项目的访问权限"** 部分：
   - 角色选择：**"Cloud Translation API User"** 或 **"Cloud Translation API 用户"**
2. 点击 **"继续"** (Continue)
3. 点击 **"完成"** (Done)

### 步骤 3.3: 创建密钥文件

1. 在服务账号列表中，找到刚创建的服务账号
2. 点击服务账号名称进入详情页
3. 点击 **"密钥"** (Keys) 标签页
4. 点击 **"添加密钥"** (Add Key) > **"创建新密钥"** (Create new key)
5. 选择 **JSON** 格式
6. 点击 **"创建"** (Create)
7. 密钥文件会自动下载到您的计算机（文件名类似：`your-project-xxxxx.json`）

⚠️ **重要提示**：
- 妥善保管此 JSON 文件，不要提交到代码仓库
- 如果文件泄露，请立即删除并重新创建

### 步骤 3.4: 查看密钥文件内容

下载的 JSON 文件内容类似：

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "xxxxx",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "translation-service@your-project.iam.gserviceaccount.com",
  "client_id": "xxxxx",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

---

## 4. 创建 API 密钥（简单方式）

如果您不想使用服务账号，可以使用 API 密钥（适合开发环境或 Railway 等无法上传文件的部署环境）。

### 步骤 4.1: 创建 API 密钥

1. 在左侧菜单中，点击 **"API 和服务"** (APIs & Services) > **"凭据"** (Credentials)
2. 点击页面顶部的 **"创建凭据"** (Create Credentials) > **"API 密钥"** (API Key)
3. API 密钥会自动创建并显示
4. 点击 **"复制"** (Copy) 保存密钥（格式类似：`AIzaSy...`）

### 步骤 4.2: 限制 API 密钥（重要！）

为了安全，建议限制 API 密钥的使用范围：

1. 点击刚创建的 API 密钥名称进入编辑页面
2. **应用限制** (Application restrictions)：
   - 选择 **"HTTP 引用来源（网站）"** (HTTP referrers)
   - 添加您的网站域名，例如：
     - `https://api.link2ur.com/*`
     - `https://www.link2ur.com/*`
   - 或者选择 **"无"** (None) 用于开发测试
3. **API 限制** (API restrictions)：
   - 选择 **"限制密钥"** (Restrict key)
   - 勾选 **"Cloud Translation API"**
   - 取消勾选其他 API
4. 点击 **"保存"** (Save)

### 步骤 4.3: 验证 API 密钥

您可以使用以下命令测试 API 密钥是否有效：

```bash
curl "https://translation.googleapis.com/language/translate/v2?key=YOUR_API_KEY&q=hello&target=zh-CN"
```

如果返回 JSON 响应，说明密钥有效。

---

## 5. 配置环境变量

根据您选择的方式（服务账号或 API 密钥），配置相应的环境变量。

### 方式 A: 使用服务账号（推荐生产环境）

#### 本地开发环境

在 `.env` 文件中添加：

```bash
# 翻译服务优先级（Google Cloud 放在最后）
TRANSLATION_SERVICES=google,mymemory,google_cloud

# 方式 1: 使用服务账号 JSON 文件路径
GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH=/path/to/your-project-xxxxx.json

# 或者方式 2: 使用环境变量（Google Cloud 默认方式）
GOOGLE_APPLICATION_CREDENTIALS=/path/to/your-project-xxxxx.json
```

#### Railway 部署环境

由于 Railway 无法直接上传文件，您有两个选择：

**选项 1: 将 JSON 内容作为环境变量**

1. 打开下载的 JSON 文件
2. 将整个 JSON 内容复制
3. 在 Railway Dashboard 中，添加环境变量：
   - 变量名：`GOOGLE_CLOUD_CREDENTIALS_JSON`
   - 变量值：粘贴完整的 JSON 内容（一行）

然后修改代码读取此环境变量（需要额外实现）。

**选项 2: 使用 API 密钥（见方式 B）**

### 方式 B: 使用 API 密钥（推荐 Railway）

#### Railway 部署环境

在 Railway Dashboard 中添加环境变量：

```bash
# 翻译服务优先级（Google Cloud 放在最后）
TRANSLATION_SERVICES=google,mymemory,google_cloud

# Google Cloud Translation API 密钥
GOOGLE_CLOUD_TRANSLATE_API_KEY=AIzaSy...
```

#### 本地开发环境

在 `.env` 文件中添加：

```bash
# 翻译服务优先级（Google Cloud 放在最后）
TRANSLATION_SERVICES=google,mymemory,google_cloud

# Google Cloud Translation API 密钥
GOOGLE_CLOUD_TRANSLATE_API_KEY=AIzaSy...
```

---

## 6. 验证配置

### 步骤 6.1: 检查应用日志

启动应用后，查看日志输出：

**成功配置的日志**：
```
Google Cloud Translation API已配置
翻译服务管理器初始化完成，可用服务: ['google', 'mymemory', 'google_cloud']
```

**配置失败的日志**：
```
WARNING:app.translation_manager:Google Cloud Translation API未配置（需要API密钥或凭据文件），跳过
```

### 步骤 6.2: 通过 API 检查服务状态

```bash
curl https://your-api-url/api/translate/services/status
```

响应示例：

```json
{
  "available_services": ["google", "mymemory", "google_cloud"],
  "failed_services": [],
  "stats": {
    "google": {"success": 10, "failure": 0},
    "mymemory": {"success": 5, "failure": 0},
    "google_cloud": {"success": 0, "failure": 0}
  }
}
```

### 步骤 6.3: 测试翻译功能

尝试翻译一段文本，检查是否使用了 Google Cloud Translation API：

```bash
curl -X POST https://your-api-url/api/translate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello, world!",
    "target_language": "zh-CN"
  }'
```

---

## 7. 费用说明

### 免费额度

- **每月前 500,000 字符免费**
- 超出后按使用量付费

### 定价（2024年）

- **标准翻译**：每 100 万字符 $20 USD
- **高级翻译**：每 100 万字符 $80 USD（支持更多语言对）

### 监控使用量

1. 在 Google Cloud Console 中，点击 **"结算"** (Billing)
2. 查看 **"使用情况"** (Usage) 报告
3. 设置预算提醒，避免意外费用

### 设置预算提醒

1. 在 **"预算和提醒"** (Budgets & alerts) 中
2. 点击 **"创建预算"** (Create Budget)
3. 设置预算金额和提醒阈值
4. 配置通知邮箱

---

## 8. 故障排查

### 问题 1: "API 未启用" 错误

**错误信息**：
```
google.api_core.exceptions.PermissionDenied: 403 Cloud Translation API has not been used in project
```

**解决方法**：
1. 确认已启用 Cloud Translation API
2. 检查服务账号或 API 密钥是否有正确的权限

### 问题 2: "API 密钥无效" 错误

**错误信息**：
```
google.api_core.exceptions.InvalidArgument: 400 API key not valid
```

**解决方法**：
1. 检查 API 密钥是否正确复制（没有多余空格）
2. 确认 API 密钥已启用 Cloud Translation API 限制
3. 检查应用限制（HTTP 引用来源）是否正确

### 问题 3: "服务账号权限不足" 错误

**错误信息**：
```
google.api_core.exceptions.PermissionDenied: 403 Permission denied
```

**解决方法**：
1. 确认服务账号已授予 **"Cloud Translation API User"** 角色
2. 检查服务账号是否属于正确的项目

### 问题 4: "找不到凭据文件" 错误

**错误信息**：
```
FileNotFoundError: [Errno 2] No such file or directory: '/path/to/credentials.json'
```

**解决方法**：
1. 检查文件路径是否正确
2. 确认文件权限（应该可读）
3. 对于 Railway，考虑使用 API 密钥方式

### 问题 5: "Client.__init__() got an unexpected keyword argument 'api_key'"

**错误信息**：
```
TypeError: Client.__init__() got an unexpected keyword argument 'api_key'
```

**解决方法**：
- 此问题已在代码中修复，使用 REST API 方式调用
- 如果仍出现，请确保使用最新版本的代码

### 问题 6: 翻译服务优先级问题

**现象**：即使配置了 Google Cloud，仍优先使用其他服务

**解决方法**：
1. 检查环境变量 `TRANSLATION_SERVICES` 的顺序
2. 确认 Google Cloud 配置正确（API 密钥或服务账号）
3. 查看日志确认服务初始化顺序

---

## 9. 最佳实践

### 安全建议

1. ✅ **不要将 API 密钥或服务账号 JSON 提交到代码仓库**
2. ✅ **使用环境变量存储敏感信息**
3. ✅ **限制 API 密钥的使用范围（HTTP 引用来源和 API 限制）**
4. ✅ **定期轮换 API 密钥**
5. ✅ **监控 API 使用情况，设置预算提醒**

### 性能优化

1. ✅ **使用缓存减少 API 调用**
2. ✅ **批量翻译文本（如果支持）**
3. ✅ **合理设置重试机制**
4. ✅ **监控服务统计，优化服务优先级**

### 成本优化

1. ✅ **充分利用每月 50 万字符的免费额度**
2. ✅ **优先使用免费服务（google, mymemory）**
3. ✅ **将 Google Cloud 作为备选服务**
4. ✅ **监控使用量，避免超出预算**

---

## 10. 相关资源

- [Google Cloud Translation API 官方文档](https://cloud.google.com/translate/docs)
- [API 参考文档](https://cloud.google.com/translate/docs/reference/rest)
- [定价信息](https://cloud.google.com/translate/pricing)
- [服务账号最佳实践](https://cloud.google.com/iam/docs/best-practices-service-accounts)

---

## 总结

配置 Google Cloud Translation API 的步骤：

1. ✅ 创建 Google Cloud 项目
2. ✅ 启用 Cloud Translation API
3. ✅ 创建服务账号或 API 密钥
4. ✅ 配置环境变量
5. ✅ 验证配置
6. ✅ 监控使用量和费用

**推荐配置**：
- **开发环境**：使用 API 密钥（简单）
- **生产环境**：使用服务账号（更安全）
- **Railway 部署**：使用 API 密钥（无法上传文件）

**优先级设置**：
```bash
TRANSLATION_SERVICES=google,mymemory,google_cloud
```

这样会优先使用免费服务，Google Cloud 作为最后的备选。
