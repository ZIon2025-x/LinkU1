#!/usr/bin/env python3
"""
测试价格阈值功能
"""

def test_task_level_assignment():
    """测试任务等级分配逻辑"""
    print("测试任务等级分配逻辑...")
    
    # 模拟系统设置
    vip_price_threshold = 100.0  # 您设置的VIP价格阈值
    super_vip_price_threshold = 500.0  # 超级VIP价格阈值
    
    # 测试不同价格的任务
    test_cases = [
        (50.0, "普通任务"),
        (100.0, "VIP任务"),  # 等于阈值
        (150.0, "VIP任务"),  # 大于阈值
        (500.0, "超级任务"),  # 等于超级阈值
        (600.0, "超级任务"),  # 大于超级阈值
    ]
    
    for price, expected in test_cases:
        # 模拟后端逻辑
        if price >= super_vip_price_threshold:
            actual = "超级任务"
        elif price >= vip_price_threshold:
            actual = "VIP任务"
        else:
            actual = "普通任务"
        
        status = "✅" if actual == expected else "❌"
        print(f"  {status} {price}元 -> {actual} (期望: {expected})")

if __name__ == "__main__":
    test_task_level_assignment()
