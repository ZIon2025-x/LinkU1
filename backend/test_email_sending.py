#!/usr/bin/env python3
"""
测试邮件发送功能
"""

import requests
import json
import smtplib
from email.mime.text import MIMEText
from datetime import datetime

def test_smtp_connection():
    """测试SMTP连接"""
    print("🔧 测试SMTP连接")
    print("=" * 60)
    
    # 从Railway获取配置
    base_url = "https://linku1-production.up.railway.app"
    
    try:
        # 测试忘记密码功能
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        # 使用测试邮箱
        test_email = "zixiong316@gmail.com"
        
        response = requests.post(
            forgot_password_url,
            data={"email": test_email},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        
        print(f"忘记密码请求状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 忘记密码请求成功")
            try:
                data = response.json()
                print(f"响应: {data}")
            except:
                print(f"响应: {response.text}")
        else:
            print(f"❌ 忘记密码请求失败: {response.status_code}")
            print(f"响应: {response.text}")
            
    except Exception as e:
        print(f"❌ 忘记密码测试异常: {e}")
    
    print()

def test_direct_smtp():
    """直接测试SMTP连接"""
    print("📧 直接测试SMTP连接")
    print("=" * 60)
    
    # 这些是您需要在Railway设置的环境变量
    smtp_config = {
        "server": "smtp.gmail.com",
        "port": 587,
        "user": "zixiong316@gmail.com",  # 您的邮箱
        "password": "your-app-password",  # 需要您的应用专用密码
        "use_tls": True,
        "use_ssl": False
    }
    
    print("🔍 SMTP配置:")
    print(f"  服务器: {smtp_config['server']}")
    print(f"  端口: {smtp_config['port']}")
    print(f"  用户: {smtp_config['user']}")
    print(f"  密码: {'*' * len(smtp_config['password']) if smtp_config['password'] != 'your-app-password' else '需要设置'}")
    print(f"  使用TLS: {smtp_config['use_tls']}")
    print(f"  使用SSL: {smtp_config['use_ssl']}")
    print()
    
    if smtp_config['password'] == 'your-app-password':
        print("⚠️  请设置正确的应用专用密码")
        print("🔧 Gmail设置步骤:")
        print("  1. 登录Gmail账户")
        print("  2. 进入Google账户设置")
        print("  3. 启用两步验证")
        print("  4. 生成应用专用密码")
        print("  5. 在Railway控制台设置SMTP_PASS环境变量")
        return
    
    try:
        # 创建测试邮件
        msg = MIMEText("这是一封测试邮件，用于验证SMTP配置。", "plain", "utf-8")
        msg["Subject"] = "Link²Ur SMTP测试邮件"
        msg["From"] = smtp_config['user']
        msg["To"] = smtp_config['user']
        
        # 测试SMTP连接
        if smtp_config['use_ssl']:
            with smtplib.SMTP_SSL(smtp_config['server'], smtp_config['port']) as server:
                server.login(smtp_config['user'], smtp_config['password'])
                server.sendmail(smtp_config['user'], [smtp_config['user']], msg.as_string())
        else:
            with smtplib.SMTP(smtp_config['server'], smtp_config['port']) as server:
                if smtp_config['use_tls']:
                    server.starttls()
                server.login(smtp_config['user'], smtp_config['password'])
                server.sendmail(smtp_config['user'], [smtp_config['user']], msg.as_string())
        
        print("✅ SMTP连接成功，测试邮件已发送")
        print(f"📧 请检查 {smtp_config['user']} 的收件箱")
        
    except Exception as e:
        print(f"❌ SMTP连接失败: {e}")
        print("🔍 可能的原因:")
        print("  1. 用户名或密码错误")
        print("  2. 需要启用两步验证")
        print("  3. 需要使用应用专用密码")
        print("  4. 网络连接问题")
        print("  5. Gmail安全设置阻止了连接")

def check_railway_environment():
    """检查Railway环境变量"""
    print("\n🔍 检查Railway环境变量")
    print("=" * 60)
    
    print("📋 需要在Railway控制台设置的环境变量:")
    print("  EMAIL_FROM=zixiong316@gmail.com")
    print("  SMTP_SERVER=smtp.gmail.com")
    print("  SMTP_PORT=587")
    print("  SMTP_USER=zixiong316@gmail.com")
    print("  SMTP_PASS=your-app-password")
    print("  SMTP_USE_TLS=true")
    print("  SMTP_USE_SSL=false")
    print("  SKIP_EMAIL_VERIFICATION=false")
    print("  BASE_URL=https://linku1-production.up.railway.app")
    print("  FRONTEND_URL=https://link-u1.vercel.app")
    print()
    
    print("⚠️  重要提醒:")
    print("  1. SMTP_PASS 必须是Gmail应用专用密码")
    print("  2. 不是您的Gmail登录密码")
    print("  3. 需要先启用两步验证")
    print("  4. 设置完成后重新部署应用")

def analyze_email_issue():
    """分析邮件问题"""
    print("\n📊 分析邮件问题")
    print("=" * 60)
    
    print("🔍 可能的问题:")
    print("  1. SMTP配置未正确设置")
    print("  2. 使用了错误的密码（登录密码而非应用专用密码）")
    print("  3. 邮件被标记为垃圾邮件")
    print("  4. Gmail安全设置阻止了连接")
    print("  5. 网络连接问题")
    print()
    
    print("🔧 解决步骤:")
    print("  1. 确认Gmail两步验证已启用")
    print("  2. 生成新的应用专用密码")
    print("  3. 在Railway控制台设置正确的环境变量")
    print("  4. 重新部署应用")
    print("  5. 测试邮件发送功能")
    print("  6. 检查垃圾邮件文件夹")
    print()
    
    print("📧 Gmail应用专用密码生成步骤:")
    print("  1. 登录 https://myaccount.google.com/")
    print("  2. 点击 '安全性'")
    print("  3. 在 '登录Google' 部分，点击 '两步验证'")
    print("  4. 滚动到底部，点击 '应用专用密码'")
    print("  5. 选择 '邮件' 和 '其他（自定义名称）'")
    print("  6. 输入名称如 'Link²Ur App'")
    print("  7. 点击 '生成'")
    print("  8. 复制生成的16位密码")
    print("  9. 在Railway控制台设置 SMTP_PASS=生成的密码")

def main():
    """主函数"""
    print("🚀 邮件发送功能测试")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    # 测试忘记密码功能
    test_smtp_connection()
    
    # 直接测试SMTP连接
    test_direct_smtp()
    
    # 检查Railway环境变量
    check_railway_environment()
    
    # 分析邮件问题
    analyze_email_issue()
    
    print("\n📋 测试总结:")
    print("邮件发送功能测试完成")
    print("请根据上述分析修复SMTP配置问题")

if __name__ == "__main__":
    main()
