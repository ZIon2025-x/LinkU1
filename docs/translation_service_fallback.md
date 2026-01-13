# 翻译服务备选机制

## 功能概述

实现了多翻译服务备选机制，当Google翻译被限制或不可用时，系统会自动切换到其他翻译服务，确保翻译功能的连续性和稳定性。

## 核心特性

### 1. 多服务支持

**支持的翻译服务**:
- ⭐ **Google Cloud Translation API** - 官方API（推荐，每月前50万字符免费）
- ✅ **Google Translator** - deep-translator免费版（备选，可能有限制）
- ✅ **MyMemory Translator** - 备选服务（免费，无需API密钥）
- 🔧 **Baidu Translator** - 需要API密钥（可选）
- 🔧 **Youdao Translator** - 需要API密钥（可选）
- 🔧 **DeepL Translator** - 需要API密钥（可选）
- 🔧 **Microsoft Translator** - 需要API密钥（可选）

### 2. 自动降级机制

**工作流程**:
```
尝试 Google Cloud Translation API（官方API）
    ↓ (失败)
尝试 Google Translator（免费版）
    ↓ (失败)
尝试 MyMemory Translator
    ↓ (失败)
尝试其他配置的服务
    ↓ (全部失败)
返回错误
```

### 3. 智能故障检测

- **失败记录**: 自动记录失败的服务，避免重复尝试
- **服务统计**: 记录每个服务的成功/失败次数
- **自动恢复**: 可以定期重置失败记录，重新尝试

## 实现细节

### 翻译服务管理器

**位置**: `backend/app/translation_manager.py`

**核心类**: `TranslationManager`

**主要方法**:
- `translate()` - 翻译文本，自动尝试多个服务
- `reset_failed_services()` - 重置失败服务记录
- `get_service_stats()` - 获取服务统计信息
- `get_available_services()` - 获取可用服务列表

### 配置

**位置**: `backend/app/config.py`

**环境变量**:
```bash
# 翻译服务优先级（用逗号分隔，按优先级排序）
# google_cloud: Google Cloud Translation API（官方API，推荐）
# google: deep-translator的Google翻译（免费版）
TRANSLATION_SERVICES=google_cloud,google,mymemory

# Google Cloud Translation API配置（推荐使用，每月前50万字符免费）
# 方式1：使用API密钥（简单）
GOOGLE_CLOUD_TRANSLATE_API_KEY=your_api_key_here

# 方式2：使用服务账号JSON文件路径（更安全，推荐生产环境）
GOOGLE_CLOUD_TRANSLATE_CREDENTIALS_PATH=/path/to/credentials.json

# 方式3：使用环境变量（Google Cloud默认方式）
GOOGLE_APPLICATION_CREDENTIALS=/path/to/credentials.json

# 其他翻译服务API密钥（可选）
BAIDU_TRANSLATE_APPID=your_appid
BAIDU_TRANSLATE_SECRET=your_secret
YOUDAO_TRANSLATE_APPID=your_appid
YOUDAO_TRANSLATE_SECRET=your_secret
DEEPL_API_KEY=your_api_key
MICROSOFT_TRANSLATE_KEY=your_api_key
```

**详细配置指南**: 请参考 `docs/google_cloud_translation_setup.md`

## 安装依赖

### 自动安装（推荐）

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

### 手动安装

```bash
# 安装所有翻译依赖
pip install deep-translator google-cloud-translate

# 或从requirements.txt安装
pip install -r requirements.txt
```

### 启动时自动检查

应用启动时会自动检查依赖，如果缺失会显示清晰的安装提示。

## 使用方式

### 基本使用

```python
from app.translation_manager import get_translation_manager

manager = get_translation_manager()
translated = manager.translate(
    text="Hello, world!",
    target_lang="zh-CN",
    source_lang="en",
    max_retries=3
)
```

### 自动降级

系统会自动按优先级尝试服务，无需手动处理：

```python
# Google失败 → 自动尝试MyMemory
# MyMemory失败 → 自动尝试下一个服务
# 所有服务失败 → 返回None
```

## API端点

### 1. 获取翻译服务状态

