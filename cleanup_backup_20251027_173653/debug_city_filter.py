#!/usr/bin/env python3
"""
调试城市筛选问题
"""

import requests
import json

def debug_city_filter():
    base_url = 'http://localhost:8000'
    
    print("=== 城市筛选调试 ===")
    
    # 测试不同的城市筛选
    test_cases = [
        {'city': 'all', 'name': '全部城市'},
        {'city': 'London', 'name': 'London'},
        {'city': 'Edinburgh', 'name': 'Edinburgh'},
        {'city': 'Online', 'name': 'Online'},
    ]
    
    for test_case in test_cases:
        city = test_case['city']
        name = test_case['name']
        
        print(f"\n--- 测试 {name} ({city}) ---")
        
        # 构建URL
        if city == 'all':
            url = f"{base_url}/api/tasks"
        else:
            url = f"{base_url}/api/tasks?location={city}"
        
        print(f"请求URL: {url}")
        
        try:
            response = requests.get(url)
            print(f"状态码: {response.status_code}")
            
            if response.status_code == 200:
                data = response.json()
                total = data.get('total', 0)
                tasks = data.get('tasks', [])
                
                print(f"总任务数: {total}")
                print(f"返回任务数: {len(tasks)}")
                
                if tasks:
                    print("前3个任务:")
                    for i, task in enumerate(tasks[:3]):
                        print(f"  {i+1}. {task.get('title', 'N/A')} - {task.get('location', 'N/A')}")
                else:
                    print("没有找到任务")
            else:
                print(f"请求失败: {response.text}")
                
        except Exception as e:
            print(f"请求异常: {e}")

if __name__ == "__main__":
    debug_city_filter()
