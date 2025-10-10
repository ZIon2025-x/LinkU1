#!/usr/bin/env python3
"""
测试令牌解析逻辑
"""

def test_token_parsing():
    # 模拟实际令牌
    token = "27167013_1760093983_787418e0:27167013:16668888:27167013:1760093983:75be96ca69e3e48c2b2dccbafe05e6a0d659b6b97733a80cee2f5d7fa13b6976"
    
    print(f"原始令牌: {token}")
    print()
    
    parts = token.split(':')
    print(f"分割后的部分数量: {len(parts)}")
    for i, part in enumerate(parts):
        print(f"  parts[{i}] = {part}")
    
    print()
    
    # 测试新的解析逻辑
    token_image_id = parts[0]
    token_user_id = parts[1]
    
    # 找到时间戳和签名的位置
    timestamp = None
    signature = None
    participants = []
    
    # 从后往前找时间戳和签名
    for i in range(len(parts) - 1, 1, -1):
        try:
            # 尝试解析为时间戳
            timestamp = int(parts[i])
            # 如果成功，那么前面的都是参与者，后面的是签名
            participants = parts[2:i]
            signature = parts[i + 1]
            break
        except ValueError:
            continue
    
    print("解析结果:")
    print(f"  image_id: {token_image_id}")
    print(f"  user_id: {token_user_id}")
    print(f"  participants: {participants}")
    print(f"  timestamp: {timestamp}")
    print(f"  signature: {signature}")
    
    # 验证参与者列表
    if "27167013" in participants:
        print("✅ 用户27167013在参与者列表中")
    else:
        print("❌ 用户27167013不在参与者列表中")
    
    # 验证时间戳
    import time
    current_time = time.time()
    if timestamp and current_time - timestamp < 24 * 60 * 60:
        print("✅ 令牌未过期")
    else:
        print("❌ 令牌已过期")

if __name__ == "__main__":
    test_token_parsing()
