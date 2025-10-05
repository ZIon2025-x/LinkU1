#!/usr/bin/env python3
"""
修复邮件配置
"""

import os
from dotenv import load_dotenv

def fix_email_config():
    """修复邮件配置"""
    print("🔧 修复邮件配置")
    print("=" * 60)
    
    # 加载现有环境变量
    load_dotenv()
    
    # 检查当前配置
    print("📋 当前配置:")
    print(f"  EMAIL_FROM: {os.getenv('EMAIL_FROM', '未设置')}")
    print(f"  SMTP_SERVER: {os.getenv('SMTP_SERVER', '未设置')}")
    print(f"  SMTP_PORT: {os.getenv('SMTP_PORT', '未设置')}")
    print(f"  SMTP_USER: {os.getenv('SMTP_USER', '未设置')}")
    print(f"  SMTP_PASS: {'*' * len(os.getenv('SMTP_PASS', '')) if os.getenv('SMTP_PASS') else '未设置'}")
    print(f"  SKIP_EMAIL_VERIFICATION: {os.getenv('SKIP_EMAIL_VERIFICATION', '未设置')}")
    print()
    
    # 提供配置建议
    print("🔧 邮件配置修复建议:")
    print("=" * 60)
    
    print("1️⃣ 对于Gmail用户:")
    print("   EMAIL_FROM=your-email@gmail.com")
    print("   SMTP_SERVER=smtp.gmail.com")
    print("   SMTP_PORT=587")
    print("   SMTP_USER=your-email@gmail.com")
    print("   SMTP_PASS=your-app-password")
    print("   SMTP_USE_TLS=true")
    print("   SMTP_USE_SSL=false")
    print()
    
    print("2️⃣ 对于其他邮件服务商:")
    print("   EMAIL_FROM=your-email@yourdomain.com")
    print("   SMTP_SERVER=your-smtp-server.com")
    print("   SMTP_PORT=587 (或 465)")
    print("   SMTP_USER=your-email@yourdomain.com")
    print("   SMTP_PASS=your-password")
    print("   SMTP_USE_TLS=true")
    print("   SMTP_USE_SSL=false (或 true)")
    print()
    
    print("3️⃣ 重要设置:")
    print("   SKIP_EMAIL_VERIFICATION=false  # 启用邮件验证")
    print("   BASE_URL=https://linku1-production.up.railway.app  # 生产环境URL")
    print()
    
    print("⚠️  注意事项:")
    print("  1. Gmail需要启用两步验证并生成应用专用密码")
    print("  2. 确保SMTP服务器支持TLS/SSL")
    print("  3. 检查防火墙和网络设置")
    print("  4. 测试邮件可能被标记为垃圾邮件")
    print()
    
    print("🔍 检查步骤:")
    print("  1. 在Railway控制台设置环境变量")
    print("  2. 重新部署应用")
    print("  3. 测试用户注册")
    print("  4. 检查邮件收件箱和垃圾邮件文件夹")

def create_env_template():
    """创建环境变量模板"""
    print("\n📝 创建环境变量模板")
    print("=" * 60)
    
    template = """# 邮件配置
EMAIL_FROM=your-email@gmail.com
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false

# 邮件验证
SKIP_EMAIL_VERIFICATION=false
EMAIL_VERIFICATION_EXPIRE_HOURS=24

# 基础URL
BASE_URL=https://linku1-production.up.railway.app
FRONTEND_URL=https://link-u1.vercel.app

# 其他配置
SECRET_KEY=your-secret-key
DATABASE_URL=your-database-url
REDIS_URL=your-redis-url
"""
    
    with open("email_config_template.env", "w", encoding="utf-8") as f:
        f.write(template)
    
    print("✅ 已创建 email_config_template.env 文件")
    print("📋 请根据您的邮件服务商修改配置")
    print("🚀 然后在Railway控制台设置这些环境变量")

def main():
    """主函数"""
    print("🚀 邮件配置修复")
    print("=" * 60)
    
    # 修复邮件配置
    fix_email_config()
    
    # 创建环境变量模板
    create_env_template()
    
    print("\n📋 修复总结:")
    print("邮件配置问题已分析完成")
    print("请根据上述建议设置环境变量")

if __name__ == "__main__":
    main()
