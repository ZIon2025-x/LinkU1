#!/usr/bin/env python3
"""
设置SendGrid邮件服务
"""

def setup_sendgrid():
    """设置SendGrid邮件服务"""
    print("📧 设置SendGrid邮件服务")
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
    
    print("📧 SendGrid优势:")
    print("  - 免费额度: 100封邮件/天")
    print("  - 高送达率")
    print("  - 不依赖SMTP连接")
    print("  - 更好的网络兼容性")
    print("  - 专业的邮件服务")
    print()

def create_sendgrid_email_utils():
    """创建SendGrid邮件工具"""
    print("🔧 创建SendGrid邮件工具")
    print("=" * 60)
    
    sendgrid_code = '''
import os
import sendgrid
from sendgrid.helpers.mail import Mail, Email, To, Content
from fastapi import BackgroundTasks
from app.config import Config

def send_email_sendgrid(to_email, subject, body):
    """使用SendGrid发送邮件"""
    try:
        sg = sendgrid.SendGridAPIClient(api_key=Config.SENDGRID_API_KEY)
        
        from_email = Email(Config.EMAIL_FROM)
        to_email = To(to_email)
        subject = subject
        content = Content("text/html", body)
        
        mail = Mail(from_email, to_email, subject, content)
        
        response = sg.send(mail)
        print(f"SendGrid邮件发送成功: {response.status_code}")
        return True
        
    except Exception as e:
        print(f"SendGrid邮件发送失败: {e}")
        return False

def send_email(to_email, subject, body):
    """智能邮件发送 - 优先使用SendGrid"""
    print(f"send_email called: to={to_email}, subject={subject}")
    
    # 检查是否使用SendGrid
    if Config.USE_SENDGRID and Config.SENDGRID_API_KEY:
        print("使用SendGrid发送邮件")
        return send_email_sendgrid(to_email, subject, body)
    
    # 回退到SMTP
    print("使用SMTP发送邮件")
    return send_email_smtp(to_email, subject, body)
'''
    
    print("📝 SendGrid邮件工具代码:")
    print(sendgrid_code)
    print()
    
    print("📋 需要安装的依赖:")
    print("  pip install sendgrid")
    print()
    
    print("📋 需要设置的环境变量:")
    print("  SENDGRID_API_KEY=your-api-key")
    print("  EMAIL_FROM=your-email@yourdomain.com")
    print("  USE_SENDGRID=true")
    print()

def main():
    """主函数"""
    print("🚀 SendGrid邮件服务设置")
    print("=" * 60)
    
    # 设置SendGrid
    setup_sendgrid()
    
    # 创建SendGrid邮件工具
    create_sendgrid_email_utils()
    
    print("📋 设置总结:")
    print("SendGrid邮件服务设置完成")
    print("请按照上述步骤配置SendGrid")

if __name__ == "__main__":
    main()
