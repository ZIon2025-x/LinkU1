#!/usr/bin/env python3
"""
测试邮件发送逻辑
"""

import os
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def test_email_logic():
    print("测试邮件发送逻辑")
    print("=" * 50)
    
    # 模拟不同的环境变量设置
    test_cases = [
        {
            "name": "Resend 配置完整",
            "env": {
                "USE_RESEND": "true",
                "RESEND_API_KEY": "test-key",
                "USE_SENDGRID": "false",
                "SENDGRID_API_KEY": "",
                "SMTP_USER": "",
                "SMTP_PASS": ""
            }
        },
        {
            "name": "SendGrid 配置完整",
            "env": {
                "USE_RESEND": "false",
                "RESEND_API_KEY": "",
                "USE_SENDGRID": "true",
                "SENDGRID_API_KEY": "test-key",
                "SMTP_USER": "",
                "SMTP_PASS": ""
            }
        },
        {
            "name": "SMTP 配置完整",
            "env": {
                "USE_RESEND": "false",
                "RESEND_API_KEY": "",
                "USE_SENDGRID": "false",
                "SENDGRID_API_KEY": "",
                "SMTP_USER": "no-reply@link2ur.com",
                "SMTP_PASS": "test-pass"
            }
        },
        {
            "name": "当前环境（无配置）",
            "env": {
                "USE_RESEND": os.getenv("USE_RESEND", "false"),
                "RESEND_API_KEY": os.getenv("RESEND_API_KEY", ""),
                "USE_SENDGRID": os.getenv("USE_SENDGRID", "false"),
                "SENDGRID_API_KEY": os.getenv("SENDGRID_API_KEY", ""),
                "SMTP_USER": os.getenv("SMTP_USER", ""),
                "SMTP_PASS": os.getenv("SMTP_PASS", "")
            }
        }
    ]
    
    for case in test_cases:
        print(f"\n{case['name']}:")
        print("-" * 30)
        
        # 模拟邮件发送逻辑
        use_resend = case["env"]["USE_RESEND"].lower() == "true"
        resend_key = case["env"]["RESEND_API_KEY"]
        use_sendgrid = case["env"]["USE_SENDGRID"].lower() == "true"
        sendgrid_key = case["env"]["SENDGRID_API_KEY"]
        smtp_user = case["env"]["SMTP_USER"]
        smtp_pass = case["env"]["SMTP_PASS"]
        
        print(f"USE_RESEND: {use_resend}")
        print(f"RESEND_API_KEY: {'已设置' if resend_key else '未设置'}")
        print(f"USE_SENDGRID: {use_sendgrid}")
        print(f"SENDGRID_API_KEY: {'已设置' if sendgrid_key else '未设置'}")
        print(f"SMTP_USER: {'已设置' if smtp_user else '未设置'}")
        print(f"SMTP_PASS: {'已设置' if smtp_pass else '未设置'}")
        
        # 判断会使用哪种方式
        if use_resend and resend_key:
            print("结果: 使用 Resend 发送邮件")
        elif use_sendgrid and sendgrid_key:
            print("结果: 使用 SendGrid 发送邮件")
        elif smtp_user and smtp_pass:
            print("结果: 使用 SMTP 发送邮件")
        else:
            print("结果: 邮件发送失败（配置不完整）")

def main():
    test_email_logic()
    
    print("\n解决方案:")
    print("1. 在 Railway 控制台设置环境变量:")
    print("   USE_RESEND=true")
    print("   RESEND_API_KEY=your-resend-api-key")
    print("2. 或者使用 SMTP:")
    print("   SMTP_USER=no-reply@link2ur.com")
    print("   SMTP_PASS=your-email-password")
    print("3. 确保域名已在 Resend 中验证")

if __name__ == "__main__":
    main()
