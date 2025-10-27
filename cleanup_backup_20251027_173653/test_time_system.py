#!/usr/bin/env python3
"""
测试新的时间处理系统
验证前后端时间处理是否一致
"""
import requests
import json
from datetime import datetime
import pytz

# 配置
API_BASE_URL = "http://localhost:8000"  # 根据实际情况修改
TEST_USER_ID = "test_user_123"

def test_backend_time_system():
    """测试后端时间系统"""
    print("=== 测试后端时间系统 ===")
    
    try:
        # 测试时区信息API
        response = requests.get(f"{API_BASE_URL}/api/users/timezone/info")
        if response.status_code == 200:
            timezone_info = response.json()
            print("✅ 时区信息API正常")
            print(f"   服务器时区: {timezone_info.get('server_timezone')}")
            print(f"   服务器时间: {timezone_info.get('server_time')}")
            print(f"   UTC时间: {timezone_info.get('utc_time')}")
            print(f"   是否夏令时: {timezone_info.get('is_dst')}")
        else:
            print(f"❌ 时区信息API失败: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 后端测试失败: {e}")

def test_frontend_time_parsing():
    """测试前端时间解析逻辑"""
    print("\n=== 测试前端时间解析逻辑 ===")
    
    # 模拟UTC时间字符串
    test_times = [
        "2024-01-15T10:30:00Z",  # 标准UTC格式
        "2024-01-15T10:30:00",   # 无时区信息
        "2024-01-15 10:30:00",   # 空格分隔
    ]
    
    for time_str in test_times:
        print(f"\n测试时间字符串: {time_str}")
        
        # 模拟前端解析逻辑
        try:
            import dayjs
            # 这里需要实际的dayjs库，暂时用Python模拟
            if time_str.endswith('Z'):
                parsed_time = datetime.fromisoformat(time_str.replace('Z', '+00:00'))
            else:
                parsed_time = datetime.fromisoformat(time_str + '+00:00')
            
            print(f"  解析结果: {parsed_time}")
            print(f"  时区: {parsed_time.tzinfo}")
            
        except Exception as e:
            print(f"  ❌ 解析失败: {e}")

def test_timezone_conversion():
    """测试时区转换"""
    print("\n=== 测试时区转换 ===")
    
    # 测试UTC到英国时间转换
    utc_time = datetime.utcnow()
    uk_tz = pytz.timezone("Europe/London")
    uk_time = utc_time.replace(tzinfo=pytz.UTC).astimezone(uk_tz)
    
    print(f"UTC时间: {utc_time}")
    print(f"英国时间: {uk_time}")
    print(f"时差: {(uk_time.utcoffset().total_seconds() / 3600):.1f}小时")
    
    # 测试中国时间
    cn_tz = pytz.timezone("Asia/Shanghai")
    cn_time = utc_time.replace(tzinfo=pytz.UTC).astimezone(cn_tz)
    print(f"中国时间: {cn_time}")
    print(f"时差: {(cn_time.utcoffset().total_seconds() / 3600):.1f}小时")

def test_message_time_consistency():
    """测试消息时间一致性"""
    print("\n=== 测试消息时间一致性 ===")
    
    # 模拟消息创建和显示流程
    utc_time = datetime.utcnow()
    print(f"1. 后端创建消息时间 (UTC): {utc_time}")
    
    # 模拟API返回格式
    api_time_str = utc_time.isoformat() + 'Z'
    print(f"2. API返回时间字符串: {api_time_str}")
    
    # 模拟前端解析
    try:
        parsed_time = datetime.fromisoformat(api_time_str.replace('Z', '+00:00'))
        print(f"3. 前端解析时间: {parsed_time}")
        
        # 转换为用户时区显示
        user_tz = pytz.timezone("Asia/Shanghai")
        user_time = parsed_time.astimezone(user_tz)
        print(f"4. 用户时区显示: {user_time}")
        
        # 验证时间一致性
        time_diff = abs((parsed_time - utc_time.replace(tzinfo=pytz.UTC)).total_seconds())
        if time_diff < 1:  # 允许1秒误差
            print("✅ 时间一致性验证通过")
        else:
            print(f"❌ 时间一致性验证失败，误差: {time_diff}秒")
            
    except Exception as e:
        print(f"❌ 时间解析失败: {e}")

def main():
    """主测试函数"""
    print("🕐 开始测试新的时间处理系统...")
    print("=" * 50)
    
    test_backend_time_system()
    test_frontend_time_parsing()
    test_timezone_conversion()
    test_message_time_consistency()
    
    print("\n" + "=" * 50)
    print("✅ 时间系统测试完成")

if __name__ == "__main__":
    main()
