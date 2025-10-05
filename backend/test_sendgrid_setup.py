#!/usr/bin/env python3
"""
测试SendGrid设置
"""

import requests
import json
from datetime import datetime

def test_sendgrid_setup():
    """测试SendGrid设置"""
    print("📧 测试SendGrid设置")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查应用健康状态
    print("1️⃣ 检查应用健康状态")
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
    
    # 2. 测试忘记密码功能
    print("2️⃣ 测试忘记密码功能")
    print("-" * 40)
    
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
    
    # 3. 测试用户注册功能
    print("3️⃣ 测试用户注册功能")
    print("-" * 40)
    
    try:
        register_url = f"{base_url}/api/users/register"
        
        # 使用测试邮箱
        test_credentials = {
            "name": "SendGrid测试用户",
            "email": "test-sendgrid@example.com",
            "password": "testpassword123"
        }
        
        response = requests.post(
            register_url,
            json=test_credentials,
            headers={"Content-Type": "application/json"},
            timeout=10
        )
        
        print(f"注册状态码: {response.status_code}")
        
        if response.status_code == 200:
            print("✅ 注册成功")
            try:
                data = response.json()
                print(f"注册响应: {data}")
                
                # 检查是否返回了验证要求
                if data.get("verification_required"):
                    print("✅ 邮件验证已启用")
                else:
                    print("❌ 邮件验证未启用")
                    
            except:
                print(f"注册响应: {response.text}")
        elif response.status_code == 400:
            print("❌ 注册失败 - 用户可能已存在")
            try:
                data = response.json()
                print(f"错误信息: {data}")
            except:
                print(f"错误信息: {response.text}")
        else:
            print(f"❌ 注册失败: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 注册测试异常: {e}")
    
    print()

def sendgrid_setup_instructions():
    """SendGrid设置说明"""
    print("📧 SendGrid设置说明")
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
    
    print("📋 需要设置的环境变量:")
    print("  SENDGRID_API_KEY=your-api-key")
    print("  EMAIL_FROM=your-email@yourdomain.com")
    print("  USE_SENDGRID=true")
    print("  SKIP_EMAIL_VERIFICATION=false")
    print("  BASE_URL=https://linku1-production.up.railway.app")
    print("  FRONTEND_URL=https://link-u1.vercel.app")
    print()
    
    print("📧 SendGrid优势:")
    print("  - 免费额度: 100封邮件/天")
    print("  - 高送达率")
    print("  - 不依赖SMTP连接")
    print("  - 更好的网络兼容性")
    print("  - 专业的邮件服务")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 设置完成后重新部署应用")
    print("  2. 检查垃圾邮件文件夹")
    print("  3. 验证邮件可能被标记为垃圾邮件")
    print("  4. 确保API密钥正确")
    print()

def main():
    """主函数"""
    print("🚀 SendGrid设置测试")
    print("=" * 60)
    
    # 测试SendGrid设置
    test_sendgrid_setup()
    
    # SendGrid设置说明
    sendgrid_setup_instructions()
    
    print("📋 测试总结:")
    print("SendGrid设置测试完成")
    print("请按照上述说明配置SendGrid")

if __name__ == "__main__":
    main()
