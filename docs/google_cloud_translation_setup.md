# Google Cloud Translation API 配置指南

## 概述

Google Cloud Translation API 是 Google 官方提供的翻译服务，**每月前 50 万字符免费**，非常适合生产环境使用。

## 配置步骤

### 1. 创建 Google Cloud 项目

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 记录项目ID

### 2. 启用 Cloud Translation API

1. 在控制台左侧菜单，导航至 **"API 和服务" > "库"**
2. 搜索 **"Cloud Translation API"**
3. 点击进入详情页
4. 点击 **"启用"** 按钮

### 3. 创建凭据

有两种方式配置凭据：

#### 方式1：使用 API 密钥（简单，适合开发环境）

1. 在控制台左侧菜单，导航至 **"API 和服务" > "凭据"**
2. 点击 **"创建凭据" > "API 密钥"**
3. 复制生成的 API 密钥
4. 在环境变量中配置：
   ```bash
   GOOGLE_CLOUD_TRANSLATE_API_KEY=your_api_key_here
   ```

#### 方式2：使用服务账号（推荐，适合生产环境）

1. 在控制台左侧菜单，导航至 **"IAM 和管理" > "服务账号"**
2. 点击 **"创建服务账号"**
3. 填写服务账号名称和描述
4. 点击 **"创建并继续"**
5. 授予角色：**"Cloud Translation API User"**
6. 点击 **"完成"**
7. 点击创建的服务账号，进入 **"密钥"** 标签
8. 点击 **"添加密钥" > "创建新密钥"**
9. 选择 **JSON** 格式，下载密钥文件
10. 将密钥文件保存到服务器安全位置（如 `/path/to/credentials.json`）
11. 在环境变量中配置：
    ```bash
    GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH=/path/to/credentials.json
    ```
    或者使用 Google Cloud 默认方式：
    ```bash
    GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
    ```

### 4. 设置结算账户

⚠️ **重要**：虽然每月前 50 万字符免费，但仍需设置结算账户以防止服务中断。

1. 在控制台左侧菜单，导航至 **"结算" > "管理结算账户"**
2. 按照提示添加有效的支付方式
3. 关联到您的项目

### 5. 配置环境变量

在 `.env` 文件或生产环境配置中添加：

```bash
# 翻译服务优先级（google_cloud优先）
TRANSLATION_SERVICES=google_cloud,google,mymemory

# Google Cloud Translation API配置（选择一种方式）

# 方式1：使用API密钥
GOOGLE_CLOUD_TRANSLATE_API_KEY=your_api_key_here

# 方式2：使用服务账号JSON文件路径
GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH=/path/to/credentials.json

# 方式3：使用环境变量（Google Cloud默认方式）
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json
```

### 6. 安装依赖

#### 方式1：自动安装（推荐）

使用提供的安装脚本自动检测并安装缺失的依赖：

**Bash脚本**:
```bash
cd backend
./scripts/install_translation_deps.sh
```

**Python脚本**:
```bash
cd backend
python3 scripts/install_translation_deps.py
```

#### 方式2：手动安装

确保已安装 Google Cloud Translation 客户端库：

```bash
pip install google-cloud-translate>=3.15.0
```

或在 `requirements.txt` 中已包含：
```
google-cloud-translate>=3.15.0
```

#### 方式3：安装所有依赖

```bash
pip install -r requirements.txt
```

#### 自动检查

应用启动时会自动检查依赖，如果缺失会显示清晰的安装提示：

```
⚠️  部分翻译服务依赖缺失，某些翻译功能可能不可用
   建议运行以下命令安装缺失的依赖:
     pip install google-cloud-translate
   或安装所有翻译依赖: pip install -r requirements.txt
```

### 7. 验证配置

启动应用后，检查日志：

```
翻译服务管理器初始化完成，可用服务: ['google_cloud', 'google', 'mymemory']
Google Cloud Translation API已配置
```

或通过API检查服务状态：

```bash
curl http://your-api-url/api/translate/services/status
```

## 配置优先级

系统会按以下顺序尝试翻译服务：

1. **Google Cloud Translation API**（官方API，推荐）
   - 每月前 50 万字符免费
   - 翻译质量高
   - 稳定可靠

2. **Google Translator**（deep-translator免费版）
   - 作为备选
   - 可能有限制

3. **MyMemory Translator**
   - 免费备选
   - 质量中等

## 免费额度

- **每月前 50 万字符免费**
- 超出部分按 [Google Cloud 定价](https://cloud.google.com/translate/pricing) 收费
- 建议监控使用量，避免超出免费额度

## 监控使用量

1. 在 Google Cloud Console 中，导航至 **"API 和服务" > "仪表板"**
2. 选择 **"Cloud Translation API"**
3. 查看使用量和配额

## 安全建议

### 生产环境

1. **使用服务账号**（推荐）
   - 更安全
   - 可以设置细粒度权限
   - 密钥文件需要妥善保管

2. **限制API密钥权限**
   - 如果使用API密钥，限制只能访问 Cloud Translation API
   - 在控制台中设置API密钥限制

3. **保护凭据文件**
   - 不要将凭据文件提交到代码仓库
   - 使用环境变量或密钥管理服务
   - 设置适当的文件权限（如 600）

### 开发环境

- 可以使用API密钥（简单方便）
- 但不要将密钥提交到代码仓库

## 故障排查

### 问题1：导入错误

```
ImportError: No module named 'google.cloud'
```

**解决方案**：
```bash
pip install google-cloud-translate
```

### 问题2：认证失败

```
google.auth.exceptions.DefaultCredentialsError: Could not automatically determine credentials
```

**解决方案**：
- 检查 `GOOGLE_CLOUD_TRANSLATE_API_KEY` 或 `GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH` 是否配置
- 检查凭据文件路径是否正确
- 检查服务账号是否有 Cloud Translation API 权限

### 问题3：配额超限

```
google.api_core.exceptions.ResourceExhausted: Quota exceeded
```

**解决方案**：
- 检查是否超出免费额度（50万字符/月）
- 在控制台查看使用量
- 考虑升级到付费计划或使用其他备选服务

## 测试配置

可以通过以下方式测试配置：

```python
from app.translation_manager import get_translation_manager

manager = get_translation_manager()
result = manager.translate("Hello, world!", "zh-CN", "en")
print(result)  # 应该输出：你好，世界！
```

## 优势

1. **官方API**：稳定可靠，质量高
2. **免费额度**：每月前 50 万字符免费
3. **自动降级**：如果失败，自动切换到其他服务
4. **生产就绪**：适合生产环境使用

## 注意事项

1. **结算账户**：即使使用免费额度，也需要设置结算账户
2. **使用监控**：定期检查使用量，避免超出免费额度
3. **密钥安全**：妥善保管API密钥或服务账号文件
4. **备选服务**：配置多个备选服务，确保高可用性
