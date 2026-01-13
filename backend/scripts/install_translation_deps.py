#!/usr/bin/env python3
"""
翻译服务依赖安装脚本（Python版本）
自动检测并安装缺失的翻译服务依赖
"""
import sys
import subprocess
import importlib.util

def check_module(module_name):
    """检查模块是否已安装"""
    try:
        spec = importlib.util.find_spec(module_name)
        return spec is not None
    except ImportError:
        return False

def install_package(package_name):
    """安装Python包"""
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", package_name])
        return True
    except subprocess.CalledProcessError:
        return False

def main():
    print("=" * 60)
    print("翻译服务依赖安装脚本")
    print("=" * 60)
    print()
    
    # 检查缺失的依赖
    missing_deps = []
    
    # 检查 deep-translator
    if not check_module("deep_translator"):
        missing_deps.append("deep-translator")
        print("❌ deep-translator 未安装")
    else:
        print("✓ deep-translator 已安装")
    
    # 检查 google-cloud-translate
    if not check_module("google.cloud.translate_v2"):
        missing_deps.append("google-cloud-translate")
        print("❌ google-cloud-translate 未安装")
    else:
        print("✓ google-cloud-translate 已安装")
    
    print()
    
    # 如果没有缺失的依赖
    if not missing_deps:
        print("✅ 所有翻译服务依赖已安装！")
        return 0
    
    # 询问是否安装
    print(f"发现以下缺失的依赖: {', '.join(missing_deps)}")
    print()
    
    try:
        response = input("是否自动安装这些依赖? (y/n): ").strip().lower()
    except KeyboardInterrupt:
        print("\n已取消安装")
        return 1
    
    if response != 'y':
        print("已取消安装")
        print()
        print("手动安装命令:")
        for dep in missing_deps:
            print(f"  pip install {dep}")
        return 0
    
    # 安装缺失的依赖
    print()
    print("开始安装...")
    print()
    
    failed_deps = []
    for dep in missing_deps:
        print(f"正在安装 {dep}...")
        if install_package(dep):
            print(f"✓ {dep} 安装成功")
        else:
            print(f"❌ {dep} 安装失败")
            failed_deps.append(dep)
        print()
    
    if failed_deps:
        print("=" * 60)
        print(f"❌ 以下依赖安装失败: {', '.join(failed_deps)}")
        print("请手动安装或检查网络连接")
        print("=" * 60)
        return 1
    else:
        print("=" * 60)
        print("✅ 所有依赖安装完成！")
        print("=" * 60)
        return 0

if __name__ == "__main__":
    sys.exit(main())
