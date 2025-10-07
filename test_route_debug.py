#!/usr/bin/env python3
"""
调试路由注册问题
"""

import requests
import json

def test_route_debug():
    print("调试路由注册问题")
    print("=" * 50)
    
    backend_url = "https://api.link2ur.com"
    
    # 测试不同的路径
    test_paths = [
        "/api/users/forgot_password",
        "/api/forgot_password", 
        "/forgot_password",
        "/api/users/",
        "/api/",
        "/"
    ]
    
    for path in test_paths:
        url = f"{backend_url}{path}"
        print(f"\n测试路径: {path}")
        print(f"完整URL: {url}")
        
        try:
            # 测试 GET 请求
            response = requests.get(url, timeout=5)
            print(f"GET 状态码: {response.status_code}")
            if response.status_code != 404:
                print(f"GET 响应: {response.text[:200]}")
        except Exception as e:
            print(f"GET 异常: {e}")
        
        try:
            # 测试 POST 请求
            response = requests.post(
                url,
                data={"email": "test@example.com"},
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=5
            )
            print(f"POST 状态码: {response.status_code}")
            if response.status_code != 404:
                print(f"POST 响应: {response.text[:200]}")
        except Exception as e:
            print(f"POST 异常: {e}")

def test_openapi():
    print("\n检查 OpenAPI 文档")
    print("-" * 50)
    
    backend_url = "https://api.link2ur.com"
    
    try:
        response = requests.get(f"{backend_url}/openapi.json", timeout=10)
        if response.status_code == 200:
            data = response.json()
            paths = data.get("paths", {})
            
            print("所有 API 路径:")
            for path, methods in paths.items():
                if "forgot" in path.lower() or "password" in path.lower():
                    print(f"  {path}: {list(methods.keys())}")
        else:
            print(f"无法获取 OpenAPI 文档: {response.status_code}")
    except Exception as e:
        print(f"OpenAPI 检查异常: {e}")

if __name__ == "__main__":
    test_route_debug()
    test_openapi()
