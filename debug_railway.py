#!/usr/bin/env python3
"""
Railway 部署调试脚本
用于诊断 Railway 部署问题
"""
import os
import sys
import time
from datetime import datetime

def main():
    print("=== Railway 部署调试信息 ===")
    print(f"时间: {datetime.now().isoformat()}")
    print(f"Python 版本: {sys.version}")
    print(f"工作目录: {os.getcwd()}")
    print(f"环境变量 PORT: {os.environ.get('PORT', 'NOT SET')}")
    print(f"环境变量 PYTHONPATH: {os.environ.get('PYTHONPATH', 'NOT SET')}")
    
    # 检查文件结构
    print("\n=== 文件结构检查 ===")
    files_to_check = [
        'app/__init__.py',
        'app/main.py',
        'requirements.txt'
    ]
    
    for file_path in files_to_check:
        exists = os.path.exists(file_path)
        print(f"{file_path}: {'✓' if exists else '✗'}")
    
    # 检查端口绑定
    print(f"\n=== 端口信息 ===")
    port = os.environ.get('PORT', '8000')
    print(f"将监听端口: {port}")
    
    # 测试应用导入
    print(f"\n=== 应用导入测试 ===")
    try:
        import app.main
        print("✓ app.main 导入成功")
        
        # 检查 FastAPI 应用
        app = app.main.app
        print(f"✓ FastAPI 应用创建成功: {app.title}")
        
        # 检查路由
        routes = [route.path for route in app.routes if hasattr(route, 'path')]
        print(f"✓ 可用路由: {routes}")
        
        if '/health' in routes:
            print("✓ /health 端点存在")
        else:
            print("✗ /health 端点不存在")
            
    except Exception as e:
        print(f"✗ 应用导入失败: {e}")
        return 1
    
    print(f"\n=== 启动信息 ===")
    print("准备启动 uvicorn 服务器...")
    print(f"命令: python -m uvicorn app.main:app --host 0.0.0.0 --port {port}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
