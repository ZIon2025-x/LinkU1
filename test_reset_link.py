#!/usr/bin/env python3
"""
测试密码重置链接生成
"""

import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def test_reset_link():
    print("测试密码重置链接生成")
    print("=" * 50)
    
    # 获取配置
    frontend_url = os.getenv("FRONTEND_URL", "https://www.link2ur.com")
    base_url = os.getenv("BASE_URL", "https://linku1-production.up.railway.app")
    
    print(f"前端URL: {frontend_url}")
    print(f"后端URL: {base_url}")
    
    # 模拟token
    test_token = "InppeGlvbmczMTZAZ21haWwuY29tIg.aORShA.lWlKZbszy_znFmDA_m5L0L8IDKU"
    
    # 生成重置链接
    reset_url = f"{frontend_url}/reset-password/{test_token}"
    
    print(f"\n生成的重置链接:")
    print(f"{reset_url}")
    
    # 检查链接格式
    if reset_url.startswith("https://www.link2ur.com"):
        print("链接格式正确")
    else:
        print("链接格式错误")
    
    # 检查前端路由
    print(f"\n前端路由检查:")
    print(f"1. 确保前端有 /reset-password/:token 路由")
    print(f"2. 确保路由组件能处理 token 参数")
    print(f"3. 确保路由能调用后端 API 验证 token")
    
    print(f"\n当前问题:")
    print(f"1. 链接指向了错误的域名 (link-u1.vercel.app)")
    print(f"2. 应该指向 https://www.link2ur.com")
    
    print(f"\n解决方案:")
    print(f"1. 在 Railway 控制台设置 FRONTEND_URL=https://www.link2ur.com")
    print(f"2. 重新部署后端")
    print(f"3. 测试新的重置链接")

def check_frontend_routes():
    print(f"\n前端路由检查:")
    print(f"确保 App.tsx 中有以下路由:")
    print('<Route path="/reset-password/:token" element={<ResetPassword />} />')
    
    print(f"\nResetPassword 组件应该:")
    print(f"1. 从 URL 参数获取 token")
    print(f"2. 调用后端 API 验证 token")
    print(f"3. 显示密码重置表单")
    print(f"4. 提交新密码到后端")

def main():
    test_reset_link()
    check_frontend_routes()
    
    print(f"\n立即行动:")
    print(f"1. 在 Railway 控制台设置环境变量:")
    print(f"   FRONTEND_URL=https://www.link2ur.com")
    print(f"2. 重新部署后端")
    print(f"3. 测试密码重置功能")

if __name__ == "__main__":
    main()
