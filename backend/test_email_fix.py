#!/usr/bin/env python3
"""
测试邮件修复
"""

import requests
import json
from datetime import datetime

def test_email_fix():
    """测试邮件修复"""
    print("📧 测试邮件修复")
    print("=" * 60)
    print(f"测试时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查邮件验证设置
    print("1️⃣ 检查邮件验证设置")
    print("-" * 40)
    
    try:
        # 测试注册（应该需要邮件验证）
        register_url = f"{base_url}/api/users/register"
        
        # 使用测试邮箱
        test_credentials = {
            "name": "邮件测试用户",
            "email": "test-email@example.com",
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
    
    # 2. 检查邮件配置状态
    print("2️⃣ 检查邮件配置状态")
    print("-" * 40)
    
    try:
        # 检查应用状态
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
    
    # 3. 分析邮件问题
    print("3️⃣ 分析邮件问题")
    print("-" * 40)
    
    print("🔍 可能的问题:")
    print("  1. SMTP配置未设置")
    print("  2. 邮件验证被跳过")
    print("  3. 邮件服务不可用")
    print("  4. 邮件被标记为垃圾邮件")
    print()
    
    print("🔧 修复步骤:")
    print("  1. 在Railway控制台设置SMTP环境变量")
    print("  2. 设置SKIP_EMAIL_VERIFICATION=false")
    print("  3. 重新部署应用")
    print("  4. 测试用户注册")
    print("  5. 检查邮件收件箱")
    print()
    
    print("📋 需要设置的环境变量:")
    print("  EMAIL_FROM=your-email@gmail.com")
    print("  SMTP_SERVER=smtp.gmail.com")
    print("  SMTP_PORT=587")
    print("  SMTP_USER=your-email@gmail.com")
    print("  SMTP_PASS=your-app-password")
    print("  SMTP_USE_TLS=true")
    print("  SMTP_USE_SSL=false")
    print("  SKIP_EMAIL_VERIFICATION=false")
    print("  BASE_URL=https://linku1-production.up.railway.app")

def analyze_email_issues():
    """分析邮件问题"""
    print("\n📊 邮件问题分析")
    print("=" * 60)
    
    print("🔍 问题原因:")
    print("  1. SKIP_EMAIL_VERIFICATION默认为true")
    print("  2. SMTP配置未设置")
    print("  3. 邮件发送函数有硬编码URL")
    print("  4. 环境变量未正确配置")
    print()
    
    print("✅ 已修复的问题:")
    print("  1. 修改SKIP_EMAIL_VERIFICATION默认值为false")
    print("  2. 修复邮件发送函数中的硬编码URL")
    print("  3. 使用Config.BASE_URL动态生成验证链接")
    print()
    
    print("🔧 待修复的问题:")
    print("  1. 在Railway控制台设置SMTP环境变量")
    print("  2. 重新部署应用")
    print("  3. 测试邮件发送功能")
    print()
    
    print("⚠️  注意事项:")
    print("  1. Gmail需要应用专用密码")
    print("  2. 检查垃圾邮件文件夹")
    print("  3. 确保SMTP服务器可访问")
    print("  4. 测试邮件可能被标记为垃圾邮件")

def main():
    """主函数"""
    print("🚀 邮件修复测试")
    print("=" * 60)
    
    # 测试邮件修复
    test_email_fix()
    
    # 分析邮件问题
    analyze_email_issues()
    
    print("\n📋 测试总结:")
    print("邮件修复测试完成")
    print("请根据上述分析设置环境变量并重新部署")

if __name__ == "__main__":
    main()
