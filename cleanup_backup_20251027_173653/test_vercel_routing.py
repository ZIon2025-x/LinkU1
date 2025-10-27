#!/usr/bin/env python3
"""
测试 Vercel SPA 路由配置
"""

import requests
import json

def test_vercel_routing():
    print("测试 Vercel SPA 路由配置")
    print("=" * 50)
    
    frontend_url = "https://www.link2ur.com"
    
    # 测试不同路径
    test_paths = [
        "/",
        "/tasks", 
        "/login",
        "/register",
        "/profile",
        "/publish",
        "/about"
    ]
    
    print(f"前端URL: {frontend_url}")
    print("-" * 50)
    
    for path in test_paths:
        url = f"{frontend_url}{path}"
        print(f"\n测试路径: {path}")
        print(f"完整URL: {url}")
        
        try:
            response = requests.get(url, timeout=10, allow_redirects=False)
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                print("路由正常")
                # 检查是否返回了 index.html
                content_type = response.headers.get('content-type', '')
                if 'text/html' in content_type:
                    print("返回HTML内容")
                else:
                    print("⚠️  未返回HTML内容")
            elif response.status_code == 404:
                print("404 错误 - SPA路由未配置")
            elif response.status_code in [301, 302]:
                print(f"⚠️  重定向到: {response.headers.get('location', 'unknown')}")
            else:
                print(f"⚠️  其他状态码: {response.status_code}")
                
        except Exception as e:
            print(f"请求失败: {e}")

def test_api_proxy():
    print("\n测试 API 代理配置")
    print("-" * 50)
    
    frontend_url = "https://www.link2ur.com"
    api_paths = [
        "/api/users/profile/me",
        "/api/tasks",
        "/api/secure-auth/login"
    ]
    
    for path in api_paths:
        url = f"{frontend_url}{path}"
        print(f"\n测试API: {path}")
        
        try:
            response = requests.get(url, timeout=10)
            print(f"状态码: {response.status_code}")
            
            if response.status_code in [200, 401, 422]:  # 正常的API响应
                print("✅ API代理正常")
            else:
                print(f"⚠️  API代理异常: {response.status_code}")
                
        except Exception as e:
            print(f"❌ API请求失败: {e}")

def main():
    test_vercel_routing()
    test_api_proxy()
    
    print("\n问题诊断:")
    print("1. 如果所有路径都返回404，说明Vercel配置未生效")
    print("2. 如果只有部分路径404，说明路由配置有问题")
    print("3. 如果API代理失败，说明后端连接有问题")
    
    print("\n解决方案:")
    print("1. 确保 vercel.json 配置正确")
    print("2. 重新部署前端")
    print("3. 检查 Vercel 部署日志")
    print("4. 清除浏览器缓存")

if __name__ == "__main__":
    main()
