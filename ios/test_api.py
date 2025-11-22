#!/usr/bin/bin/env python3
"""
iOS 应用 API 测试脚本
在 Windows 上可以运行此脚本测试后端 API
"""

import requests
import json
from typing import Optional

# 配置
API_BASE_URL = "https://api.link2ur.com"
WS_BASE_URL = "wss://api.link2ur.com"

class APITester:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.token: Optional[str] = None
        self.session = requests.Session()
    
    def login(self, email: str, password: str) -> bool:
        """测试登录API"""
        print(f"\n🔐 测试登录: {email}")
        try:
            response = self.session.post(
                f"{self.base_url}/api/auth/login",
                json={"email": email, "password": password},
                headers={"Content-Type": "application/json"}
            )
            
            if response.status_code == 200:
                data = response.json()
                self.token = data.get("access_token")
                print(f"✅ 登录成功")
                print(f"   Token: {self.token[:20]}...")
                self.session.headers.update({
                    "Authorization": f"Bearer {self.token}"
                })
                return True
            else:
                print(f"❌ 登录失败: {response.status_code}")
                print(f"   响应: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 登录错误: {e}")
            return False
    
    def get_tasks(self) -> bool:
        """测试获取任务列表"""
        print(f"\n📋 测试获取任务列表")
        try:
            response = self.session.get(f"{self.base_url}/api/tasks")
            
            if response.status_code == 200:
                data = response.json()
                tasks = data.get("tasks", [])
                print(f"✅ 获取成功: {len(tasks)} 个任务")
                if tasks:
                    print(f"   第一个任务: {tasks[0].get('title', 'N/A')}")
                return True
            else:
                print(f"❌ 获取失败: {response.status_code}")
                print(f"   响应: {response.text}")
                return False
        except Exception as e:
            print(f"❌ 获取错误: {e}")
            return False
    
    def get_flea_market_items(self) -> bool:
        """测试获取跳蚤市场商品"""
        print(f"\n🛒 测试获取跳蚤市场商品")
        try:
            response = self.session.get(f"{self.base_url}/api/flea-market/items")
            
            if response.status_code == 200:
                data = response.json()
                items = data.get("items", [])
                print(f"✅ 获取成功: {len(items)} 个商品")
                if items:
                    print(f"   第一个商品: {items[0].get('title', 'N/A')}")
                return True
            else:
                print(f"❌ 获取失败: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 获取错误: {e}")
            return False
    
    def get_user_profile(self) -> bool:
        """测试获取用户资料"""
        print(f"\n👤 测试获取用户资料")
        try:
            response = self.session.get(f"{self.base_url}/api/users/profile/me")
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ 获取成功")
                print(f"   用户名: {data.get('username', 'N/A')}")
                print(f"   邮箱: {data.get('email', 'N/A')}")
                return True
            else:
                print(f"❌ 获取失败: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 获取错误: {e}")
            return False
    
    def get_unread_count(self) -> bool:
        """测试获取未读消息数量"""
        print(f"\n💬 测试获取未读消息数量")
        try:
            response = self.session.get(f"{self.base_url}/api/users/messages/unread/count")
            
            if response.status_code == 200:
                data = response.json()
                count = data.get("count", 0)
                print(f"✅ 获取成功: {count} 条未读消息")
                return True
            else:
                print(f"❌ 获取失败: {response.status_code}")
                return False
        except Exception as e:
            print(f"❌ 获取错误: {e}")
            return False
    
    def test_all(self, email: str, password: str):
        """运行所有测试"""
        print("=" * 50)
        print("iOS 应用 API 测试")
        print("=" * 50)
        
        # 登录
        if not self.login(email, password):
            print("\n❌ 登录失败，无法继续测试")
            return
        
        # 测试各个API
        results = []
        results.append(("获取任务列表", self.get_tasks()))
        results.append(("获取跳蚤市场商品", self.get_flea_market_items()))
        results.append(("获取用户资料", self.get_user_profile()))
        results.append(("获取未读消息数量", self.get_unread_count()))
        
        # 总结
        print("\n" + "=" * 50)
        print("测试总结")
        print("=" * 50)
        for name, result in results:
            status = "✅ 通过" if result else "❌ 失败"
            print(f"{name}: {status}")
        
        passed = sum(1 for _, r in results if r)
        total = len(results)
        print(f"\n总计: {passed}/{total} 通过")


if __name__ == "__main__":
    # 配置测试账号
    TEST_EMAIL = "test@example.com"  # 更新为实际测试账号
    TEST_PASSWORD = "password123"     # 更新为实际密码
    
    # 更新API地址
    tester = APITester(API_BASE_URL)
    
    # 运行测试
    tester.test_all(TEST_EMAIL, TEST_PASSWORD)

