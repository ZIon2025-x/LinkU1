#!/usr/bin/env python3
"""
测试英国夏冬令时转换
验证UTC到英国时间的DST处理是否正确
"""
import pytz
from datetime import datetime, timedelta
import requests

def test_dst_conversion():
    """测试DST转换"""
    print("=== 测试英国夏冬令时转换 ===")
    
    uk_tz = pytz.timezone("Europe/London")
    
    # 测试不同时期的时间转换
    test_dates = [
        # 冬季时间 (GMT, UTC+0)
        datetime(2024, 1, 15, 12, 0, 0),  # 1月 - 冬令时
        datetime(2024, 2, 15, 12, 0, 0),  # 2月 - 冬令时
        
        # 夏令时开始 (GMT -> BST)
        datetime(2024, 3, 31, 1, 0, 0),   # 3月最后周日 - 夏令时开始
        datetime(2024, 3, 31, 2, 0, 0),   # 夏令时开始后
        
        # 夏季时间 (BST, UTC+1)
        datetime(2024, 6, 15, 12, 0, 0),  # 6月 - 夏令时
        datetime(2024, 7, 15, 12, 0, 0),  # 7月 - 夏令时
        datetime(2024, 8, 15, 12, 0, 0),  # 8月 - 夏令时
        
        # 夏令时结束 (BST -> GMT)
        datetime(2024, 10, 27, 1, 0, 0),  # 10月最后周日 - 夏令时结束
        datetime(2024, 10, 27, 2, 0, 0),  # 夏令时结束后
        
        # 冬季时间 (GMT, UTC+0)
        datetime(2024, 11, 15, 12, 0, 0), # 11月 - 冬令时
        datetime(2024, 12, 15, 12, 0, 0), # 12月 - 冬令时
    ]
    
    for utc_time in test_dates:
        print(f"\nUTC时间: {utc_time}")
        
        # 转换为英国时间
        uk_time = utc_time.replace(tzinfo=pytz.UTC).astimezone(uk_tz)
        is_dst = uk_time.dst().total_seconds() > 0
        tz_name = uk_time.tzname()
        offset_hours = uk_time.utcoffset().total_seconds() / 3600
        
        print(f"英国时间: {uk_time}")
        print(f"时区名称: {tz_name}")
        print(f"是否夏令时: {is_dst}")
        print(f"UTC偏移: {offset_hours:+.0f}小时")
        
        # 验证时区名称
        if is_dst and tz_name != 'BST':
            print("❌ 夏令时时区名称错误")
        elif not is_dst and tz_name != 'GMT':
            print("❌ 冬令时时区名称错误")
        else:
            print("✅ 时区名称正确")

def test_dst_boundary():
    """测试DST边界情况"""
    print("\n=== 测试DST边界情况 ===")
    
    uk_tz = pytz.timezone("Europe/London")
    
    # 2024年夏令时开始：3月31日 01:00 GMT -> 02:00 BST
    print("\n2024年夏令时开始 (3月31日):")
    
    # 夏令时开始前
    before_dst = datetime(2024, 3, 31, 0, 59, 0, tzinfo=pytz.UTC)
    uk_before = before_dst.astimezone(uk_tz)
    print(f"01:59 UTC -> {uk_before} ({uk_before.tzname()})")
    
    # 夏令时开始后
    after_dst = datetime(2024, 3, 31, 1, 1, 0, tzinfo=pytz.UTC)
    uk_after = after_dst.astimezone(uk_tz)
    print(f"01:01 UTC -> {uk_after} ({uk_after.tzname()})")
    
    # 2024年夏令时结束：10月27日 01:00 BST -> 01:00 GMT
    print("\n2024年夏令时结束 (10月27日):")
    
    # 夏令时结束前
    before_end = datetime(2024, 10, 27, 0, 59, 0, tzinfo=pytz.UTC)
    uk_before_end = before_end.astimezone(uk_tz)
    print(f"00:59 UTC -> {uk_before_end} ({uk_before_end.tzname()})")
    
    # 夏令时结束后
    after_end = datetime(2024, 10, 27, 1, 1, 0, tzinfo=pytz.UTC)
    uk_after_end = after_end.astimezone(uk_tz)
    print(f"01:01 UTC -> {uk_after_end} ({uk_after_end.tzname()})")

def test_api_timezone_info():
    """测试API时区信息"""
    print("\n=== 测试API时区信息 ===")
    
    try:
        response = requests.get("http://localhost:8000/api/users/timezone/info")
        if response.status_code == 200:
            info = response.json()
            print("✅ 时区信息API正常")
            print(f"服务器时区: {info.get('server_timezone')}")
            print(f"是否夏令时: {info.get('is_dst')}")
            print(f"时区名称: {info.get('timezone_name')}")
            print(f"UTC偏移: {info.get('offset_hours')}小时")
            
            if 'dst_info' in info:
                dst_info = info['dst_info']
                print(f"DST描述: {dst_info.get('description')}")
        else:
            print(f"❌ API调用失败: {response.status_code}")
    except Exception as e:
        print(f"❌ API测试失败: {e}")

def test_message_time_consistency_with_dst():
    """测试消息时间在DST转换时的一致性"""
    print("\n=== 测试消息时间DST一致性 ===")
    
    uk_tz = pytz.timezone("Europe/London")
    
    # 模拟消息在不同时期的时间
    test_times = [
        datetime(2024, 1, 15, 10, 30, 0),  # 冬令时
        datetime(2024, 6, 15, 10, 30, 0),  # 夏令时
        datetime(2024, 12, 15, 10, 30, 0), # 冬令时
    ]
    
    for utc_time in test_times:
        print(f"\nUTC时间: {utc_time}")
        
        # 转换为英国时间
        uk_time = utc_time.replace(tzinfo=pytz.UTC).astimezone(uk_tz)
        is_dst = uk_time.dst().total_seconds() > 0
        
        print(f"英国时间: {uk_time}")
        print(f"时区: {uk_time.tzname()}")
        print(f"是否夏令时: {is_dst}")
        
        # 验证时间差
        expected_offset = 1 if is_dst else 0
        actual_offset = (uk_time.hour - utc_time.hour) % 24
        if actual_offset == expected_offset:
            print("✅ 时间偏移正确")
        else:
            print(f"❌ 时间偏移错误，期望: {expected_offset}，实际: {actual_offset}")

def main():
    """主测试函数"""
    print("🕐 开始测试英国夏冬令时转换...")
    print("=" * 60)
    
    test_dst_conversion()
    test_dst_boundary()
    test_api_timezone_info()
    test_message_time_consistency_with_dst()
    
    print("\n" + "=" * 60)
    print("✅ DST转换测试完成")

if __name__ == "__main__":
    main()
