#!/usr/bin/env python3
"""
测试分页排序功能
"""

import requests
import json

def test_pagination_sorting():
    base_url = 'http://localhost:8000'
    
    print("=== 分页排序测试 ===")
    
    # 测试按金额升序排序的分页
    print("\n--- 测试按金额升序排序 ---")
    
    # 获取第一页
    response1 = requests.get(f'{base_url}/api/tasks?sort_by=reward_asc&page=1&page_size=3')
    if response1.status_code == 200:
        data1 = response1.json()
        tasks1 = data1.get('tasks', [])
        print(f"第一页任务数: {len(tasks1)}")
        print("第一页任务金额:")
        for i, task in enumerate(tasks1):
            print(f"  {i+1}. {task.get('title', 'N/A')} - £{task.get('reward', 0)}")
    else:
        print(f"第一页请求失败: {response1.status_code}")
        return
    
    # 获取第二页
    response2 = requests.get(f'{base_url}/api/tasks?sort_by=reward_asc&page=2&page_size=3')
    if response2.status_code == 200:
        data2 = response2.json()
        tasks2 = data2.get('tasks', [])
        print(f"\n第二页任务数: {len(tasks2)}")
        print("第二页任务金额:")
        for i, task in enumerate(tasks2):
            print(f"  {i+1}. {task.get('title', 'N/A')} - £{task.get('reward', 0)}")
    else:
        print(f"第二页请求失败: {response2.status_code}")
        return
    
    # 检查排序连续性
    if tasks1 and tasks2:
        last_task_page1 = tasks1[-1]
        first_task_page2 = tasks2[0]
        
        last_reward = last_task_page1.get('reward', 0)
        first_reward = first_task_page2.get('reward', 0)
        
        print(f"\n排序连续性检查:")
        print(f"第一页最后一个任务金额: £{last_reward}")
        print(f"第二页第一个任务金额: £{first_reward}")
        
        if last_reward <= first_reward:
            print("✓ 排序连续，分页正确")
        else:
            print("✗ 排序不连续，分页有问题")
    
    # 测试按金额降序排序的分页
    print("\n--- 测试按金额降序排序 ---")
    
    # 获取第一页
    response3 = requests.get(f'{base_url}/api/tasks?sort_by=reward_desc&page=1&page_size=3')
    if response3.status_code == 200:
        data3 = response3.json()
        tasks3 = data3.get('tasks', [])
        print(f"第一页任务数: {len(tasks3)}")
        print("第一页任务金额:")
        for i, task in enumerate(tasks3):
            print(f"  {i+1}. {task.get('title', 'N/A')} - £{task.get('reward', 0)}")
    else:
        print(f"第一页请求失败: {response3.status_code}")
        return
    
    # 获取第二页
    response4 = requests.get(f'{base_url}/api/tasks?sort_by=reward_desc&page=2&page_size=3')
    if response4.status_code == 200:
        data4 = response4.json()
        tasks4 = data4.get('tasks', [])
        print(f"\n第二页任务数: {len(tasks4)}")
        print("第二页任务金额:")
        for i, task in enumerate(tasks4):
            print(f"  {i+1}. {task.get('title', 'N/A')} - £{task.get('reward', 0)}")
    else:
        print(f"第二页请求失败: {response4.status_code}")
        return
    
    # 检查排序连续性
    if tasks3 and tasks4:
        last_task_page1 = tasks3[-1]
        first_task_page2 = tasks4[0]
        
        last_reward = last_task_page1.get('reward', 0)
        first_reward = first_task_page2.get('reward', 0)
        
        print(f"\n排序连续性检查:")
        print(f"第一页最后一个任务金额: £{last_reward}")
        print(f"第二页第一个任务金额: £{first_reward}")
        
        if last_reward >= first_reward:
            print("✓ 排序连续，分页正确")
        else:
            print("✗ 排序不连续，分页有问题")

if __name__ == "__main__":
    test_pagination_sorting()
