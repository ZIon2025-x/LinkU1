#!/usr/bin/env python3
"""
测试岗位管理功能
"""

import requests
import json
import sys
import os

# 添加项目根目录到Python路径
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# API基础URL
API_BASE_URL = "https://api.link2ur.com"

def test_public_job_positions():
    """测试公开岗位API"""
    print("=== 测试公开岗位API ===")
    
    try:
        # 测试获取公开岗位列表
        response = requests.get(f"{API_BASE_URL}/api/job-positions")
        print(f"状态码: {response.status_code}")
        
        if response.status_code == 200:
            data = response.json()
            print(f"岗位数量: {data.get('total', 0)}")
            print(f"当前页: {data.get('page', 1)}")
            print(f"每页数量: {data.get('size', 20)}")
            
            positions = data.get('positions', [])
            if positions:
                print("\n前3个岗位:")
                for i, pos in enumerate(positions[:3]):
                    print(f"{i+1}. {pos.get('title')} - {pos.get('department')} - {pos.get('type')}")
            else:
                print("没有找到岗位数据")
        else:
            print(f"请求失败: {response.text}")
            
    except Exception as e:
        print(f"测试失败: {e}")

def test_admin_job_positions():
    """测试管理员岗位API（需要认证）"""
    print("\n=== 测试管理员岗位API ===")
    
    # 这里需要管理员登录，暂时跳过
    print("需要管理员认证，跳过测试")

if __name__ == "__main__":
    test_public_job_positions()
    test_admin_job_positions()
    print("\n测试完成！")
