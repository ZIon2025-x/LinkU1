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
    
    print("🚀 启动开发环境...")
    print("📧 跳过邮件验证: 是")
    print("🔧 调试模式: 开启")
    print("🍪 Cookie安全: 关闭")
    print("=" * 50)
    
    # 启动应用
    try:
        subprocess.run([
            sys.executable, 
            "-m", "uvicorn", 
            "app.main:app", 
            "--host", "0.0.0.0", 
            "--port", "8000", 
            "--reload"
        ], env=env, check=True)
    except KeyboardInterrupt:
        print("\n👋 开发服务器已停止")
    except subprocess.CalledProcessError as e:
        print(f"❌ 启动失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
