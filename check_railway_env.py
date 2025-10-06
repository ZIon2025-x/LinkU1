#!/usr/bin/env python3
"""
检查 Railway 环境变量配置
"""

import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def main():
    print("Railway 环境变量检查")
    print("=" * 50)
    
    # 检查关键环境变量
    env_vars = {
        "FRONTEND_URL": "前端URL",
        "BASE_URL": "后端URL", 
        "EMAIL_FROM": "发件人邮箱",
        "USE_RESEND": "是否使用Resend",
        "RESEND_API_KEY": "Resend API密钥"
    }
    
    print("当前环境变量状态:")
    for var, desc in env_vars.items():
        value = os.getenv(var, "未设置")
        if var in ["RESEND_API_KEY"]:
            value = "已设置" if value != "未设置" and value else "未设置"
        print(f"  {var} ({desc}): {value}")
    
    print("\n问题分析:")
    frontend_url = os.getenv("FRONTEND_URL", "")
    
    if not frontend_url:
        print("FRONTEND_URL 未设置")
        print("解决方案: 在 Railway 控制台设置 FRONTEND_URL=https://www.link2ur.com")
    elif "link-u1.vercel.app" in frontend_url:
        print("FRONTEND_URL 指向错误的域名")
        print("解决方案: 更新为 FRONTEND_URL=https://www.link2ur.com")
    elif "www.link2ur.com" in frontend_url:
        print("FRONTEND_URL 配置正确")
    else:
        print(f"⚠️  FRONTEND_URL 配置: {frontend_url}")
        print("请确认这是正确的前端域名")
    
    print("\n立即行动:")
    print("1. 登录 Railway 控制台")
    print("2. 进入项目设置 -> 环境变量")
    print("3. 设置或更新以下变量:")
    print("   FRONTEND_URL=https://www.link2ur.com")
    print("4. 重新部署后端")
    print("5. 测试密码重置功能")

if __name__ == "__main__":
    main()
