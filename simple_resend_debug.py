#!/usr/bin/env python3
"""
简化的 Resend 邮件发送问题诊断脚本
"""

import os
import requests
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def main():
    print("Resend 邮件发送问题诊断")
    print("=" * 50)
    
    # 检查配置
    use_resend = os.getenv("USE_RESEND", "false").lower() == "true"
    resend_api_key = os.getenv("RESEND_API_KEY", "")
    email_from = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
    
    print(f"USE_RESEND: {use_resend}")
    print(f"RESEND_API_KEY: {'已设置' if resend_api_key else '未设置'}")
    print(f"EMAIL_FROM: {email_from}")
    
    if not use_resend:
        print("问题: USE_RESEND 未启用")
        print("解决方案: 在 Railway 控制台设置 USE_RESEND=true")
        return
    
    if not resend_api_key:
        print("问题: RESEND_API_KEY 未设置")
        print("解决方案: 在 Railway 控制台设置 RESEND_API_KEY")
        return
    
    # 检查 API 连接
    try:
        headers = {
            "Authorization": f"Bearer {resend_api_key}",
            "Content-Type": "application/json"
        }
        
        response = requests.get("https://api.resend.com/domains", headers=headers)
        
        if response.status_code == 200:
            domains = response.json()
            print("Resend API 连接成功")
            
            # 检查域名
            domain = email_from.split("@")[1]
            print(f"检查域名: {domain}")
            
            for domain_info in domains.get('data', []):
                if domain_info.get('name') == domain:
                    print(f"找到域名: {domain}")
                    print(f"状态: {domain_info.get('status', 'unknown')}")
                    print(f"验证: {domain_info.get('verified', False)}")
                    
                    if not domain_info.get('verified', False):
                        print("警告: 域名未验证，这可能导致邮件发送失败")
                        print("解决方案: 在 Resend 控制台验证域名")
                    
                    break
            else:
                print(f"错误: 未找到域名 {domain}")
                print("解决方案: 在 Resend 控制台添加域名")
        else:
            print(f"API 连接失败: {response.status_code}")
            print(f"错误: {response.text}")
    
    except Exception as e:
        print(f"连接异常: {e}")
    
    print("\n常见问题解决方案:")
    print("1. 检查垃圾邮件文件夹")
    print("2. 确保域名已在 Resend 中验证")
    print("3. 检查 DNS 记录")
    print("4. 等待几分钟，邮件可能有延迟")

if __name__ == "__main__":
    main()
