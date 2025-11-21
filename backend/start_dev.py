#!/usr/bin/env python3
"""
开发环境启动脚本
设置环境变量并启动应用
"""

import os
import sys
import subprocess

def main():
    # 设置开发环境变量
    env = os.environ.copy()
    env['SKIP_EMAIL_VERIFICATION'] = 'true'
    env['DEBUG'] = 'true'
    env['ENVIRONMENT'] = 'development'
    env['COOKIE_SECURE'] = 'false'
    env['COOKIE_SAMESITE'] = 'lax'
    
    # 开发环境会话配置：延长会话时间，避免频繁登出
    env['USER_SESSION_EXPIRE_HOURS'] = '168'  # 7天，开发环境避免频繁登出
    env['SESSION_EXPIRE_HOURS'] = '168'  # 7天
    env['REFRESH_TOKEN_EXPIRE_HOURS'] = '720'  # 30天
    
    print("🚀 启动开发环境...")
    print("📧 跳过邮件验证: 是")
    print("🔧 调试模式: 开启")
    print("🍪 Cookie安全: 关闭")
    print("⏰ 会话过期时间: 7天 (开发环境)")
    print("📝 日志级别: WARNING (减少401等开发干扰)")
    print("=" * 50)
    
    # 启动应用
    try:
        subprocess.run([
            sys.executable, 
            "-m", "uvicorn", 
            "app.main:app", 
            "--host", "0.0.0.0", 
            "--port", "8000", 
            "--reload",
            "--log-level", "warning"  # 设置uvicorn日志级别为warning
        ], env=env, check=True)
    except KeyboardInterrupt:
        print("\n👋 开发服务器已停止")
    except subprocess.CalledProcessError as e:
        print(f"❌ 启动失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
