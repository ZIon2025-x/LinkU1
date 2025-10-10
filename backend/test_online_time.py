#!/usr/bin/env python3
"""
测试在线英国时间获取功能
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.models import get_uk_time, get_uk_time_online, get_uk_time_naive
from datetime import datetime
import pytz

def test_time_functions():
    print("=== 英国时间获取测试 ===\n")
    
    # 测试本地时间
    print("1. 本地英国时间:")
    local_time = get_uk_time()
    print(f"   时间: {local_time}")
    print(f"   时区: {local_time.tzinfo}")
    print(f"   是否夏令时: {local_time.dst() != datetime.timedelta(0)}")
    print()
    
    # 测试在线时间
    print("2. 在线英国时间:")
    online_time = get_uk_time_online()
    print(f"   时间: {online_time}")
    print(f"   时区: {online_time.tzinfo}")
    print(f"   是否夏令时: {online_time.dst() != datetime.timedelta(0)}")
    print()
    
    # 测试数据库存储时间
    print("3. 数据库存储时间 (naive):")
    naive_time = get_uk_time_naive()
    print(f"   时间: {naive_time}")
    print(f"   时区: {naive_time.tzinfo}")
    print()
    
    # 比较时间差异
    print("4. 时间差异分析:")
    time_diff = abs((online_time - local_time).total_seconds())
    print(f"   本地时间与在线时间差异: {time_diff:.2f} 秒")
    
    if time_diff < 5:
        print("   ✅ 时间差异在可接受范围内 (< 5秒)")
    else:
        print("   ⚠️  时间差异较大，可能需要检查")
    
    print()
    
    # 显示当前UTC时间作为参考
    print("5. 参考时间:")
    utc_now = datetime.now(pytz.UTC)
    print(f"   UTC时间: {utc_now}")
    print(f"   英国时间 (UTC+0/+1): {utc_now.astimezone(pytz.timezone('Europe/London'))}")

if __name__ == "__main__":
    test_time_functions()
