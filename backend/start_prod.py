#!/usr/bin/env python3
"""
生产环境启动脚本
设置环境变量并启动应用
"""

import os
import sys
import subprocess

def main():
    # 设置生产环境变量
    env = os.environ.copy()
    env['SKIP_EMAIL_VERIFICATION'] = 'false'
    env['DEBUG'] = 'false'
    env['ENVIRONMENT'] = 'production'
    env['COOKIE_SECURE'] = 'true'
    env['COOKIE_SAMESITE'] = 'strict'
    
    print("🚀 启动生产环境...")
    print("📧 跳过邮件验证: 否")
    print("🔧 调试模式: 关闭")
    print("🍪 Cookie安全: 开启")
    print("=" * 50)
    
    # 启动应用
    try:
        subprocess.run([
            sys.executable, 
            "-m", "uvicorn", 
            "app.main:app", 
            "--host", "0.0.0.0", 
            "--port", "8000",
            "--no-access-log"
        ], env=env, check=True)
    except KeyboardInterrupt:
        print("\n👋 生产服务器已停止")
    except subprocess.CalledProcessError as e:
        print(f"❌ 启动失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
