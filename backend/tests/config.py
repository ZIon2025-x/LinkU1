"""
LinkU API 测试配置

重要安全措施：
- 测试只能运行在测试环境，绝不能指向生产环境
- 必须使用 Stripe 测试密钥（sk_test_ 开头）
- 测试账号与真实用户完全隔离
"""

import os
import sys

# =============================================================================
# 生产环境保护列表 - 绝对不允许测试指向这些地址
# =============================================================================
PRODUCTION_URLS = [
    "api.link2ur.com",
    "link2ur.com",
    "www.link2ur.com",
    "linku1-production.up.railway.app",
    # 如果有其他生产域名，在这里添加
]

# =============================================================================
# 测试环境配置
# =============================================================================

# 测试 API URL - 必须是 Railway 测试环境
TEST_API_URL = os.getenv("TEST_API_URL", "")

# 测试账号
TEST_USER_EMAIL = os.getenv("TEST_USER_EMAIL", "")
TEST_USER_PASSWORD = os.getenv("TEST_USER_PASSWORD", "")

# Stripe 测试密钥
STRIPE_TEST_SECRET_KEY = os.getenv("STRIPE_TEST_SECRET_KEY", "")

# 测试超时时间（秒）
REQUEST_TIMEOUT = int(os.getenv("TEST_REQUEST_TIMEOUT", "30"))

# 配置状态标志
CONFIG_VALID = True
CONFIG_ERROR_MESSAGE = ""

# =============================================================================
# 安全检查 - 防止误操作生产环境
# =============================================================================

def _validate_test_environment():
    """
    验证测试环境配置的安全性
    如果检测到生产环境配置，立即终止测试（安全问题必须阻止）
    """
    global CONFIG_VALID, CONFIG_ERROR_MESSAGE
    errors = []
    
    # 检查 1: TEST_API_URL 不能包含生产环境地址
    if TEST_API_URL:
        for prod_url in PRODUCTION_URLS:
            if prod_url.lower() in TEST_API_URL.lower():
                errors.append(
                    f"TEST_API_URL 包含生产环境地址 '{prod_url}'!\n"
                    f"当前值: {TEST_API_URL}\n"
                    "请使用测试环境 URL（如 xxx-test.up.railway.app）"
                )
    
    # 检查 2: Stripe 密钥必须是测试密钥
    if STRIPE_TEST_SECRET_KEY:
        if not STRIPE_TEST_SECRET_KEY.startswith("sk_test_"):
            errors.append(
                "STRIPE_TEST_SECRET_KEY 不是测试密钥!\n"
                "测试必须使用 'sk_test_' 开头的测试密钥\n"
                "当前密钥开头: " + STRIPE_TEST_SECRET_KEY[:10] + "..."
            )
    
    # 检查 3: 确保测试邮箱不是真实用户常用域名（可选警告）
    if TEST_USER_EMAIL:
        real_domains = ["gmail.com", "qq.com", "163.com", "outlook.com", "icloud.com"]
        domain = TEST_USER_EMAIL.split("@")[-1] if "@" in TEST_USER_EMAIL else ""
        if domain in real_domains:
            print(
                f"⚠️  警告: TEST_USER_EMAIL 使用真实邮箱域名 '{domain}'\n"
                "建议使用专用测试邮箱或 example.com 域名"
            )
    
    # 如果有安全错误，必须终止测试（不能允许对生产环境进行测试）
    if errors:
        print("\n" + "=" * 60)
        print("❌ 安全检查失败 - 测试已终止")
        print("=" * 60)
        for i, error in enumerate(errors, 1):
            print(f"\n错误 {i}:")
            print(error)
        print("\n" + "=" * 60)
        print("请修正以上配置后重新运行测试")
        print("=" * 60 + "\n")
        sys.exit(1)


def _validate_required_config():
    """
    验证必需的配置项
    不再使用 sys.exit()，而是设置标志让测试跳过
    """
    global CONFIG_VALID, CONFIG_ERROR_MESSAGE
    missing = []
    
    if not TEST_API_URL:
        missing.append("TEST_API_URL")
    
    if missing:
        CONFIG_VALID = False
        CONFIG_ERROR_MESSAGE = f"缺少必需的环境变量: {', '.join(missing)}"
        print("\n" + "=" * 60)
        print("⚠️  缺少必需的环境变量 - API 测试将被跳过")
        print("=" * 60)
        print("\n请设置以下环境变量:")
        for var in missing:
            print(f"  export {var}='your-value'")
        print("\n示例:")
        print("  export TEST_API_URL='https://your-test-app.up.railway.app'")
        print("  export TEST_USER_EMAIL='test@example.com'")
        print("  export TEST_USER_PASSWORD='your-test-password'")
        print("=" * 60 + "\n")
        # 不再调用 sys.exit(1)，让测试可以被收集并跳过


def require_config(func):
    """
    装饰器：如果配置无效，跳过测试
    """
    import functools
    import pytest
    
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        if not CONFIG_VALID:
            pytest.skip(CONFIG_ERROR_MESSAGE)
        return func(*args, **kwargs)
    return wrapper


# 模块加载时执行安全检查
_validate_test_environment()
_validate_required_config()

# 打印测试环境信息（仅当配置有效时）
if CONFIG_VALID:
    print("\n" + "=" * 60)
    print("✅ 测试环境配置验证通过")
    print("=" * 60)
    print(f"  API URL: {TEST_API_URL}")
    print(f"  测试账号: {TEST_USER_EMAIL or '(未配置)'}")
    print(f"  Stripe: {'已配置' if STRIPE_TEST_SECRET_KEY else '未配置'}")
    print("=" * 60 + "\n")
