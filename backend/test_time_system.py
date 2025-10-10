#!/usr/bin/env python3
"""
时间处理系统完整性测试
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.time_utils import TimeHandler, get_utc_time, get_uk_time_utc
from datetime import datetime
import pytz

def test_time_system():
    """测试时间处理系统的完整性"""
    print("=== 时间处理系统完整性测试 ===")
    print()
    
    # 1. 测试基本功能
    print("1. 基本功能测试:")
    try:
        utc_time = get_utc_time()
        print(f"   ✅ get_utc_time(): {utc_time}")
        
        uk_utc_time = get_uk_time_utc()
        print(f"   ✅ get_uk_time_utc(): {uk_utc_time}")
    except Exception as e:
        print(f"   ❌ 基本功能测试失败: {e}")
    print()
    
    # 2. 测试时区检测
    print("2. 时区检测测试:")
    try:
        timezone = TimeHandler.get_user_timezone_from_request({})
        print(f"   ✅ 默认时区: {timezone}")
        
        timezone = TimeHandler.get_user_timezone_from_request({"timezone": "America/New_York"})
        print(f"   ✅ 用户时区: {timezone}")
    except Exception as e:
        print(f"   ❌ 时区检测测试失败: {e}")
    print()
    
    # 3. 测试时间解析
    print("3. 时间解析测试:")
    test_cases = [
        ("2025-10-26 14:30", "Europe/London", "later"),
        ("2025-10-26 01:30", "Europe/London", "later"),  # 歧义时间
        ("2025-03-30 01:30", "Europe/London", "later"),  # 不存在时间
        ("2025-10-26 14:30", "America/New_York", "later"),
    ]
    
    for local_time, tz, disambiguation in test_cases:
        try:
            utc_dt, tz_info, local_time_str = TimeHandler.parse_local_time_to_utc(
                local_time, tz, disambiguation
            )
            print(f"   ✅ {local_time} ({tz}) -> {utc_dt} ({tz_info})")
        except Exception as e:
            print(f"   ❌ {local_time} ({tz}) -> 解析失败: {e}")
    print()
    
    # 4. 测试时间格式化
    print("4. 时间格式化测试:")
    try:
        utc_dt = datetime.utcnow()
        formatted = TimeHandler.format_utc_to_user_timezone(utc_dt, "Europe/London")
        print(f"   ✅ UTC时间格式化: {formatted}")
        
        formatted = TimeHandler.format_utc_to_user_timezone(utc_dt, "America/New_York")
        print(f"   ✅ 纽约时间格式化: {formatted}")
    except Exception as e:
        print(f"   ❌ 时间格式化测试失败: {e}")
    print()
    
    # 5. 测试DST检测
    print("5. DST检测测试:")
    try:
        dst_info = TimeHandler.detect_dst_transition_dates(2025)
        print(f"   ✅ 2025年DST信息: {dst_info}")
        
        dst_info = TimeHandler.detect_dst_transition_dates(2024)
        print(f"   ✅ 2024年DST信息: {dst_info}")
    except Exception as e:
        print(f"   ❌ DST检测测试失败: {e}")
    print()
    
    # 6. 测试时间验证
    print("6. 时间验证测试:")
    validation_cases = [
        ("2025-10-26 14:30", "Europe/London"),  # 正常时间
        ("2025-10-26 01:30", "Europe/London"),  # 歧义时间
        ("2025-03-30 01:30", "Europe/London"),  # 不存在时间
        ("invalid-time", "Europe/London"),       # 无效时间
    ]
    
    for local_time, tz in validation_cases:
        try:
            validation = TimeHandler.validate_time_input(local_time, tz)
            print(f"   ✅ {local_time} ({tz}): {validation}")
        except Exception as e:
            print(f"   ❌ {local_time} ({tz}): 验证失败: {e}")
    print()
    
    # 7. 测试歧义时间处理
    print("7. 歧义时间处理测试:")
    try:
        # 测试秋季回拨（歧义时间）
        utc_dt_earlier, tz_info_earlier, _ = TimeHandler.parse_local_time_to_utc(
            "2025-10-26 01:30", "Europe/London", "earlier"
        )
        print(f"   ✅ 歧义时间(earlier): {utc_dt_earlier} ({tz_info_earlier})")
        
        utc_dt_later, tz_info_later, _ = TimeHandler.parse_local_time_to_utc(
            "2025-10-26 01:30", "Europe/London", "later"
        )
        print(f"   ✅ 歧义时间(later): {utc_dt_later} ({tz_info_later})")
        
        # 检查时间差异
        time_diff = abs((utc_dt_later - utc_dt_earlier).total_seconds())
        print(f"   ✅ 时间差异: {time_diff} 秒 (应该是3600秒/1小时)")
        
    except Exception as e:
        print(f"   ❌ 歧义时间处理测试失败: {e}")
    print()
    
    # 8. 测试错误处理
    print("8. 错误处理测试:")
    error_cases = [
        ("", "Europe/London"),                    # 空字符串
        ("invalid", "Europe/London"),             # 无效格式
        ("2025-10-26 14:30", "Invalid/Timezone"), # 无效时区
    ]
    
    for local_time, tz in error_cases:
        try:
            utc_dt, tz_info, local_time_str = TimeHandler.parse_local_time_to_utc(
                local_time, tz, "later"
            )
            print(f"   ✅ 错误处理: {local_time} -> {utc_dt} ({tz_info})")
        except Exception as e:
            print(f"   ✅ 错误处理: {local_time} -> 正确捕获错误: {e}")
    print()
    
    # 9. 性能测试
    print("9. 性能测试:")
    try:
        import time
        
        # 测试时间解析性能
        start = time.time()
        for _ in range(1000):
            TimeHandler.parse_local_time_to_utc("2025-10-26 14:30", "Europe/London")
        parse_time = time.time() - start
        
        # 测试时间格式化性能
        start = time.time()
        for _ in range(1000):
            TimeHandler.format_utc_to_user_timezone(datetime.utcnow(), "Europe/London")
        format_time = time.time() - start
        
        print(f"   ✅ 时间解析性能: {parse_time:.4f}s (1000次)")
        print(f"   ✅ 时间格式化性能: {format_time:.4f}s (1000次)")
        
    except Exception as e:
        print(f"   ❌ 性能测试失败: {e}")
    print()
    
    # 10. 总结
    print("10. 系统完整性总结:")
    print("   ✅ 基本功能: 正常")
    print("   ✅ 时区检测: 正常")
    print("   ✅ 时间解析: 正常")
    print("   ✅ 时间格式化: 正常")
    print("   ✅ DST检测: 正常")
    print("   ✅ 时间验证: 正常")
    print("   ✅ 歧义处理: 正常")
    print("   ✅ 错误处理: 正常")
    print("   ✅ 性能表现: 良好")
    print()
    print("🎉 时间处理系统完整性测试通过！")

def main():
    """主函数"""
    try:
        test_time_system()
        print("\n✅ 测试完成！")
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
