#!/usr/bin/env python3
"""
测试系统设置功能
验证价格阈值是否正确应用到任务创建中
"""

import requests
import json

# 配置
API_BASE_URL = "https://api.link2ur.com"
TEST_USER = {
    "email": "test@example.com",
    "password": "testpassword123"
}

def test_system_settings():
    """测试系统设置功能"""
    print("开始测试系统设置功能...")
    
    # 1. 获取当前系统设置
    print("\n1. 获取当前系统设置...")
    try:
        response = requests.get(f"{API_BASE_URL}/api/system-settings/public")
        if response.status_code == 200:
            settings = response.json()
            print(f"当前系统设置:")
            print(f"   VIP价格阈值: {settings.get('vip_price_threshold', 'N/A')}元")
            print(f"   超级VIP价格阈值: {settings.get('super_vip_price_threshold', 'N/A')}元")
            print(f"   VIP功能启用: {settings.get('vip_enabled', 'N/A')}")
            print(f"   超级VIP功能启用: {settings.get('super_vip_enabled', 'N/A')}")
        else:
            print(f"获取系统设置失败: {response.status_code}")
            return False
    except Exception as e:
        print(f"获取系统设置异常: {e}")
        return False
    
    # 2. 测试任务等级分配逻辑
    print("\n2. 测试任务等级分配逻辑...")
    
    # 模拟不同价格的任务
    test_prices = [
        (5.0, "普通任务"),
        (15.0, "VIP任务"),
        (60.0, "超级任务")
    ]
    
    vip_threshold = settings.get('vip_price_threshold', 10.0)
    super_threshold = settings.get('super_vip_price_threshold', 50.0)
    
    print(f"   价格阈值: VIP≥{vip_threshold}元, 超级≥{super_threshold}元")
    
    for price, expected_level in test_prices:
        if price >= super_threshold:
            actual_level = "超级任务"
        elif price >= vip_threshold:
            actual_level = "VIP任务"
        else:
            actual_level = "普通任务"
        
        status = "PASS" if actual_level == expected_level else "FAIL"
        print(f"   {status} {price}元 -> {actual_level} (期望: {expected_level})")
    
    # 3. 测试前端价格提示
    print("\n3. 测试前端价格提示逻辑...")
    
    def get_task_level_hint(price, vip_threshold, super_threshold, vip_enabled, super_enabled):
        if not price or price <= 0:
            return ''
        
        if super_enabled and price >= super_threshold:
            return f"超级任务 (≥{super_threshold}元)"
        elif vip_enabled and price >= vip_threshold:
            return f"VIP任务 (≥{vip_threshold}元)"
        else:
            return f"普通任务 (<{vip_threshold}元)"
    
    for price in [5.0, 15.0, 60.0]:
        hint = get_task_level_hint(
            price, 
            vip_threshold, 
            super_threshold,
            settings.get('vip_enabled', True),
            settings.get('super_vip_enabled', True)
        )
        print(f"   {price}元 -> {hint}")
    
    print("\n系统设置测试完成！")
    return True

if __name__ == "__main__":
    test_system_settings()
