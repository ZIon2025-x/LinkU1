#!/usr/bin/env python3
"""
检查SMTP配置
"""

import os
import smtplib
from email.mime.text import MIMEText
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def check_smtp_config():
    """检查SMTP配置"""
    print("📧 检查SMTP配置")
    print("=" * 60)
    
    # 获取SMTP配置
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "")
    smtp_pass = os.getenv("SMTP_PASS", "")
    smtp_use_tls = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    smtp_use_ssl = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    email_from = os.getenv("EMAIL_FROM", "noreply@yourdomain.com")
    
    print(f"SMTP服务器: {smtp_server}")
    print(f"SMTP端口: {smtp_port}")
    print(f"SMTP用户: {smtp_user}")
    print(f"SMTP密码: {'*' * len(smtp_pass) if smtp_pass else '未设置'}")
    print(f"使用TLS: {smtp_use_tls}")
    print(f"使用SSL: {smtp_use_ssl}")
    print(f"发件人: {email_from}")
    print()
    
    # 检查配置完整性
    print("🔍 配置检查:")
    if not smtp_user:
        print("❌ SMTP_USER 未设置")
    else:
        print("✅ SMTP_USER 已设置")
        
    if not smtp_pass:
        print("❌ SMTP_PASS 未设置")
    else:
        print("✅ SMTP_PASS 已设置")
        
    if not email_from:
        print("❌ EMAIL_FROM 未设置")
    else:
        print("✅ EMAIL_FROM 已设置")
    
    print()
    
    # 测试SMTP连接
    if smtp_user and smtp_pass:
        print("🔧 测试SMTP连接:")
        try:
            if smtp_use_ssl:
                # 使用SSL连接
                with smtplib.SMTP_SSL(smtp_server, smtp_port) as server:
                    server.login(smtp_user, smtp_pass)
                    print("✅ SMTP SSL连接成功")
            else:
                # 使用TLS连接
                with smtplib.SMTP(smtp_server, smtp_port) as server:
                    if smtp_use_tls:
                        server.starttls()
                    server.login(smtp_user, smtp_pass)
                    print("✅ SMTP TLS连接成功")
        except Exception as e:
            print(f"❌ SMTP连接失败: {e}")
    else:
        print("⚠️  SMTP配置不完整，跳过连接测试")
    
    print()
    
    # 检查环境变量
    print("🔍 环境变量检查:")
    env_vars = [
        "SMTP_SERVER",
        "SMTP_PORT", 
        "SMTP_USER",
        "SMTP_PASS",
        "SMTP_USE_TLS",
        "SMTP_USE_SSL",
        "EMAIL_FROM",
        "SKIP_EMAIL_VERIFICATION"
    ]
    
    for var in env_vars:
        value = os.getenv(var, "未设置")
        if var == "SMTP_PASS" and value != "未设置":
            value = "*" * len(value)
        print(f"  {var}: {value}")
    
    print()
    
    # 提供修复建议
    print("🔧 修复建议:")
    if not smtp_user or not smtp_pass:
        print("  1. 设置SMTP_USER和SMTP_PASS环境变量")
        print("  2. 对于Gmail，使用应用专用密码")
        print("  3. 确保SMTP服务器和端口正确")
    
    if not email_from:
        print("  4. 设置EMAIL_FROM环境变量")
    
    print("  5. 检查垃圾邮件文件夹")
    print("  6. 确认邮件服务商设置")

def test_email_sending():
    """测试邮件发送"""
    print("\n📤 测试邮件发送")
    print("=" * 60)
    
    smtp_server = os.getenv("SMTP_SERVER", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER", "")
    smtp_pass = os.getenv("SMTP_PASS", "")
    smtp_use_tls = os.getenv("SMTP_USE_TLS", "true").lower() == "true"
    smtp_use_ssl = os.getenv("SMTP_USE_SSL", "false").lower() == "true"
    email_from = os.getenv("EMAIL_FROM", "noreply@yourdomain.com")
    
    if not smtp_user or not smtp_pass:
        print("❌ SMTP配置不完整，无法测试邮件发送")
        return
    
    try:
        # 创建测试邮件
        msg = MIMEText("这是一封测试邮件，用于验证SMTP配置。", "plain", "utf-8")
        msg["Subject"] = "LinkU SMTP测试邮件"
        msg["From"] = email_from
        msg["To"] = smtp_user  # 发送给自己
        
        # 发送邮件
        if smtp_use_ssl:
            with smtplib.SMTP_SSL(smtp_server, smtp_port) as server:
                server.login(smtp_user, smtp_pass)
                server.sendmail(email_from, [smtp_user], msg.as_string())
        else:
            with smtplib.SMTP(smtp_server, smtp_port) as server:
                if smtp_use_tls:
                    server.starttls()
                server.login(smtp_user, smtp_pass)
                server.sendmail(email_from, [smtp_user], msg.as_string())
        
        print("✅ 测试邮件发送成功")
        print(f"📧 请检查 {smtp_user} 的收件箱")
        
    except Exception as e:
        print(f"❌ 测试邮件发送失败: {e}")
        print("🔍 可能的原因:")
        print("  1. SMTP服务器或端口错误")
        print("  2. 用户名或密码错误")
        print("  3. 需要启用应用专用密码（Gmail）")
        print("  4. 网络连接问题")

def main():
    """主函数"""
    print("🚀 SMTP配置检查")
    print("=" * 60)
    
    # 检查SMTP配置
    check_smtp_config()
    
    # 测试邮件发送
    test_email_sending()
    
    print("\n📋 检查总结:")
    print("SMTP配置检查完成")
    print("请根据上述结果修复配置问题")

if __name__ == "__main__":
    main()
