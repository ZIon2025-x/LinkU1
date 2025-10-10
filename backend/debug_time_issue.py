#!/usr/bin/env python3
"""
时间问题调试脚本
详细分析时间获取和存储的每个步骤
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.models import get_uk_time, get_uk_time_online, get_uk_time_naive
from datetime import datetime
import pytz
import requests

def debug_time_issue():
    """调试时间问题"""
    print("=== 时间问题调试 ===")
    print()
    
    # 1. 检查系统时间
    print("1. 系统时间检查:")
    system_time = datetime.now()
    print(f"   系统本地时间: {system_time}")
    print(f"   系统UTC时间: {datetime.utcnow()}")
    print()
    
    # 2. 检查时区设置
    print("2. 时区设置检查:")
    try:
        uk_tz = pytz.timezone("Europe/London")
        uk_time_local = datetime.now(uk_tz)
        print(f"   英国时区时间: {uk_time_local}")
        print(f"   是否夏令时: {uk_time_local.dst() != datetime.timedelta(0)}")
        print(f"   时区偏移: {uk_time_local.strftime('%z')}")
    except Exception as e:
        print(f"   时区检查失败: {e}")
    print()
    
    # 3. 检查在线时间API
    print("3. 在线时间API检查:")
    apis = [
        'http://worldtimeapi.org/api/timezone/Europe/London',
        'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
        'http://worldclockapi.com/api/json/utc/now'
    ]
    
    for i, api in enumerate(apis, 1):
        try:
            print(f"   API {i}: {api}")
            response = requests.get(api, timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"   响应: {data}")
                
                # 解析时间
                if 'utc_datetime' in data:
                    utc_time = datetime.fromisoformat(data['utc_datetime'].replace('Z', '+00:00'))
                    uk_time = utc_time.astimezone(pytz.timezone("Europe/London"))
                    print(f"   解析的英国时间: {uk_time}")
                elif 'dateTime' in data:
                    uk_time = datetime.fromisoformat(data['dateTime'].replace('Z', '+00:00'))
                    print(f"   解析的英国时间: {uk_time}")
                elif 'currentDateTime' in data:
                    utc_time = datetime.fromisoformat(data['currentDateTime'].replace('Z', '+00:00'))
                    uk_time = utc_time.astimezone(pytz.timezone("Europe/London"))
                    print(f"   解析的英国时间: {uk_time}")
            else:
                print(f"   HTTP错误: {response.status_code}")
        except Exception as e:
            print(f"   请求失败: {e}")
        print()
    
    # 4. 检查我们的函数
    print("4. 我们的时间函数检查:")
    try:
        uk_time = get_uk_time()
        print(f"   get_uk_time(): {uk_time}")
        print(f"   时区: {uk_time.tzinfo}")
        print(f"   是否夏令时: {uk_time.dst() != datetime.timedelta(0)}")
    except Exception as e:
        print(f"   get_uk_time() 失败: {e}")
    
    try:
        uk_time_online = get_uk_time_online()
        print(f"   get_uk_time_online(): {uk_time_online}")
        print(f"   时区: {uk_time_online.tzinfo}")
        print(f"   是否夏令时: {uk_time_online.dst() != datetime.timedelta(0)}")
    except Exception as e:
        print(f"   get_uk_time_online() 失败: {e}")
    
    try:
        uk_time_naive = get_uk_time_naive()
        print(f"   get_uk_time_naive(): {uk_time_naive}")
        print(f"   时区: {uk_time_naive.tzinfo}")
    except Exception as e:
        print(f"   get_uk_time_naive() 失败: {e}")
    print()
    
    # 5. 时间差异分析
    print("5. 时间差异分析:")
    try:
        uk_time = get_uk_time()
        uk_time_naive = get_uk_time_naive()
        
        # 转换为相同格式进行比较
        uk_time_naive_comparison = uk_time.replace(tzinfo=None)
        time_diff = abs((uk_time_naive - uk_time_naive_comparison).total_seconds())
        
        print(f"   本地英国时间: {uk_time}")
        print(f"   数据库存储时间: {uk_time_naive}")
        print(f"   时间差异: {time_diff} 秒")
        
        if time_diff > 3600:  # 超过1小时
            print("   ⚠️  发现超过1小时的时间差异！")
        elif time_diff > 300:  # 超过5分钟
            print("   ⚠️  发现超过5分钟的时间差异")
        else:
            print("   ✅ 时间差异在可接受范围内")
            
    except Exception as e:
        print(f"   时间差异分析失败: {e}")
    print()
    
    # 6. 建议修复方案
    print("6. 建议修复方案:")
    print("   如果发现1小时差异，可能的原因：")
    print("   - 夏令时/冬令时处理错误")
    print("   - 时区转换问题")
    print("   - API返回的时间本身有误")
    print("   - 服务器时区设置问题")
    print()
    print("   建议的修复步骤：")
    print("   1. 检查服务器时区设置")
    print("   2. 验证API返回的时间准确性")
    print("   3. 调整时区转换逻辑")
    print("   4. 使用更可靠的时间源")

def main():
    """主函数"""
    print("开始调试时间问题...")
    print("=" * 60)
    
    try:
        debug_time_issue()
        print("\n✅ 调试完成！")
    except Exception as e:
        print(f"\n❌ 调试失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
