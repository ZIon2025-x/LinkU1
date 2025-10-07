#!/usr/bin/env python3
"""
直接测试 API
"""

import requests

def test_api():
    try:
        response = requests.post(
            "https://api.link2ur.com/api/users/forgot_password",
            data={"email": "test@example.com"},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        print(f"状态码: {response.status_code}")
        print(f"响应: {response.text}")
        print(f"响应头: {dict(response.headers)}")
    except Exception as e:
        print(f"错误: {e}")

if __name__ == "__main__":
    test_api()
