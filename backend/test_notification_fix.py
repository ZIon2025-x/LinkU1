#!/usr/bin/env python3
"""
测试通知系统修复
"""

import requests
import json
import time

BASE_URL = "http://localhost:8000"

def test_notification_fix():
    """测试通知系统修复"""
    print("🧪 测试通知系统修复...")
    
    # 1. 注册发布者
    print("\n1. 注册任务发布者...")
    poster_data = {
        "email": "poster_test@example.com",
        "password": "testpass123",
        "name": "poster_test",
        "phone": "1234567890"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=poster_data)
        if response.status_code == 200:
            print("✅ 发布者注册成功")
        else:
            print(f"❌ 发布者注册失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 发布者注册异常: {e}")
        return
    
    # 2. 登录发布者
    print("\n2. 登录发布者...")
    try:
        login_data = {
            "email": poster_data["email"],
            "password": poster_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("✅ 发布者登录成功")
            poster_cookies = response.cookies
        else:
            print(f"❌ 发布者登录失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 发布者登录异常: {e}")
        return
    
    # 3. 创建任务
    print("\n3. 创建测试任务...")
    try:
        task_data = {
            "title": "通知测试任务",
            "description": "这是一个用于测试通知系统的任务",
            "reward": 50.0,
            "task_level": "normal",
            "location": "测试地点"
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks", 
            json=task_data,
            cookies=poster_cookies
        )
        if response.status_code == 200:
            task = response.json()
            task_id = task["id"]
            print(f"✅ 任务创建成功，ID: {task_id}")
        else:
            print(f"❌ 任务创建失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 任务创建异常: {e}")
        return
    
    # 4. 注册申请者
    print("\n4. 注册任务申请者...")
    applicant_data = {
        "email": "applicant_test@example.com",
        "password": "testpass123",
        "name": "applicant_test",
        "phone": "0987654321"
    }
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=applicant_data)
        if response.status_code == 200:
            print("✅ 申请者注册成功")
        else:
            print(f"❌ 申请者注册失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 申请者注册异常: {e}")
        return
    
    # 5. 登录申请者
    print("\n5. 登录申请者...")
    try:
        login_data = {
            "email": applicant_data["email"],
            "password": applicant_data["password"]
        }
        response = requests.post(f"{BASE_URL}/api/secure-auth/login", json=login_data)
        if response.status_code == 200:
            print("✅ 申请者登录成功")
            applicant_cookies = response.cookies
        else:
            print(f"❌ 申请者登录失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 申请者登录异常: {e}")
        return
    
    # 6. 申请任务（应该发送通知给发布者）
    print("\n6. 申请任务（测试申请通知）...")
    try:
        apply_data = {
            "message": "我想申请这个任务！"
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks/{task_id}/apply",
            json=apply_data,
            cookies=applicant_cookies
        )
        if response.status_code == 200:
            print("✅ 任务申请成功")
        else:
            print(f"❌ 任务申请失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 任务申请异常: {e}")
        return
    
    # 7. 检查发布者是否收到通知
    print("\n7. 检查发布者通知...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=poster_cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"✅ 发布者收到 {len(notifications)} 条通知")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"❌ 获取发布者通知失败: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ 检查发布者通知异常: {e}")
    
    # 8. 发布者同意申请
    print("\n8. 发布者同意申请...")
    try:
        # 获取申请者ID
        response = requests.get(
            f"{BASE_URL}/api/tasks/{task_id}/applications",
            cookies=poster_cookies
        )
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
                    print("✅ 申请同意成功")
                else:
                    print(f"❌ 申请同意失败: {response.status_code} - {response.text}")
                    return
            else:
                print("❌ 没有找到申请记录")
                return
        else:
            print(f"❌ 获取申请列表失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 申请同意异常: {e}")
        return
    
    # 9. 检查申请者是否收到通知
    print("\n9. 检查申请者通知...")
    try:
        response = requests.get(f"{BASE_URL}/api/notifications", cookies=applicant_cookies)
        if response.status_code == 200:
            notifications = response.json()
            print(f"✅ 申请者收到 {len(notifications)} 条通知")
            for notif in notifications:
                print(f"  - {notif.get('title', 'N/A')}: {notif.get('content', 'N/A')}")
        else:
            print(f"❌ 获取申请者通知失败: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"❌ 检查申请者通知异常: {e}")
    
    print("\n🎉 通知系统测试完成！")
    print("\n📋 测试结果总结：")
    print("1. 任务申请应该发送通知给发布者")
    print("2. 申请同意应该发送通知给申请者")
    print("3. 任务进行中时发布者应该能看到联系接收者的按钮")
    print("4. 请检查前端通知面板是否显示通知")

if __name__ == "__main__":
    test_notification_fix()
