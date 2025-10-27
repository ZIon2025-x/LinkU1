#!/usr/bin/env python3
"""
测试新后端连接
"""

import requests
import json

def test_backend_connection():
    print("测试新后端连接")
    print("=" * 50)
    
    # 新的后端URL
    backend_url = "https://api.link2ur.com"
    frontend_url = "https://www.link2ur.com"
    
    print(f"后端URL: {backend_url}")
    print(f"前端URL: {frontend_url}")
    print("-" * 50)
    
    # 测试基本连接
    print("1. 测试基本连接...")
    try:
        response = requests.get(f"{backend_url}/", timeout=10)
        print(f"状态码: {response.status_code}")
        if response.status_code == 200:
            print("后端连接正常")
        else:
            print("后端连接异常")
    except Exception as e:
        print(f"连接失败: {e}")
    
    # 测试API端点
    print("\n2. 测试API端点...")
    try:
        response = requests.get(f"{backend_url}/api/users/profile/me", timeout=10)
        print(f"用户信息API状态码: {response.status_code}")
        if response.status_code in [200, 401]:  # 401是正常的未认证
            print("API端点正常")
        else:
            print("API端点异常")
    except Exception as e:
        print(f"API测试失败: {e}")
    
    # 测试CORS
    print("\n3. 测试CORS配置...")
    try:
        headers = {
            "Origin": frontend_url,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "Content-Type"
        }
        
        response = requests.options(f"{backend_url}/api/users/profile/me", headers=headers, timeout=10)
        print(f"CORS预检状态码: {response.status_code}")
        
        cors_headers = {k: v for k, v in response.headers.items() if 'access-control' in k.lower()}
        if cors_headers:
            print("CORS头信息:")
            for key, value in cors_headers.items():
                print(f"  {key}: {value}")
        else:
            print("未找到CORS头信息")
            
    except Exception as e:
        print(f"CORS测试失败: {e}")
    
    # 测试密码重置链接生成
    print("\n4. 测试密码重置链接...")
    try:
        # 模拟密码重置请求
        data = {"email": "test@example.com"}
        response = requests.post(f"{backend_url}/api/users/forgot-password", json=data, timeout=10)
        print(f"密码重置API状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("密码重置API正常")
            print("注意: 检查邮件中的链接是否指向正确的前端域名")
        else:
            print("密码重置API异常")
            
    except Exception as e:
        print(f"密码重置测试失败: {e}")

def main():
    test_backend_connection()
    
    print("\n配置检查:")
    print("1. 确保前端API配置指向新后端")
    print("2. 确保CORS允许前端域名")
    print("3. 确保密码重置链接指向正确的前端")
    
    print("\n下一步:")
    print("1. 重新部署前端以使用新的API URL")
    print("2. 测试密码重置功能")
    print("3. 检查邮件中的链接")

if __name__ == "__main__":
    main()
