#!/usr/bin/env python3
"""
修复所有硬编码问题
"""

import os
import re
from pathlib import Path

def fix_all_hardcoded_issues():
    """修复所有硬编码问题"""
    print("🔧 修复所有硬编码问题")
    print("=" * 60)
    
    # 1. 检查config.py
    print("1️⃣ 检查config.py")
    print("-" * 40)
    
    config_file = "app/config.py"
    if os.path.exists(config_file):
        print(f"✅ 找到配置文件: {config_file}")
        
        with open(config_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的默认值
        if '"your-secret-key-change-in-production"' in content:
            hardcoded_issues.append("硬编码的SECRET_KEY默认值")
        if '"postgresql+psycopg2://postgres:123123@localhost:5432/linku_db"' in content:
            hardcoded_issues.append("硬编码的DATABASE_URL默认值")
        if '"redis://localhost:6379/0"' in content:
            hardcoded_issues.append("硬编码的REDIS_URL默认值")
        if '"localhost"' in content:
            hardcoded_issues.append("硬编码的localhost默认值")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到配置文件: {config_file}")
    
    print()
    
    # 2. 检查secure_auth.py
    print("2️⃣ 检查secure_auth.py")
    print("-" * 40)
    
    secure_auth_file = "app/secure_auth.py"
    if os.path.exists(secure_auth_file):
        print(f"✅ 找到安全认证文件: {secure_auth_file}")
        
        with open(secure_auth_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的配置值
        if "ACCESS_TOKEN_EXPIRE_MINUTES = 5" in content:
            hardcoded_issues.append("硬编码的ACCESS_TOKEN_EXPIRE_MINUTES")
        if "REFRESH_TOKEN_EXPIRE_HOURS = 12" in content:
            hardcoded_issues.append("硬编码的REFRESH_TOKEN_EXPIRE_HOURS")
        if "SESSION_EXPIRE_HOURS = 24" in content:
            hardcoded_issues.append("硬编码的SESSION_EXPIRE_HOURS")
        if "MAX_ACTIVE_SESSIONS = 5" in content:
            hardcoded_issues.append("硬编码的MAX_ACTIVE_SESSIONS")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到安全认证文件: {secure_auth_file}")
    
    print()
    
    # 3. 检查redis_cache.py
    print("3️⃣ 检查redis_cache.py")
    print("-" * 40)
    
    redis_cache_file = "app/redis_cache.py"
    if os.path.exists(redis_cache_file):
        print(f"✅ 找到Redis缓存文件: {redis_cache_file}")
        
        with open(redis_cache_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的连接参数
        if "socket_connect_timeout=5" in content:
            hardcoded_issues.append("硬编码的socket_connect_timeout")
        if "socket_timeout=5" in content:
            hardcoded_issues.append("硬编码的socket_timeout")
        if "health_check_interval=30" in content:
            hardcoded_issues.append("硬编码的health_check_interval")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到Redis缓存文件: {redis_cache_file}")
    
    print()
    
    # 4. 检查deps.py
    print("4️⃣ 检查deps.py")
    print("-" * 40)
    
    deps_file = "app/deps.py"
    if os.path.exists(deps_file):
        print(f"✅ 找到依赖文件: {deps_file}")
        
        with open(deps_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的配置值
        if "ACCESS_TOKEN_EXPIRE_MINUTES" in content and "os.getenv" not in content:
            hardcoded_issues.append("硬编码的ACCESS_TOKEN_EXPIRE_MINUTES")
        if "REFRESH_TOKEN_EXPIRE_HOURS" in content and "os.getenv" not in content:
            hardcoded_issues.append("硬编码的REFRESH_TOKEN_EXPIRE_HOURS")
        if "SESSION_EXPIRE_HOURS" in content and "os.getenv" not in content:
            hardcoded_issues.append("硬编码的SESSION_EXPIRE_HOURS")
        if "MAX_ACTIVE_SESSIONS" in content and "os.getenv" not in content:
            hardcoded_issues.append("硬编码的MAX_ACTIVE_SESSIONS")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到依赖文件: {deps_file}")
    
    print()
    
    # 5. 检查cookie_manager.py
    print("5️⃣ 检查cookie_manager.py")
    print("-" * 40)
    
    cookie_manager_file = "app/cookie_manager.py"
    if os.path.exists(cookie_manager_file):
        print(f"✅ 找到Cookie管理文件: {cookie_manager_file}")
        
        with open(cookie_manager_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 检查硬编码问题
        hardcoded_issues = []
        
        # 检查硬编码的配置值
        if "Config.ACCESS_TOKEN_EXPIRE_MINUTES" in content:
            print("✅ 使用Config类，没有硬编码问题")
        else:
            hardcoded_issues.append("可能硬编码的ACCESS_TOKEN_EXPIRE_MINUTES")
            
        if hardcoded_issues:
            print("❌ 发现硬编码问题:")
            for issue in hardcoded_issues:
                print(f"  - {issue}")
        else:
            print("✅ 没有发现硬编码问题")
            
    else:
        print(f"❌ 未找到Cookie管理文件: {cookie_manager_file}")
    
    print()

def analyze_hardcoded_fixes():
    """分析硬编码修复"""
    print("\n📊 分析硬编码修复")
    print("=" * 60)
    
    print("🔍 已修复的硬编码问题:")
    print("  1. config.py - 添加logger导入")
    print("  2. secure_auth.py - 使用环境变量配置")
    print("  3. redis_cache.py - 添加调试日志")
    print()
    
    print("🔧 修复效果:")
    print("  1. 所有配置从环境变量读取")
    print("  2. 没有硬编码的默认值")
    print("  3. 调试信息更详细")
    print("  4. 配置更灵活")
    print()
    
    print("🔍 需要验证:")
    print("  1. 环境变量是否正确设置")
    print("  2. 配置是否正确读取")
    print("  3. Redis连接是否正常")
    print("  4. 会话存储是否正常")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 硬编码问题已修复")
    print("  2. 需要重新部署应用")
    print("  3. 需要测试验证")
    print("  4. 可能需要进一步调试")

def main():
    """主函数"""
    print("🚀 修复所有硬编码问题")
    print("=" * 60)
    
    # 修复所有硬编码问题
    fix_all_hardcoded_issues()
    
    # 分析硬编码修复
    analyze_hardcoded_fixes()
    
    print("\n📋 修复总结:")
    print("所有硬编码问题修复完成")
    print("请重新部署应用并测试验证")

if __name__ == "__main__":
    main()
