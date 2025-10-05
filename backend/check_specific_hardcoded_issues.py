#!/usr/bin/env python3
"""
检查特定硬编码问题
"""

import os
import re
from pathlib import Path

def check_specific_hardcoded_issues():
    """检查特定硬编码问题"""
    print("🔍 检查特定硬编码问题")
    print("=" * 60)
    
    # 1. 检查config.py中的硬编码问题
    print("1️⃣ 检查config.py中的硬编码问题")
    print("-" * 40)
    
    config_file = "app/config.py"
    if os.path.exists(config_file):
        print(f"✅ 找到配置文件: {config_file}")
        
        with open(config_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的数据库URL
        if "postgresql+psycopg2://postgres:123123@localhost:5432/linku_db" in content:
            hardcoded_issues.append("硬编码的数据库URL (postgres:123123)")
        if "postgresql+asyncpg://postgres:123123@localhost:5432/linku_db" in content:
            hardcoded_issues.append("硬编码的异步数据库URL (postgres:123123)")
            
        # 检查硬编码的邮件配置
        if '"zixiong316@gmail.com"' in content:
            hardcoded_issues.append("硬编码的EMAIL_FROM (zixiong316@gmail.com)")
        if '"smtp.gmail.com"' in content:
            hardcoded_issues.append("硬编码的SMTP_SERVER (smtp.gmail.com)")
        if 'int(os.getenv("SMTP_PORT", "465"))' in content:
            hardcoded_issues.append("硬编码的SMTP_PORT (465)")
        if '"ksnmkitvacpyscfc"' in content:
            hardcoded_issues.append("硬编码的SMTP_PASS (ksnmkitvacpyscfc)")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到配置文件: {config_file}")
    
    print()
    
    # 2. 检查其他文件中的硬编码问题
    print("2️⃣ 检查其他文件中的硬编码问题")
    print("-" * 40)
    
    # 检查是否有其他文件包含这些硬编码值
    hardcoded_values = [
        "zixiong316@gmail.com",
        "ksnmkitvacpyscfc",
        "postgres:123123",
        "smtp.gmail.com",
        "465"
    ]
    
    found_files = []
    for root, dirs, files in os.walk("app"):
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        for value in hardcoded_values:
                            if value in content:
                                found_files.append((file_path, value))
                except:
                    pass
    
    if found_files:
        print("❌ 发现包含硬编码值的文件:")
        for file_path, value in found_files:
            print(f"  - {file_path}: {value}")
    else:
        print("✅ 没有发现其他文件包含硬编码值")
    
    print()

def analyze_specific_hardcoded_issues():
    """分析特定硬编码问题"""
    print("\n📊 分析特定硬编码问题")
    print("=" * 60)
    
    print("🔍 需要修复的硬编码问题:")
    print("  1. DATABASE_URL中的硬编码密码 (postgres:123123)")
    print("  2. EMAIL_FROM中的硬编码邮箱 (zixiong316@gmail.com)")
    print("  3. SMTP_SERVER中的硬编码服务器 (smtp.gmail.com)")
    print("  4. SMTP_PORT中的硬编码端口 (465)")
    print("  5. SMTP_PASS中的硬编码密码 (ksnmkitvacpyscfc)")
    print()
    
    print("🔧 修复建议:")
    print("  1. 移除硬编码的数据库密码")
    print("  2. 移除硬编码的邮箱地址")
    print("  3. 移除硬编码的SMTP服务器")
    print("  4. 移除硬编码的SMTP端口")
    print("  5. 移除硬编码的SMTP密码")
    print()
    
    print("🔍 修复方法:")
    print("  1. 使用环境变量读取配置")
    print("  2. 设置安全的默认值")
    print("  3. 避免在代码中硬编码敏感信息")
    print("  4. 使用配置文件管理敏感信息")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 硬编码的敏感信息存在安全风险")
    print("  2. 需要从环境变量读取配置")
    print("  3. 需要设置安全的默认值")
    print("  4. 需要重新部署应用")

def main():
    """主函数"""
    print("🚀 特定硬编码问题检查")
    print("=" * 60)
    
    # 检查特定硬编码问题
    check_specific_hardcoded_issues()
    
    # 分析特定硬编码问题
    analyze_specific_hardcoded_issues()
    
    print("\n📋 检查总结:")
    print("特定硬编码问题检查完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()
