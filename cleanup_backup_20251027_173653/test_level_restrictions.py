#!/usr/bin/env python3
"""
测试等级限制功能
"""

import requests
import json

# 测试用户凭据
users = {
    'normal': {'email': 'normal@test.com', 'password': '123456'},
    'vip': {'email': 'vip@test.com', 'password': '123456'},
    'super': {'email': 'super@test.com', 'password': '123456'}
}

# 任务等级
task_levels = ['normal', 'vip', 'super']

def login_user(email, password):
    """登录用户并获取session"""
    response = requests.post('http://localhost:8000/api/users/login', 
                           data={'username': email, 'password': password})
    print(f"登录响应状态: {response.status_code}")
    if response.status_code == 200:
        session_id = response.cookies.get('session_id')
        print(f"获取到session_id: {session_id[:10] if session_id else 'None'}...")
        return session_id
    else:
        print(f"登录失败: {response.text}")
    return None

def test_apply_task(session_id, task_id, user_level):
    """测试申请任务"""
    headers = {
        'X-CSRF-Token': 'test-token',
        'Cookie': f'session_id={session_id}'
    }
    
    response = requests.post(f'http://localhost:8000/api/tasks/{task_id}/apply',
                           headers=headers,
                           data={'message': f'{user_level}用户申请任务'})
    
    return response.status_code, response.json() if response.status_code != 200 else response.json()

def main():
    print("测试等级限制功能")
    print("=" * 50)
    
    # 获取任务列表
    response = requests.get('http://localhost:8000/api/tasks')
    if response.status_code != 200:
        print("无法获取任务列表")
        return
    
    data = response.json()
    print(f"API响应: {type(data)}")
    print(f"数据内容: {data}")
    
    # 检查数据结构
    if isinstance(data, dict) and 'tasks' in data:
        tasks = data['tasks']
    elif isinstance(data, dict) and 'items' in data:
        tasks = data['items']
    elif isinstance(data, list):
        tasks = data
    else:
        print("未知的数据格式")
        return
    
    print(f"找到 {len(tasks)} 个任务")
    
    # 按等级分组任务
    tasks_by_level = {}
    for task in tasks:
        if isinstance(task, dict):
            level = task.get('task_level', 'normal')
            if level not in tasks_by_level:
                tasks_by_level[level] = []
            tasks_by_level[level].append(task)
        else:
            print(f"任务数据格式错误: {task}")
    
    print("\n任务分布:")
    for level, task_list in tasks_by_level.items():
        print(f"  {level.upper()}: {len(task_list)} 个")
    
    print("\n测试等级限制:")
    
    # 测试每个用户等级
    for user_level, credentials in users.items():
        print(f"\n测试 {user_level.upper()} 用户:")
        
        # 登录用户
        session_id = login_user(credentials['email'], credentials['password'])
        if not session_id:
            print(f"  登录失败")
            continue
        
        print(f"  登录成功")
        
        # 测试申请不同等级的任务
        for task_level, task_list in tasks_by_level.items():
            if not task_list:
                continue
                
            task = task_list[0]  # 取第一个任务测试
            print(f"  申请 {task_level.upper()} 任务 (ID: {task['id']}):")
            
            status_code, result = test_apply_task(session_id, task['id'], user_level)
            
            if status_code == 200:
                print(f"    申请成功: {result.get('message', '')}")
            elif status_code == 403:
                print(f"    等级不足: {result.get('detail', '')}")
            else:
                print(f"    申请失败 ({status_code}): {result.get('detail', '')}")

if __name__ == "__main__":
    main()
