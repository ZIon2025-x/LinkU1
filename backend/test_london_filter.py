#!/usr/bin/env python3
"""
测试London任务筛选功能
"""

import requests
import json

def test_london_filter():
    base_url = 'http://localhost:8000'
    print('测试任务列表API...')

    # 测试获取所有任务
    response = requests.get(f'{base_url}/api/tasks')
    print(f'所有任务状态码: {response.status_code}')
    if response.status_code == 200:
        data = response.json()
        print(f'总任务数: {data.get("total", 0)}')
        print(f'返回任务数: {len(data.get("tasks", []))}')
    else:
        print(f'错误: {response.text}')
        return

    # 测试London筛选
    print('\n测试London筛选...')
    response = requests.get(f'{base_url}/api/tasks?location=London')
    print(f'London任务状态码: {response.status_code}')
    if response.status_code == 200:
        data = response.json()
        print(f'London任务数: {data.get("total", 0)}')
        tasks = data.get('tasks', [])
        if tasks:
            print('前3个London任务:')
            for i, task in enumerate(tasks[:3]):
                print(f'  {i+1}. {task.get("title", "N/A")} - {task.get("location", "N/A")}')
        else:
            print('没有找到London任务')
    else:
        print(f'错误: {response.text}')

    # 测试all筛选
    print('\n测试all筛选...')
    response = requests.get(f'{base_url}/api/tasks?location=all')
    print(f'all任务状态码: {response.status_code}')
    if response.status_code == 200:
        data = response.json()
        print(f'all任务数: {data.get("total", 0)}')

if __name__ == "__main__":
    test_london_filter()
