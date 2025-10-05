#!/usr/bin/env python3
"""
测试不同的SMTP配置
"""

import smtplib
from email.mime.text import MIMEText
from datetime import datetime

def test_smtp_configurations():
    """测试不同的SMTP配置"""
    print("🔧 测试不同的SMTP配置")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    # 测试配置列表
    smtp_configs = [
        {
            "name": "Gmail 587端口 (STARTTLS)",
            "server": "smtp.gmail.com",
            "port": 587,
            "use_tls": True,
            "use_ssl": False
        },
        {
            "name": "Gmail 465端口 (SSL)",
            "server": "smtp.gmail.com", 
            "port": 465,
            "use_tls": False,
            "use_ssl": True
        },
        {
            "name": "Gmail 25端口 (标准)",
            "server": "smtp.gmail.com",
            "port": 25,
            "use_tls": False,
            "use_ssl": False
        },
        {
            "name": "Outlook 587端口",
            "server": "smtp-mail.outlook.com",
            "port": 587,
            "use_tls": True,
            "use_ssl": False
        },
        {
            "name": "Yahoo 587端口",
            "server": "smtp.mail.yahoo.com",
            "port": 587,
            "use_tls": True,
            "use_ssl": False
        }
    ]
    
    for config in smtp_configs:
        print(f"测试 {config['name']}...")
        try:
            if config['use_ssl']:
                with smtplib.SMTP_SSL(config['server'], config['port']) as server:
                    print(f"✅ {config['name']} - SSL连接成功")
            else:
                with smtplib.SMTP(config['server'], config['port']) as server:
                    if config['use_tls']:
                        server.starttls()
                        print(f"✅ {config['name']} - TLS连接成功")
                    else:
                        print(f"✅ {config['name']} - 标准连接成功")
        except Exception as e:
            print(f"❌ {config['name']} - 连接失败: {e}")
        print()

def suggest_alternatives():
    """建议替代方案"""
    print("🔧 建议替代方案")
    print("=" * 60)
    
    print("1️⃣ 使用不同的邮件服务商:")
    print("  - SendGrid (推荐)")
    print("  - Mailgun")
    print("  - Amazon SES")
    print("  - Postmark")
    print("  - 企业邮箱")
    print()
    
    print("2️⃣ 使用SendGrid (推荐):")
    print("  - 注册SendGrid账户")
    print("  - 获取API密钥")
    print("  - 设置环境变量:")
    print("    SENDGRID_API_KEY=your-api-key")
    print("    EMAIL_FROM=your-email@yourdomain.com")
    print()
    
    print("3️⃣ 使用企业邮箱:")
    print("  - 使用您公司的企业邮箱")
    print("  - 通常有更好的网络连接")
    print("  - 更稳定的SMTP服务")
    print()
    
    print("4️⃣ 使用邮件API服务:")
    print("  - 不依赖SMTP连接")
    print("  - 更可靠的邮件发送")
    print("  - 更好的送达率")
    print()

def create_sendgrid_config():
    """创建SendGrid配置"""
    print("📧 创建SendGrid配置")
    print("=" * 60)
    
    print("🔧 SendGrid设置步骤:")
    print("  1. 访问 https://sendgrid.com/")
    print("  2. 注册免费账户")
    print("  3. 验证邮箱地址")
    print("  4. 创建API密钥")
    print("  5. 在Railway设置环境变量:")
    print("     SENDGRID_API_KEY=your-api-key")
    print("     EMAIL_FROM=your-email@yourdomain.com")
    print("     USE_SENDGRID=true")
    print()
    
    print("📋 修改邮件发送代码:")
    print("  1. 安装SendGrid Python库")
    print("  2. 修改email_utils.py")
    print("  3. 使用SendGrid API发送邮件")
    print("  4. 重新部署应用")
    print()

def main():
    """主函数"""
    print("🚀 SMTP替代方案测试")
    print("=" * 60)
    
    # 测试不同的SMTP配置
    test_smtp_configurations()
    
    # 建议替代方案
    suggest_alternatives()
    
    # 创建SendGrid配置
    create_sendgrid_config()
    
    print("📋 测试总结:")
    print("SMTP替代方案测试完成")
    print("建议使用SendGrid或其他邮件API服务")

if __name__ == "__main__":
    main()
