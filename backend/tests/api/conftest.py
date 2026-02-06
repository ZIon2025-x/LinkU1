"""
API 测试专用 conftest

API 测试通过 HTTP 请求测试远程 Railway 环境，不需要本地数据库连接。
这个文件覆盖根目录的 conftest.py，避免加载 sqlalchemy 等依赖。
"""

import pytest
import os
import sys

# 确保可以导入 tests.config
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def pytest_configure(config):
    """pytest 配置钩子"""
    # 注册自定义标记
    config.addinivalue_line(
        "markers", "requires_config: 标记需要完整配置的测试"
    )


@pytest.fixture(scope="session", autouse=True)
def setup_api_tests():
    """API 测试初始化"""
    print("\n" + "=" * 60)
    print("LinkU API 集成测试")
    print("=" * 60)
    
    # 导入配置会触发安全检查
    try:
        from tests.config import TEST_API_URL, CONFIG_VALID
        if CONFIG_VALID:
            print(f"目标环境: {TEST_API_URL}")
        else:
            print("⚠️ 配置不完整，部分测试将被跳过")
    except Exception as e:
        print(f"配置加载失败: {e}")
    
    print("=" * 60 + "\n")
    
    yield
    
    print("\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)


@pytest.fixture(autouse=True)
def skip_if_config_invalid():
    """自动跳过配置无效时的测试"""
    try:
        from tests.config import CONFIG_VALID, CONFIG_ERROR_MESSAGE
        if not CONFIG_VALID:
            pytest.skip(CONFIG_ERROR_MESSAGE)
    except ImportError:
        pytest.skip("无法加载测试配置")
