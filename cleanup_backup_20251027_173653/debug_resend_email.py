#!/usr/bin/env python3
"""
Resend 邮件发送问题诊断脚本
检查 Resend 配置、域名验证和邮件投递状态
"""

import os
import requests
import json
from dotenv import load_dotenv

# 加载环境变量
load_dotenv()

def check_resend_config():
    """检查 Resend 配置"""
    print("检查 Resend 配置...")
    print("=" * 50)
    
    # 检查环境变量
    use_resend = os.getenv("USE_RESEND", "false").lower() == "true"
    resend_api_key = os.getenv("RESEND_API_KEY", "")
    email_from = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
    
    print(f"USE_RESEND: {use_resend}")
    print(f"RESEND_API_KEY: {'已设置' if resend_api_key else '未设置'}")
    print(f"EMAIL_FROM: {email_from}")
    
    if not use_resend:
        print("❌ USE_RESEND 未启用")
        return False
    
    if not resend_api_key:
        print("❌ RESEND_API_KEY 未设置")
        return False
    
    print("✅ Resend 配置检查通过")
    return True

def check_resend_api():
    """检查 Resend API 连接"""
    print("\n🔌 检查 Resend API 连接...")
    print("-" * 50)
    
    resend_api_key = os.getenv("RESEND_API_KEY", "")
    if not resend_api_key:
        print("❌ RESEND_API_KEY 未设置")
        return False
    
    try:
        # 测试 API 连接
        headers = {
            "Authorization": f"Bearer {resend_api_key}",
            "Content-Type": "application/json"
        }
        
        # 获取域名列表
        response = requests.get("https://api.resend.com/domains", headers=headers)
        
        if response.status_code == 200:
            domains = response.json()
            print("✅ Resend API 连接成功")
            print(f"已配置域名: {len(domains.get('data', []))}")
            
            # 检查 link2ur.com 域名
            email_from = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
            domain = email_from.split("@")[1]
            
            for domain_info in domains.get('data', []):
                if domain_info.get('name') == domain:
                    print(f"✅ 找到域名: {domain}")
                    print(f"  状态: {domain_info.get('status', 'unknown')}")
                    print(f"  验证: {domain_info.get('verified', False)}")
                    
                    if not domain_info.get('verified', False):
                        print("⚠️  域名未验证，这可能导致邮件发送失败")
                        print("请在 Resend 控制台验证域名")
                    
                    return True
            
            print(f"❌ 未找到域名: {domain}")
            print("请在 Resend 控制台添加并验证域名")
            return False
            
        else:
            print(f"❌ Resend API 连接失败: {response.status_code}")
            print(f"错误信息: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ API 连接异常: {e}")
        return False

def check_recent_emails():
    """检查最近的邮件发送记录"""
    print("\n📧 检查最近的邮件发送记录...")
    print("-" * 50)
    
    resend_api_key = os.getenv("RESEND_API_KEY", "")
    if not resend_api_key:
        print("❌ RESEND_API_KEY 未设置")
        return False
    
    try:
        headers = {
            "Authorization": f"Bearer {resend_api_key}",
            "Content-Type": "application/json"
        }
        
        # 获取最近的邮件记录
        response = requests.get("https://api.resend.com/emails", headers=headers)
        
        if response.status_code == 200:
            emails = response.json()
            print("✅ 成功获取邮件记录")
            
            recent_emails = emails.get('data', [])[:5]  # 最近5封邮件
            print(f"最近 {len(recent_emails)} 封邮件:")
            
            for email in recent_emails:
                print(f"  ID: {email.get('id')}")
                print(f"  收件人: {email.get('to', [])}")
                print(f"  主题: {email.get('subject')}")
                print(f"  状态: {email.get('last_event', 'unknown')}")
                print(f"  时间: {email.get('created_at')}")
                print("-" * 30)
            
            return True
        else:
            print(f"❌ 获取邮件记录失败: {response.status_code}")
            print(f"错误信息: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 检查邮件记录异常: {e}")
        return False

def test_email_sending():
    """测试邮件发送"""
    print("\n📤 测试邮件发送...")
    print("-" * 50)
    
    # 这里我们不会实际发送邮件，只是检查配置
    print("邮件发送测试需要以下配置:")
    print("1. 域名已添加到 Resend")
    print("2. 域名已通过验证")
    print("3. API 密钥有效")
    print("4. 发件人地址格式正确")
    
    email_from = os.getenv("EMAIL_FROM", "no-reply@link2ur.com")
    print(f"\n当前发件人: {email_from}")
    
    # 检查发件人格式
    if "@" in email_from and "." in email_from.split("@")[1]:
        print("✅ 发件人格式正确")
    else:
        print("❌ 发件人格式错误")
        return False
    
    return True

def check_delivery_issues():
    """检查邮件投递问题"""
    print("\n🚨 常见邮件投递问题检查...")
    print("-" * 50)
    
    print("1. 检查垃圾邮件文件夹")
    print("   - Gmail: 检查 '垃圾邮件' 文件夹")
    print("   - Outlook: 检查 '垃圾邮件' 文件夹")
    print("   - 其他邮箱: 检查 '垃圾邮件' 或 'Spam' 文件夹")
    
    print("\n2. 检查域名验证")
    print("   - 确保 link2ur.com 已在 Resend 中验证")
    print("   - 检查 DNS 记录是否正确")
    
    print("\n3. 检查发件人信誉")
    print("   - 新域名可能需要时间建立信誉")
    print("   - 避免发送垃圾邮件内容")
    
    print("\n4. 检查收件人邮箱")
    print("   - 确保收件人邮箱地址正确")
    print("   - 检查收件人邮箱是否正常工作")

def main():
    print("Resend 邮件发送问题诊断")
    print("=" * 50)
    
    # 检查配置
    config_ok = check_resend_config()
    if not config_ok:
        print("\n❌ 配置检查失败，请先修复配置问题")
        return
    
    # 检查 API 连接
    api_ok = check_resend_api()
    if not api_ok:
        print("\n❌ API 连接失败，请检查 API 密钥")
        return
    
    # 检查邮件记录
    emails_ok = check_recent_emails()
    
    # 测试邮件发送
    test_ok = test_email_sending()
    
    # 检查投递问题
    check_delivery_issues()
    
    print("\n📋 诊断总结:")
    if config_ok and api_ok and test_ok:
        print("✅ 配置和连接正常")
        print("如果仍然收不到邮件，请检查:")
        print("1. 垃圾邮件文件夹")
        print("2. 域名验证状态")
        print("3. 收件人邮箱地址")
    else:
        print("❌ 发现问题，请根据上述建议修复")

if __name__ == "__main__":
    main()