**GET** `/api/translate/services/status`

**返回**:
```json
{
  "available_services": ["google", "mymemory"],
  "failed_services": [],
  "stats": {
    "google": {
      "success": 100,
      "failure": 2
    },
    "mymemory": {
      "success": 5,
      "failure": 0
    }
  }
}
```

### 2. 重置翻译服务状态

**POST** `/api/translate/services/reset`

**返回**:
```json
{
  "success": true,
  "message": "翻译服务失败记录已重置"
}
```

## 配置示例

### 默认配置（免费服务）

```bash
TRANSLATION_SERVICES=google,mymemory
```

### 包含付费服务

```bash
TRANSLATION_SERVICES=google,mymemory,baidu,youdao
BAIDU_TRANSLATE_APPID=your_appid
BAIDU_TRANSLATE_SECRET=your_secret
YOUDAO_TRANSLATE_APPID=your_appid
YOUDAO_TRANSLATE_SECRET=your_secret
```

## 优势

1. **高可用性**: 多个服务备选，确保翻译功能不中断
2. **自动切换**: 无需人工干预，自动降级到可用服务
3. **智能管理**: 自动记录失败服务，避免重复尝试
4. **灵活配置**: 支持通过环境变量配置服务优先级
5. **统计监控**: 记录服务使用情况，便于分析和优化

## 工作流程

```
用户请求翻译
    ↓
翻译管理器接收请求
    ↓
按优先级尝试服务1（Google）
    ↓ (失败)
按优先级尝试服务2（MyMemory）
    ↓ (失败)
按优先级尝试服务3（其他）
    ↓ (成功)
返回翻译结果
    ↓
更新服务统计
```

## 服务特性对比

| 服务 | 免费 | 需要API密钥 | 翻译质量 | 速度 | 限流 | 免费额度 |
|------|------|------------|---------|------|------|---------|
| Google Cloud API | ✅ | ✅ | ⭐⭐⭐⭐⭐ | 快 | 高 | 50万字符/月 |
| Google (免费版) | ✅ | ❌ | ⭐⭐⭐⭐⭐ | 快 | 中等 | 无限制（可能有限制） |
| MyMemory | ✅ | ❌ | ⭐⭐⭐ | 中等 | 低 | 无限制 |
| Baidu | ❌ | ✅ | ⭐⭐⭐⭐ | 快 | 高 | 需付费 |
| Youdao | ❌ | ✅ | ⭐⭐⭐⭐ | 快 | 高 | 需付费 |
| DeepL | ❌ | ✅ | ⭐⭐⭐⭐⭐ | 快 | 高 | 需付费 |

## 故障处理

### 服务失败处理

1. **自动标记**: 失败的服务会被标记，暂时跳过
2. **重试机制**: 每个服务内部有重试机制（最多3次）
3. **降级切换**: 自动切换到下一个可用服务
4. **统计记录**: 记录失败次数，便于分析

### 恢复机制

- **手动重置**: 通过API重置失败记录
- **定期重置**: 可以设置定时任务定期重置（建议每小时）
- **自动恢复**: 下次请求时会重新尝试失败的服务

## 监控和日志

### 日志记录

- **成功日志**: 记录使用的服务和翻译结果
- **失败日志**: 记录失败的服务和错误信息
- **统计信息**: 记录每个服务的成功/失败次数

### 监控指标

- 服务可用性
- 服务响应时间
- 服务成功率
- 服务失败率

## 最佳实践

1. **服务配置**: 优先使用免费服务（Google + MyMemory）
2. **API密钥**: 如果需要更好的质量，配置付费服务
3. **监控**: 定期检查服务状态和统计信息
4. **重置**: 定期重置失败记录，给服务恢复的机会
5. **缓存**: 充分利用缓存，减少对翻译服务的依赖

## 未来优化

1. **负载均衡**: 根据服务响应时间动态调整优先级
2. **健康检查**: 定期检查服务健康状态
3. **智能选择**: 根据文本类型选择最适合的服务
4. **成本优化**: 根据使用量和成本选择服务
5. **质量评估**: 评估翻译质量，选择最佳服务
