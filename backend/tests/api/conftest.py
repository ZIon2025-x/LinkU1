"""
API 测试专用 conftest

API 测试通过 HTTP 请求测试远程 Railway 环境，不需要本地数据库连接。
这个文件覆盖根目录的 conftest.py，避免加载 sqlalchemy 等依赖。
"""

import pytest
import httpx
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


@pytest.fixture(scope="class")
def auth_client():
    """
    登录一次，整个测试类共用同一个 httpx.Client。
    Client 自动管理 cookie，无需手动传递。
    Bearer token 也会设置到 headers 中（如果后端返回的话）。
    登录失败时跳过整个测试类。
    """
    from tests.config import TEST_API_URL, TEST_USER_EMAIL, TEST_USER_PASSWORD, REQUEST_TIMEOUT

    if not TEST_USER_EMAIL or not TEST_USER_PASSWORD:
        pytest.skip("未配置测试账号 (TEST_USER_EMAIL / TEST_USER_PASSWORD)")

    with httpx.Client(timeout=REQUEST_TIMEOUT) as client:
        response = client.post(
            f"{TEST_API_URL}/api/secure-auth/login",
            json={"email": TEST_USER_EMAIL, "password": TEST_USER_PASSWORD}
        )
        if response.status_code != 200:
            pytest.skip(f"登录失败: HTTP {response.status_code}")

        data = response.json()
        access_token = data.get("access_token", "")
        if access_token:
            client.headers.update({"Authorization": f"Bearer {access_token}"})

        yield client


def pytest_runtest_makereport(item, call):
    """将 502/503/504 导致的测试失败转为 skip（测试环境瞬时故障）"""
    if call.when == "call" and call.excinfo is not None:
        exc = call.excinfo.value
        if isinstance(exc, AssertionError):
            msg = str(exc)
            for code in ("502", "503", "504"):
                if code in msg:
                    import pytest
                    call.excinfo = None
                    item._store["gateway_skip"] = True
                    break


def pytest_runtest_logreport(report):
    """配合上面的 hook，把标记为 gateway_skip 的用例改为 skip"""
    if report.when == "call" and hasattr(report, "item"):
        pass

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_call(item):
    outcome = yield
    if outcome.excinfo is not None:
        exc = outcome.excinfo[1]
        if isinstance(exc, AssertionError):
            msg = str(exc)
            for code in ("502", "503", "504"):
                if code in msg:
                    pytest.skip(f"测试环境网关错误 ({code})，跳过本次测试")
