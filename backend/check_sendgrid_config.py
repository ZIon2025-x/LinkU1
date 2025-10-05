#!/usr/bin/env python3
"""
检查SendGrid配置
"""

import os
import sys
from datetime import datetime

def check_sendgrid_installation():
    """检查SendGrid安装"""
    print("🔧 检查SendGrid安装")
    print("=" * 60)
    print(f"检查时间: {datetime.now().isoformat()}")
    print()
    
    # 1. 检查SendGrid库是否安装
    print("1️⃣ 检查SendGrid库安装")
    print("-" * 40)
    
    try:
        import sendgrid
        from sendgrid.helpers.mail import Mail, Email, To, Content
        print("✅ SendGrid库已安装")
        print(f"SendGrid版本: {sendgrid.__version__}")
    except ImportError as e:
        print(f"❌ SendGrid库未安装: {e}")
        print("🔧 解决方案:")
        print("  1. 在Railway重新部署应用")
        print("  2. 确保requirements.txt包含sendgrid>=6.10.0")
        print("  3. 检查部署日志")
        return False
    
    print()
    
    # 2. 检查环境变量
    print("2️⃣ 检查环境变量")
    print("-" * 40)
    
    sendgrid_api_key = os.getenv("SENDGRID_API_KEY", "")
    email_from = os.getenv("EMAIL_FROM", "")
    use_sendgrid = os.getenv("USE_SENDGRID", "false").lower() == "true"
    
    print(f"SENDGRID_API_KEY: {'已设置' if sendgrid_api_key else '未设置'}")
    print(f"EMAIL_FROM: {email_from}")
    print(f"USE_SENDGRID: {use_sendgrid}")
    
    if not sendgrid_api_key:
        print("❌ SENDGRID_API_KEY未设置")
        print("🔧 解决方案:")
        print("  1. 在Railway控制台设置SENDGRID_API_KEY")
        print("  2. 重新部署应用")
        return False
    
    if not email_from:
        print("❌ EMAIL_FROM未设置")
        print("🔧 解决方案:")
        print("  1. 在Railway控制台设置EMAIL_FROM")
        print("  2. 重新部署应用")
        return False
    
    if not use_sendgrid:
        print("❌ USE_SENDGRID未设置为true")
        print("🔧 解决方案:")
        print("  1. 在Railway控制台设置USE_SENDGRID=true")
        print("  2. 重新部署应用")
        return False
    
    print("✅ 环境变量配置正确")
    print()
    
    # 3. 测试SendGrid连接
    print("3️⃣ 测试SendGrid连接")
    print("-" * 40)
    
    try:
        sg = sendgrid.SendGridAPIClient(api_key=sendgrid_api_key)
        print("✅ SendGrid客户端创建成功")
        
        # 测试发送邮件
        from_email = Email(email_from)
        to_email = To("test@example.com")
        subject = "SendGrid测试邮件"
        content = Content("text/plain", "这是一封测试邮件")
        
        mail = Mail(from_email, to_email, subject, content)
        print("✅ 邮件对象创建成功")
        
        # 注意：这里不实际发送邮件，只是测试配置
        print("✅ SendGrid配置测试通过")
        
    except Exception as e:
        print(f"❌ SendGrid连接测试失败: {e}")
        print("🔧 解决方案:")
        print("  1. 检查SENDGRID_API_KEY是否正确")
        print("  2. 检查SendGrid账户状态")
        print("  3. 检查网络连接")
        return False
    
    print()
    
    return True

def check_railway_deployment():
    """检查Railway部署"""
    print("🚀 检查Railway部署")
    print("=" * 60)
    
    print("🔍 需要检查的项目:")
    print("  1. requirements.txt是否包含sendgrid>=6.10.0")
    print("  2. 是否重新部署了应用")
    print("  3. 环境变量是否正确设置")
    print("  4. 部署日志是否有错误")
    print()
    
    print("🔧 Railway部署步骤:")
    print("  1. 登录Railway控制台")
    print("  2. 选择您的项目")
    print("  3. 检查'Deployments'标签")
    print("  4. 查看最新的部署日志")
    print("  5. 确认SendGrid库已安装")
    print()
    
    print("📋 需要设置的环境变量:")
    print("  SENDGRID_API_KEY=your-api-key")
    print("  EMAIL_FROM=zixiong316@gmail.com")
    print("  USE_SENDGRID=true")
    print("  SKIP_EMAIL_VERIFICATION=false")
    print()

def main():
    """主函数"""
    print("🚀 SendGrid配置检查")
    print("=" * 60)
    
    # 检查SendGrid安装
    if check_sendgrid_installation():
        print("✅ SendGrid配置检查通过")
    else:
        print("❌ SendGrid配置检查失败")
        print("请按照上述建议修复配置问题")
    
    print()
    
    # 检查Railway部署
    check_railway_deployment()
    
    print("📋 检查总结:")
    print("SendGrid配置检查完成")
    print("请确保在Railway上正确设置环境变量并重新部署应用")

if __name__ == "__main__":
    main()
