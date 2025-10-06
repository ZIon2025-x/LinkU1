#!/usr/bin/env python3
"""
邮箱配置测试脚本
测试 no-reply@link2ur.com 邮箱配置是否正确
"""

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def test_email_configuration():
    """测试邮箱配置"""
    print("📧 测试邮箱配置...")
    print("=" * 50)
    
    # 从环境变量获取配置
    email_from = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
    smtp_server = os.getenv("SMTP_SERVER", "smtp.link2ur.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "no-reply@link2ur.com")
    smtp_pass = os.getenv("SMTP_PASS", "")
    smtp_use_tls = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    smtp_use_ssl = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    
    print(f"发件人: {email_from}")
    print(f"SMTP服务器: {smtp_server}")
    print(f"SMTP端口: {smtp_port}")
    print(f"SMTP用户: {smtp_user}")
    print(f"使用TLS: {smtp_use_tls}")
    print(f"使用SSL: {smtp_use_ssl}")
    print(f"密码已设置: {'是' if smtp_pass else '否'}")
    print("-" * 50)
    
    if not smtp_pass:
        print("⚠️  警告: SMTP_PASS 环境变量未设置")
        print("请在 Railway 控制台设置 SMTP_PASS 环境变量")
        return False
    
    # 测试SMTP连接
    print("🔌 测试SMTP连接...")
    try:
        if smtp_use_ssl:
            server = smtplib.SMTP_SSL(smtp_server, smtp_port)
        else:
            server = smtplib.SMTP(smtp_server, smtp_port)
            if smtp_use_tls:
                server.starttls()
        
        server.login(smtp_user, smtp_pass)
        print("✅ SMTP连接成功")
        
        # 测试发送邮件（可选）
        test_recipient = input("输入测试收件人邮箱（回车跳过）: ").strip()
        if test_recipient:
            print("📤 发送测试邮件...")
            msg = MIMEMultipart()
            msg['From'] = email_from
            msg['To'] = test_recipient
            msg['Subject'] = "LinkU 邮箱配置测试"
            
            body = """
            这是一封来自 LinkU 平台的测试邮件。
            
            如果您收到这封邮件，说明邮箱配置正确！
            
            --
            LinkU 团队
            """
            msg.attach(MIMEText(body, 'plain', 'utf-8'))
            
            server.send_message(msg)
            print(f"✅ 测试邮件已发送到 {test_recipient}")
        else:
            print("⏭️  跳过测试邮件发送")
        
        server.quit()
        return True
        
    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ SMTP认证失败: {e}")
        print("请检查 SMTP_USER 和 SMTP_PASS 是否正确")
        return False
    except smtplib.SMTPConnectError as e:
        print(f"❌ SMTP连接失败: {e}")
        print("请检查 SMTP_SERVER 和 SMTP_PORT 是否正确")
        return False
    except Exception as e:
        print(f"❌ 邮件发送异常: {e}")
        return False

def check_domain_configuration():
    """检查域名配置"""
    print("\n🌐 检查域名配置...")
    print("-" * 50)
    
    # 检查DNS记录
    import socket
    try:
        smtp_server = os.getenv("SMTP_SERVER", "smtp.link2ur.com")
        ip = socket.gethostbyname(smtp_server)
        print(f"✅ {smtp_server} 解析到 {ip}")
    except socket.gaierror:
        print(f"❌ 无法解析 {smtp_server}")
        print("请确保域名配置正确")
    
    # 检查MX记录（可选）
    try:
        import dns.resolver
        domain = "link2ur.com"
        mx_records = dns.resolver.resolve(domain, 'MX')
        print(f"✅ {domain} 的MX记录:")
        for mx in mx_records:
            print(f"  {mx.exchange} (优先级: {mx.preference})")
    except ImportError:
        print("ℹ️  未安装 dnspython，跳过MX记录检查")
    except Exception as e:
        print(f"ℹ️  MX记录检查失败: {e}")

def main():
    print("🚀 LinkU 邮箱配置测试")
    print("=" * 50)
    
    # 检查环境变量
    print("📋 当前环境变量:")
    env_vars = [
        "EMAIL_FROM", "SMTP_SERVER", "SMTP_PORT", 
        "SMTP_USER", "SMTP_PASS", "SMTP_USE_TLS", "SMTP_USE_SSL"
    ]
    
    for var in env_vars:
        value = os.getenv(var, "未设置")
        if var == "SMTP_PASS" and value != "未设置":
            value = "已设置" if value else "未设置"
        print(f"  {var}: {value}")
    
    print("-" * 50)
    
    # 测试邮箱配置
    success = test_email_configuration()
    
    # 检查域名配置
    check_domain_configuration()
    
    print("\n📋 配置建议:")
    print("1. 确保在 Railway 控制台设置了正确的环境变量")
    print("2. 确保 link2ur.com 域名已配置邮件服务")
    print("3. 确保 SMTP 服务器支持 TLS/SSL 连接")
    print("4. 确保邮箱账户有发送邮件的权限")
    
    if success:
        print("\n✅ 邮箱配置测试完成！")
    else:
        print("\n❌ 邮箱配置需要修复")

if __name__ == "__main__":
    main()
