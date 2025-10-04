#!/usr/bin/env python3
"""
测试任务通知系统
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_task_notifications():
    """测试任务流程通知"""
    print("🧪 测试任务通知系统...")
    
    # 测试数据
    test_data = {
        "email": "test_poster@example.com",
        "password": "testpass123",
        "name": "test_poster",
        "phone": "1234567890"
    }
    
    # 1. 注册发布者
    print("\n1. 注册任务发布者...")
    try:
        response = requests.post(f"{BASE_URL}/api/users/register", json=test_data)
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
            "email": test_data["email"],
            "password": test_data["password"]
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
            "title": "测试通知任务",
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
    try:
        applicant_data = {
            "email": "test_applicant@example.com",
            "password": "testpass123",
            "name": "test_applicant",
            "phone": "0987654321"
        }
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
            "message": "我想申请这个任务，请考虑我！"
        }
        response = requests.post(
            f"{BASE_URL}/api/tasks/{task_id}/apply",
            json=apply_data,
            cookies=applicant_cookies
        )
        if response.status_code == 200:
            print("✅ 任务申请成功，应该已发送通知给发布者")
        else:
            print(f"❌ 任务申请失败: {response.status_code} - {response.text}")
            return
    except Exception as e:
        print(f"❌ 任务申请异常: {e}")
        return
    
    # 7. 发布者同意申请（应该发送通知给申请者）
    print("\n7. 发布者同意申请（测试同意通知）...")
    try:
        # 先获取申请者ID
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
                    print("✅ 申请同意成功，应该已发送通知给申请者")
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
    
    print("\n🎉 任务通知系统测试完成！")
    print("\n📧 请检查以下内容：")
    print("1. 发布者应该收到申请通知邮件")
    print("2. 申请者应该收到同意通知邮件")
    print("3. 数据库中应该有相应的通知记录")
    print("4. 如果配置了邮件服务，应该能收到实际邮件")

if __name__ == "__main__":
    test_task_notifications()
