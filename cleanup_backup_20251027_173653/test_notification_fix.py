#!/usr/bin/env python3
"""
测试通知系统修复
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_notification_system():
    """测试完整的通知流程"""
    print("=== 测试通知系统修复 ===\n")
    
    # 1. 注册两个测试用户
    print("1. 注册测试用户...")
    
    # 用户1 - 发布者
    poster_data = {
        "name": "发布者测试",
        "email": "poster@test.com",
        "password": "test123456",
        "phone": "12345678901"
    }
    
    response = requests.post(f"{BASE_URL}/api/register", json=poster_data)
    if response.status_code == 200:
        poster_cookies = response.cookies
        print("✓ 发布者注册成功")
    else:
        print(f"✗ 发布者注册失败: {response.status_code} - {response.text}")
        return
    
    # 用户2 - 申请者
    applicant_data = {
        "name": "申请者测试",
        "email": "applicant@test.com", 
        "password": "test123456",
        "phone": "12345678902"
    }
    
    response = requests.post(f"{BASE_URL}/api/register", json=applicant_data)
    if response.status_code == 200:
        applicant_cookies = response.cookies
        print("✓ 申请者注册成功")
    else:
        print(f"✗ 申请者注册失败: {response.status_code} - {response.text}")
        return
    
    # 2. 发布者创建任务
    print("\n2. 发布者创建任务...")
    task_data = {
        "title": "通知测试任务",
        "description": "这是一个用于测试通知系统的任务",
        "reward": 50.0,
        "location": "测试地点",
        "task_level": "normal"
    }
    
    response = requests.post(
        f"{BASE_URL}/api/tasks",
        json=task_data,
        cookies=poster_cookies
    )
    if response.status_code == 200:
        task = response.json()
        task_id = task["id"]
        print(f"✓ 任务创建成功，ID: {task_id}")
    else:
        print(f"✗ 任务创建失败: {response.status_code} - {response.text}")
        return
    
    # 3. 检查发布者初始通知
    print("\n3. 检查发布者初始通知...")
    response = requests.get(f"{BASE_URL}/api/notifications", cookies=poster_cookies)
    if response.status_code == 200:
        notifications = response.json()
        print(f"✓ 发布者当前有 {len(notifications)} 条通知")
        for notif in notifications:
            print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
    else:
        print(f"✗ 获取发布者通知失败: {response.status_code} - {response.text}")
    
    # 4. 申请者申请任务
    print("\n4. 申请者申请任务...")
    application_data = {
        "message": "我想申请这个任务"
    }
    
    response = requests.post(
        f"{BASE_URL}/api/tasks/{task_id}/apply",
        json=application_data,
        cookies=applicant_cookies
    )
    if response.status_code == 200:
        print("✓ 任务申请成功")
    else:
        print(f"✗ 任务申请失败: {response.status_code} - {response.text}")
        return
    
    # 等待一下让通知处理完成
    time.sleep(2)
    
    # 5. 检查发布者是否收到申请通知
    print("\n5. 检查发布者是否收到申请通知...")
    response = requests.get(f"{BASE_URL}/api/notifications", cookies=poster_cookies)
    if response.status_code == 200:
        notifications = response.json()
        print(f"✓ 发布者现在有 {len(notifications)} 条通知")
        
        # 查找申请通知
        application_notifications = [n for n in notifications if n.get('type') == 'task_application']
        if application_notifications:
            print("✓ 找到任务申请通知！")
            for notif in application_notifications:
                print(f"  - 标题: {notif.get('title', 'N/A')}")
                print(f"  - 内容: {notif.get('content', 'N/A')}")
                print(f"  - 类型: {notif.get('type', 'N/A')}")
        else:
            print("✗ 没有找到任务申请通知")
            print("所有通知类型:", [n.get('type') for n in notifications])
    else:
        print(f"✗ 获取发布者通知失败: {response.status_code} - {response.text}")
    
    # 6. 检查申请者初始通知
    print("\n6. 检查申请者初始通知...")
    response = requests.get(f"{BASE_URL}/api/notifications", cookies=applicant_cookies)
    if response.status_code == 200:
        notifications = response.json()
        print(f"✓ 申请者当前有 {len(notifications)} 条通知")
        for notif in notifications:
            print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
    else:
        print(f"✗ 获取申请者通知失败: {response.status_code} - {response.text}")
    
    # 7. 发布者同意申请
    print("\n7. 发布者同意申请...")
    # 先获取申请列表
    response = requests.get(f"{BASE_URL}/api/tasks/{task_id}/applications", cookies=poster_cookies)
    if response.status_code == 200:
        applications = response.json()
        if applications:
            applicant_id = applications[0]["applicant_id"]
            print(f"找到申请者ID: {applicant_id}")
            
            # 同意申请
            response = requests.post(
                f"{BASE_URL}/api/tasks/{task_id}/approve/{applicant_id}",
                cookies=poster_cookies
            )
            if response.status_code == 200:
                print("✓ 申请同意成功")
            else:
                print(f"✗ 申请同意失败: {response.status_code} - {response.text}")
                return
        else:
            print("✗ 没有找到申请记录")
            return
    else:
        print(f"✗ 获取申请列表失败: {response.status_code} - {response.text}")
        return
    
    # 等待一下让通知处理完成
    time.sleep(2)
    
    # 8. 检查申请者是否收到同意通知
    print("\n8. 检查申请者是否收到同意通知...")
    response = requests.get(f"{BASE_URL}/api/notifications", cookies=applicant_cookies)
    if response.status_code == 200:
        notifications = response.json()
        print(f"✓ 申请者现在有 {len(notifications)} 条通知")
        
        # 查找同意通知
        approval_notifications = [n for n in notifications if n.get('type') == 'task_approved']
        if approval_notifications:
            print("✓ 找到任务同意通知！")
            for notif in approval_notifications:
                print(f"  - 标题: {notif.get('title', 'N/A')}")
                print(f"  - 内容: {notif.get('content', 'N/A')}")
                print(f"  - 类型: {notif.get('type', 'N/A')}")
        else:
            print("✗ 没有找到任务同意通知")
            print("所有通知类型:", [n.get('type') for n in notifications])
    else:
        print(f"✗ 获取申请者通知失败: {response.status_code} - {response.text}")
    
    print("\n🎉 通知系统测试完成！")

if __name__ == "__main__":
    test_notification_system()
