#!/usr/bin/env python3
"""
诊断邮件发送问题
"""

import requests
import json
import smtplib
from email.mime.text import MIMEText
from datetime import datetime

def test_direct_smtp_connection():
    """直接测试SMTP连接"""
    print("🔧 直接测试SMTP连接")
    print("=" * 60)
    
    # 测试Gmail SMTP连接
    try:
        print("测试Gmail SMTP连接...")
        
        # 使用您的邮箱
        test_email = "zixiong316@gmail.com"
        
        # 创建测试邮件
        msg = MIMEText("这是一封测试邮件，用于验证SMTP连接。", "plain", "utf-8")
        msg["Subject"] = "LinkU SMTP连接测试"
        msg["From"] = test_email
        msg["To"] = test_email
        
        # 测试587端口
        print("测试端口587...")
        try:
            with smtplib.SMTP('smtp.gmail.com', 587) as server:
                server.starttls()
                print("✅ TLS连接成功")
                # 注意：这里需要应用专用密码才能登录
                print("⚠️  需要应用专用密码才能完成登录测试")
        except Exception as e:
            print(f"❌ 端口587连接失败: {e}")
        
        # 测试465端口
        print("测试端口465...")
        try:
            with smtplib.SMTP_SSL('smtp.gmail.com', 465) as server:
                print("✅ SSL连接成功")
                print("⚠️  需要应用专用密码才能完成登录测试")
        except Exception as e:
            print(f"❌ 端口465连接失败: {e}")
            
    except Exception as e:
        print(f"❌ SMTP连接测试异常: {e}")
    
    print()

def check_railway_logs():
    """检查Railway日志"""
    print("📋 检查Railway应用状态")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查应用健康状态
    try:
        health_url = f"{base_url}/health"
        response = requests.get(health_url, timeout=10)
        
        print(f"健康检查状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ 应用运行正常")
            try:
                data = response.json()
                print(f"应用状态: {data}")
            except:
                print(f"应用状态: {response.text}")
        else:
            print(f"❌ 应用状态异常: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 应用状态检查异常: {e}")
    
    print()
    
    # 2. 测试忘记密码功能
    try:
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        response = requests.post(
            forgot_password_url,
            data={"email": "zixiong316@gmail.com"},
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

def analyze_email_issue():
    """分析邮件问题"""
    print("📊 分析邮件问题")
    print("=" * 60)
    
    print("🔍 可能的问题:")
    print("  1. SMTP_PASS环境变量未设置")
    print("  2. 使用了错误的密码（登录密码而非应用专用密码）")
    print("  3. Gmail两步验证未启用")
    print("  4. 邮件被标记为垃圾邮件")
    print("  5. 网络连接问题")
    print("  6. SMTP服务器配置错误")
    print("  7. 邮件发送函数有bug")
    print("  8. 环境变量未正确加载")
    print()
    
    print("🔧 解决步骤:")
    print("  1. 确认Gmail两步验证已启用")
    print("  2. 生成Gmail应用专用密码")
    print("  3. 在Railway控制台设置正确的环境变量")
    print("  4. 重新部署应用")
    print("  5. 检查Railway日志")
    print("  6. 测试邮件发送功能")
    print("  7. 检查垃圾邮件文件夹")
    print()
    
    print("📧 Gmail应用专用密码生成步骤:")
    print("  1. 访问 https://myaccount.google.com/")
    print("  2. 点击左侧菜单的 '安全性'")
    print("  3. 在 '登录Google' 部分，点击 '两步验证'")
    print("  4. 如果未启用，请先启用两步验证")
    print("  5. 启用后，滚动到页面底部")
    print("  6. 点击 '应用专用密码'")
    print("  7. 选择应用类型: '邮件'")
    print("  8. 选择设备: '其他（自定义名称）'")
    print("  9. 输入设备名称: 'LinkU App'")
    print("  10. 点击 '生成'")
    print("  11. 复制生成的16位密码")
    print("  12. 在Railway控制台设置 SMTP_PASS=生成的密码")
    print()
    
    print("⚠️  重要提醒:")
    print("  1. 应用专用密码是16位，包含空格")
    print("  2. 设置时去掉空格，只保留字母和数字")
    print("  3. 例如: abcd efgh ijkl mnop -> abcdefghijklmnop")
    print("  4. 设置完成后重新部署应用")
    print("  5. 测试邮件可能被标记为垃圾邮件")
    print()
    
    print("🔍 检查Railway环境变量:")
    print("  1. 登录Railway控制台")
    print("  2. 选择您的项目")
    print("  3. 点击 'Variables' 标签")
    print("  4. 确认以下环境变量已设置:")
    print("     EMAIL_FROM=zixiong316@gmail.com")
    print("     SMTP_SERVER=smtp.gmail.com")
    print("     SMTP_PORT=587")
    print("     SMTP_USER=zixiong316@gmail.com")
    print("     SMTP_PASS=your-16-digit-app-password")
    print("     SMTP_USE_TLS=true")
    print("     SMTP_USE_SSL=false")
    print("     SKIP_EMAIL_VERIFICATION=false")
    print("     BASE_URL=https://linku1-production.up.railway.app")
    print("     FRONTEND_URL=https://link-u1.vercel.app")
    print()
    
    print("🔍 检查Railway日志:")
    print("  1. 在Railway控制台点击 'Deployments'")
    print("  2. 选择最新的部署")
    print("  3. 查看 'Logs' 标签")
    print("  4. 查找邮件发送相关的错误信息")
    print("  5. 查找SMTP连接错误")
    print("  6. 查找环境变量加载错误")
    print()

def test_email_sending_with_debug():
    """测试邮件发送并调试"""
    print("📤 测试邮件发送并调试")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试忘记密码功能
    try:
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        print("发送忘记密码请求...")
        response = requests.post(
            forgot_password_url,
            data={"email": "zixiong316@gmail.com"},
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            timeout=10
        )
        
        print(f"请求状态码: {response.status_code}")
        print(f"响应头: {dict(response.headers)}")
        print(f"响应内容: {response.text}")
        
        if response.status_code == 200:
            print("✅ 请求成功，但邮件可能未发送")
            print("🔍 可能的原因:")
            print("  1. SMTP配置错误")
            print("  2. 邮件被标记为垃圾邮件")
            print("  3. 邮件发送函数有bug")
            print("  4. 环境变量未正确加载")
        else:
            print(f"❌ 请求失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 测试异常: {e}")
    
    print()

def main():
    """主函数"""
    print("🚀 邮件问题诊断")
    print("=" * 60)
    print(f"诊断时间: {datetime.now().isoformat()}")
    print()
    
    # 直接测试SMTP连接
    test_direct_smtp_connection()
    
    # 检查Railway应用状态
    check_railway_logs()
    
    # 分析邮件问题
    analyze_email_issue()
    
    # 测试邮件发送并调试
    test_email_sending_with_debug()
    
    print("📋 诊断总结:")
    print("邮件问题诊断完成")
    print("请根据上述分析修复SMTP配置问题")
    print("重点检查Railway环境变量设置和日志信息")

if __name__ == "__main__":
    main()
