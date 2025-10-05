#!/usr/bin/env python3
"""
分析本地和Railway网络环境差异
"""

import smtplib
import socket
import requests
from datetime import datetime

def test_local_network():
    """测试本地网络环境"""
    print("🏠 本地网络环境测试")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    # 测试Gmail SMTP连接
    print("1️⃣ 测试Gmail SMTP连接")
    print("-" * 40)
    
    smtp_configs = [
        {"name": "Gmail 587端口", "server": "smtp.gmail.com", "port": 587},
        {"name": "Gmail 465端口", "server": "smtp.gmail.com", "port": 465},
        {"name": "Gmail 25端口", "server": "smtp.gmail.com", "port": 25},
    ]
    
    for config in smtp_configs:
        try:
            print(f"测试 {config['name']}...")
            with smtplib.SMTP(config['server'], config['port']) as server:
                print(f"✅ {config['name']} - 连接成功")
        except Exception as e:
            print(f"❌ {config['name']} - 连接失败: {e}")
    
    print()
    
    # 测试网络连接
    print("2️⃣ 测试网络连接")
    print("-" * 40)
    
    test_hosts = [
        "smtp.gmail.com",
        "google.com",
        "github.com",
        "railway.app"
    ]
    
    for host in test_hosts:
        try:
            socket.create_connection((host, 80), timeout=5)
            print(f"✅ {host} - 网络可达")
        except Exception as e:
            print(f"❌ {host} - 网络不可达: {e}")
    
    print()

def test_railway_network():
    """测试Railway网络环境"""
    print("☁️ Railway网络环境测试")
    print("=" * 60)
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 测试应用健康状态
    print("1️⃣ 测试应用健康状态")
    print("-" * 40)
    
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
    
    # 测试邮件发送
    print("2️⃣ 测试邮件发送")
    print("-" * 40)
    
    try:
        forgot_password_url = f"{base_url}/api/users/forgot_password"
        
        response = requests.post(
            forgot_password_url,
            data={"email": "test@example.com"},
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

def analyze_network_differences():
    """分析网络环境差异"""
    print("📊 网络环境差异分析")
    print("=" * 60)
    
    print("🔍 本地环境特点:")
    print("  1. 直接网络访问")
    print("  2. 无防火墙限制")
    print("  3. 网络配置简单")
    print("  4. 可以访问所有端口")
    print("  5. 网络延迟低")
    print()
    
    print("☁️ Railway环境特点:")
    print("  1. 容器化环境")
    print("  2. 网络隔离")
    print("  3. 防火墙规则")
    print("  4. 安全策略")
    print("  5. 网络延迟较高")
    print()
    
    print("🚫 Railway可能阻止的连接:")
    print("  1. SMTP端口 (25, 587, 465)")
    print("  2. 某些邮件服务器")
    print("  3. 垃圾邮件防护")
    print("  4. 安全策略限制")
    print()
    
    print("✅ Railway允许的连接:")
    print("  1. HTTP/HTTPS (80, 443)")
    print("  2. 数据库连接")
    print("  3. Redis连接")
    print("  4. API调用")
    print("  5. 第三方服务")
    print()

def suggest_solutions():
    """建议解决方案"""
    print("🔧 解决方案建议")
    print("=" * 60)
    
    print("1️⃣ 使用邮件API服务 (推荐):")
    print("  - SendGrid")
    print("  - Mailgun")
    print("  - Amazon SES")
    print("  - Postmark")
    print("  - 优势: 不依赖SMTP，网络兼容性好")
    print()
    
    print("2️⃣ 使用企业邮箱:")
    print("  - 公司邮箱通常有更好的网络连接")
    print("  - 更稳定的SMTP服务")
    print("  - 更好的网络兼容性")
    print()
    
    print("3️⃣ 使用代理服务器:")
    print("  - 通过代理访问SMTP服务器")
    print("  - 绕过网络限制")
    print("  - 但可能不稳定")
    print()
    
    print("4️⃣ 使用Railway网络配置:")
    print("  - 检查Railway网络设置")
    print("  - 联系Railway支持")
    print("  - 但可能无法解决")
    print()
    
    print("🎯 最佳解决方案:")
    print("  使用SendGrid等邮件API服务")
    print("  - 不依赖SMTP连接")
    print("  - 网络兼容性好")
    print("  - 专业邮件服务")
    print("  - 高送达率")
    print()

def main():
    """主函数"""
    print("🚀 网络环境差异分析")
    print("=" * 60)
    
    # 测试本地网络
    test_local_network()
    
    # 测试Railway网络
    test_railway_network()
    
    # 分析网络差异
    analyze_network_differences()
    
    # 建议解决方案
    suggest_solutions()
    
    print("📋 分析总结:")
    print("本地和Railway网络环境存在显著差异")
    print("建议使用SendGrid等邮件API服务解决SMTP连接问题")

if __name__ == "__main__":
    main()
