#!/usr/bin/env python3
"""
检查环境变量配置
"""

import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def main():
    print("环境变量检查")
    print("=" * 50)
    
    # 检查所有邮件相关环境变量
    env_vars = [
        "USE_RESEND",
        "RESEND_API_KEY", 
        "USE_SENDGRID",
        "SENDGRID_API_KEY",
        "EMAIL_FROM",
        "SMTP_SERVER",
        "SMTP_USER",
        "SMTP_PASS"
    ]
    
    for var in env_vars:
        value = os.getenv(var, "未设置")
        if var in ["RESEND_API_KEY", "SENDGRID_API_KEY", "SMTP_PASS"]:
            value = "已设置" if value != "未设置" and value else "未设置"
        print(f"{var}: {value}")
    
    print("\n分析:")
    
    # 检查 Resend 配置
    use_resend = os.getenv("USE_RESEND", "false").lower() == "true"
    resend_key = os.getenv("RESEND_API_KEY", "")
    
    if use_resend and resend_key:
        print("Resend 配置完整")
    elif use_resend and not resend_key:
        print("问题: USE_RESEND=true 但 RESEND_API_KEY 未设置")
    elif not use_resend and resend_key:
        print("问题: RESEND_API_KEY 已设置但 USE_RESEND=false")
    else:
        print("Resend 未配置，将使用 SMTP")
    
    # 检查 SMTP 配置
    smtp_user = os.getenv("SMTP_USER", "")
    smtp_pass = os.getenv("SMTP_PASS", "")
    
    if smtp_user and smtp_pass:
        print("SMTP 配置完整")
    else:
        print("问题: SMTP 配置不完整")
    
    print("\n建议:")
    print("1. 如果要使用 Resend，设置:")
    print("   USE_RESEND=true")
    print("   RESEND_API_KEY=your-api-key")
    print("2. 如果要使用 SMTP，设置:")
    print("   SMTP_USER=no-reply@link2ur.com")
    print("   SMTP_PASS=your-password")

if __name__ == "__main__":
    main()
