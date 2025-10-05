#!/usr/bin/env python3
"""
检查Railway部署配置
"""

import requests
import json
from datetime import datetime

def check_railway_deployment():
    """检查Railway部署配置"""
    print("🔍 检查Railway部署配置")
    print("=" * 60)
    print(f"检查时间: {datetime.now().isoformat()}")
    print()
    
    base_url = "https://linku1-production.up.railway.app"
    
    # 1. 检查应用状态
    print("1️⃣ 检查应用状态")
    print("-" * 40)
    
    try:
        # 检查健康状态
        health_url = f"{base_url}/health"
        response = requests.get(health_url, timeout=10)
        
        print(f"健康检查状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ 应用正常运行")
            try:
                data = response.json()
                print(f"健康检查响应: {data}")
            except:
                print(f"健康检查响应: {response.text}")
        else:
            print(f"❌ 应用异常: {response.status_code}")
            print(f"响应: {response.text[:200]}...")
            
    except Exception as e:
        print(f"❌ 健康检查失败: {e}")
    
    print()
    
    # 2. 检查API端点
    print("2️⃣ 检查API端点")
    print("-" * 40)
    
    try:
        # 检查根路径
        root_url = f"{base_url}/"
        response = requests.get(root_url, timeout=10)
        
        print(f"根路径状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ 根路径正常")
            print(f"响应内容: {response.text[:100]}...")
            
            # 检查是否是Hono应用
            if "Hello world!" in response.text:
                print("❌ 检测到Hono应用！Railway配置有问题")
                print("🔧 需要修复Railway项目配置")
            else:
                print("✅ 不是Hono应用，可能是Python应用")
        else:
            print(f"❌ 根路径异常: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 根路径检查失败: {e}")
    
    print()
    
    # 3. 检查Python应用端点
    print("3️⃣ 检查Python应用端点")
    print("-" * 40)
    
    try:
        # 检查API文档
        docs_url = f"{base_url}/docs"
        response = requests.get(docs_url, timeout=10)
        
        print(f"API文档状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ Python FastAPI应用正常运行")
            print("✅ 检测到FastAPI文档页面")
        else:
            print(f"❌ API文档不可用: {response.status_code}")
            
    except Exception as e:
        print(f"❌ API文档检查失败: {e}")
    
    print()
    
    # 4. 检查认证端点
    print("4️⃣ 检查认证端点")
    print("-" * 40)
    
    try:
        # 检查认证状态
        auth_url = f"{base_url}/api/secure-auth/status"
        response = requests.get(auth_url, timeout=10)
        
        print(f"认证状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ 认证端点正常")
            try:
                data = response.json()
                print(f"认证响应: {data}")
            except:
                print(f"认证响应: {response.text}")
        else:
            print(f"❌ 认证端点异常: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 认证端点检查失败: {e}")
    
    print()
    
    # 5. 检查Redis状态
    print("5️⃣ 检查Redis状态")
    print("-" * 40)
    
    try:
        # 检查Redis状态
        redis_url = f"{base_url}/api/secure-auth/redis-status"
        response = requests.get(redis_url, timeout=10)
        
        print(f"Redis状态码: {response.status_code}")
        if response.status_code == 200:
            print("✅ Redis状态检查正常")
            try:
                data = response.json()
                print(f"Redis状态: {data}")
            except:
                print(f"Redis状态: {response.text}")
        else:
            print(f"❌ Redis状态检查异常: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Redis状态检查失败: {e}")

def analyze_railway_issues():
    """分析Railway问题"""
    print("\n📊 分析Railway问题")
    print("=" * 60)
    
    print("🔍 可能的问题:")
    print("  1. Railway项目被重置为默认模板")
    print("  2. Python应用被Hono应用覆盖")
    print("  3. 项目配置错误")
    print("  4. 启动命令错误")
    print()
    
    print("🔧 修复建议:")
    print("  1. 检查Railway项目设置")
    print("  2. 确保项目类型是Python")
    print("  3. 检查启动命令")
    print("  4. 重新部署应用")
    print()
    
    print("🔍 检查步骤:")
    print("  1. 登录Railway控制台")
    print("  2. 进入项目设置")
    print("  3. 检查项目类型")
    print("  4. 检查启动命令")
    print("  5. 检查环境变量")
    print()
    
    print("⚠️  注意事项:")
    print("  1. 如果检测到Hono应用，需要重新配置")
    print("  2. 确保Python应用正确部署")
    print("  3. 检查所有配置文件")
    print("  4. 重新部署应用")

def main():
    """主函数"""
    print("🚀 Railway部署配置检查")
    print("=" * 60)
    
    # 检查Railway部署配置
    check_railway_deployment()
    
    # 分析Railway问题
    analyze_railway_issues()
    
    print("\n📋 检查总结:")
    print("Railway部署配置检查完成")
    print("请查看上述结果，确认问题原因")

if __name__ == "__main__":
    main()
