# LinkU API 测试指南

## 快速开始

### 1. 安装测试依赖

```bash
cd backend
pip install -r requirements-test.txt
```

### 2. 配置环境变量

```bash
# 必需：Railway 测试环境 URL（绝对不能是生产环境！）
export TEST_API_URL="https://your-test-app.up.railway.app"

# 可选：测试账号（用于需要认证的测试）
export TEST_USER_EMAIL="test@example.com"
export TEST_USER_PASSWORD="your-test-password"

# 可选：Stripe 测试密钥（必须是 sk_test_ 开头）
export STRIPE_TEST_SECRET_KEY="sk_test_xxx"
```

### 3. 运行测试

```bash
# 运行所有 API 测试
pytest tests/api/ -v

# 只运行认证测试
pytest tests/api/test_auth_api.py -v

# 只运行任务测试
pytest tests/api/test_task_api.py -v

# 只运行支付测试
pytest tests/api/test_payment_api.py -v

# 使用标记筛选
pytest tests/api/ -v -m auth    # 只运行 @pytest.mark.auth 标记的测试
pytest tests/api/ -v -m task    # 只运行 @pytest.mark.task 标记的测试
pytest tests/api/ -v -m payment # 只运行 @pytest.mark.payment 标记的测试
```

## 测试结构

```
tests/
├── README.md           # 本文件
├── config.py           # 测试配置（含安全检查）
├── conftest.py         # pytest 公共 fixtures
└── api/                # API 集成测试
    ├── __init__.py
    ├── test_auth_api.py     # 认证 API 测试
    ├── test_task_api.py     # 任务 API 测试
    └── test_payment_api.py  # 支付 API 测试
```

## 安全措施

测试框架内置多重安全检查，防止误操作生产环境：

1. **URL 检查**：`TEST_API_URL` 不能包含生产域名
2. **Stripe 密钥检查**：必须使用 `sk_test_` 开头的测试密钥
3. **启动时验证**：加载测试配置时自动执行安全检查

如果配置错误，测试会立即终止并显示错误信息。

## GitHub Actions 自动测试

每次 push 到 `main` 或 `develop` 分支时，GitHub Actions 会自动运行测试。

### 需要配置的 Secrets

在 GitHub 仓库设置 → Secrets and variables → Actions 中添加：

| Secret 名称 | 说明 | 示例 |
|------------|------|------|
| `TEST_API_URL` | Railway 测试环境 URL | `https://xxx-test.up.railway.app` |
| `TEST_USER_EMAIL` | 测试账号邮箱 | `test@example.com` |
| `TEST_USER_PASSWORD` | 测试账号密码 | `TestPass123!` |
| `STRIPE_TEST_SECRET_KEY` | Stripe 测试密钥 (可选) | `sk_test_xxx` |

### 手动触发测试

可以在 GitHub Actions 页面手动触发测试，支持临时覆盖测试 URL。

## 添加新测试

### 示例：添加新的 API 测试

```python
# tests/api/test_new_feature.py

import pytest
import httpx
from tests.config import TEST_API_URL, REQUEST_TIMEOUT

class TestNewFeatureAPI:
    """新功能 API 测试"""

    @pytest.fixture(autouse=True)
    def setup(self):
        self.base_url = TEST_API_URL
        self.timeout = REQUEST_TIMEOUT

    @pytest.mark.api
    def test_new_endpoint(self):
        """测试新端点"""
        with httpx.Client(timeout=self.timeout) as client:
            response = client.get(f"{self.base_url}/api/new-endpoint")
            assert response.status_code == 200
```

## 常见问题

### Q: 测试显示 "安全检查失败"

检查 `TEST_API_URL` 是否包含生产环境地址。测试只能指向测试环境。

### Q: 测试显示 "缺少必需的环境变量"

确保设置了 `TEST_API_URL` 环境变量。

### Q: 部分测试被跳过

如果测试账号未配置（`TEST_USER_EMAIL`、`TEST_USER_PASSWORD`），需要认证的测试会被跳过。

### Q: 如何在 CI 中调试

查看 GitHub Actions 日志，或下载测试产物（test-results）查看详细输出。
