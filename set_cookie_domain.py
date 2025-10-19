#!/usr/bin/env python3
"""
设置Cookie域名环境变量
解决跨域Cookie问题
"""

import os
import sys

def set_cookie_domain():
    """设置Cookie域名环境变量"""
    
    print("🍪 设置Cookie域名环境变量")
    print("=" * 50)
    
    # 检查当前环境变量
    print("当前环境变量:")
    print(f"  IS_PRODUCTION: {os.getenv('IS_PRODUCTION', 'Not set')}")
    print(f"  COOKIE_DOMAIN: {os.getenv('COOKIE_DOMAIN', 'Not set')}")
    print(f"  NODE_ENV: {os.getenv('NODE_ENV', 'Not set')}")
    print()
    
    # 设置环境变量
    os.environ['IS_PRODUCTION'] = 'true'
    os.environ['COOKIE_DOMAIN'] = '.link2ur.com'
    os.environ['COOKIE_SECURE'] = 'true'
    os.environ['COOKIE_SAMESITE'] = 'lax'
    
    print("设置后的环境变量:")
    print(f"  IS_PRODUCTION: {os.environ.get('IS_PRODUCTION')}")
    print(f"  COOKIE_DOMAIN: {os.environ.get('COOKIE_DOMAIN')}")
    print(f"  COOKIE_SECURE: {os.environ.get('COOKIE_SECURE')}")
    print(f"  COOKIE_SAMESITE: {os.environ.get('COOKIE_SAMESITE')}")
    print()
    
    # 测试配置
    print("测试Cookie配置:")
    try:
        from app.config import get_settings
        settings = get_settings()
        
        print(f"  IS_PRODUCTION: {settings.IS_PRODUCTION}")
        print(f"  COOKIE_DOMAIN: {settings.COOKIE_DOMAIN}")
        print(f"  COOKIE_SECURE: {settings.COOKIE_SECURE}")
        print(f"  COOKIE_SAMESITE: {settings.COOKIE_SAMESITE}")
        
        if settings.COOKIE_DOMAIN == '.link2ur.com':
            print("✅ Cookie域名配置正确")
        else:
            print("❌ Cookie域名配置错误")
            
    except Exception as e:
        print(f"❌ 配置测试失败: {e}")
    
    print()
    print("📋 部署说明:")
    print("1. 在Railway环境变量中设置:")
    print("   IS_PRODUCTION=true")
    print("   COOKIE_DOMAIN=.link2ur.com")
    print("   COOKIE_SECURE=true")
    print("   COOKIE_SAMESITE=lax")
    print()
    print("2. 重新部署应用")
    print("3. 测试客服登录功能")

if __name__ == "__main__":
    set_cookie_domain()
