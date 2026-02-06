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


@pytest.fixture(scope="session", autouse=True)
def setup_api_tests():
    """API 测试初始化"""
    print("\n" + "=" * 60)
    print("LinkU API 集成测试")
    print("=" * 60)
    
    # 导入配置会触发安全检查
    try:
        from tests.config import TEST_API_URL
        print(f"目标环境: {TEST_API_URL}")
    except Exception as e:
        print(f"配置加载失败: {e}")
    
    print("=" * 60 + "\n")
    
    yield
    
    print("\n" + "=" * 60)
    print("测试完成")
    print("=" * 60)
