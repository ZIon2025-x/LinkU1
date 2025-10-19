#!/usr/bin/env python3
"""
Railway环境变量检查工具
检查Railway上的环境变量配置
"""

import os
import sys
from datetime import datetime

def check_railway_environment():
    """检查Railway环境变量"""
    print("🚀 Railway环境变量检查")
    print("=" * 60)
    print(f"检查时间: {datetime.now().isoformat()}")
    print()
    
    # Railway环境检测
    railway_env = os.getenv("RAILWAY_ENVIRONMENT")
    print(f"RAILWAY_ENVIRONMENT: {railway_env}")
    print(f"是否在Railway环境: {'是' if railway_env else '否'}")
    print()
    
    # 关键环境变量
    critical_vars = {
        "DATABASE_URL": "数据库连接",
        "REDIS_URL": "Redis连接",
        "SECRET_KEY": "JWT密钥",
        "USE_REDIS": "Redis启用状态"
    }
    
    print("🔍 关键环境变量检查:")
    print("-" * 40)
    
    for var, description in critical_vars.items():
        value = os.getenv(var)
        if var == "SECRET_KEY" and value:
            print(f"{var:15} ({description:10}): {'*' * 20} (已设置)")
        elif var == "REDIS_URL" and value:
            # 只显示前20个字符
            preview = value[:20] + "..." if len(value) > 20 else value
            print(f"{var:15} ({description:10}): {preview}")
        else:
            status = "✅ 已设置" if value else "❌ 未设置"
            print(f"{var:15} ({description:10}): {status}")
    
    print()
    
    # Redis相关配置
    print("🔗 Redis配置详情:")
    print("-" * 40)
    
    redis_vars = [
        "REDIS_URL",
        "REDIS_HOST",
        "REDIS_PORT", 
        "REDIS_DB",
        "REDIS_PASSWORD",
        "USE_REDIS"
    ]
    
    for var in redis_vars:
        value = os.getenv(var)
        if var == "REDIS_PASSWORD" and value:
            print(f"{var:15}: {'*' * len(value)} (已设置)")
        else:
            print(f"{var:15}: {value}")
    
    print()
    
    # Cookie配置
    print("🍪 Cookie配置:")
    print("-" * 40)
    
    cookie_vars = [
        "COOKIE_SECURE",
        "COOKIE_SAMESITE", 
        # "COOKIE_DOMAIN",  # 已移除 - 现在只使用当前域名
        "COOKIE_PATH"
    ]
    
    for var in cookie_vars:
        value = os.getenv(var)
        print(f"{var:15}: {value}")
    
    print()
    
    # CORS配置
    print("🌐 CORS配置:")
    print("-" * 40)
    
    cors_vars = [
        "ALLOWED_ORIGINS",
        "BASE_URL"
    ]
    
    for var in cors_vars:
        value = os.getenv(var)
        print(f"{var:15}: {value}")
    
    print()
    
    # 检查配置完整性
    print("📊 配置完整性检查:")
    print("-" * 40)
    
    required_vars = ["DATABASE_URL", "SECRET_KEY"]
    optional_vars = ["REDIS_URL", "USE_REDIS"]
    
    missing_required = []
    missing_optional = []
    
    for var in required_vars:
        if not os.getenv(var):
            missing_required.append(var)
    
    for var in optional_vars:
        if not os.getenv(var):
            missing_optional.append(var)
    
    if missing_required:
        print("❌ 缺少必需的环境变量:")
        for var in missing_required:
            print(f"   - {var}")
    else:
        print("✅ 所有必需的环境变量都已设置")
    
    if missing_optional:
        print("⚠️ 缺少可选的环境变量:")
        for var in missing_optional:
            print(f"   - {var}")
    else:
        print("✅ 所有可选的环境变量都已设置")
    
    print()
    
    # 总结
    print("📋 总结:")
    print("-" * 40)
    
    if missing_required:
        print("❌ 配置不完整，缺少必需的环境变量")
        return False
    elif missing_optional:
        print("⚠️ 基本配置完整，但缺少一些可选配置")
        return True
    else:
        print("✅ 配置完整，所有环境变量都已设置")
        return True

def main():
    """主函数"""
    success = check_railway_environment()
    
    if success:
        print("\n🎉 环境变量检查完成！")
        return 0
    else:
        print("\n⚠️ 发现问题，请检查环境变量配置")
        return 1

if __name__ == "__main__":
    sys.exit(main())
