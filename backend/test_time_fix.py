#!/usr/bin/env python3
"""
测试时间修复效果
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.models import get_uk_time, get_uk_time_naive
from datetime import datetime
import pytz

def test_time_fix():
    """测试时间修复效果"""
    print("=== 时间修复测试 ===")
    print()
    
    # 1. 测试本地英国时间
    print("1. 本地英国时间测试:")
    uk_time = get_uk_time()
    print(f"   get_uk_time(): {uk_time}")
    print(f"   时区: {uk_time.tzinfo}")
    print(f"   是否夏令时: {uk_time.dst() != datetime.timedelta(0)}")
    print()
    
    # 2. 测试数据库存储时间
    print("2. 数据库存储时间测试:")
    uk_time_naive = get_uk_time_naive()
    print(f"   get_uk_time_naive(): {uk_time_naive}")
    print(f"   时区: {uk_time_naive.tzinfo}")
    print()
    
    # 3. 时间对比
    print("3. 时间对比:")
    uk_time_naive_comparison = uk_time.replace(tzinfo=None)
    time_diff = abs((uk_time_naive - uk_time_naive_comparison).total_seconds())
    print(f"   本地英国时间: {uk_time}")
    print(f"   数据库存储时间: {uk_time_naive}")
    print(f"   时间差异: {time_diff} 秒")
    
    if time_diff < 5:
        print("   ✅ 时间修复成功！差异在可接受范围内")
    elif time_diff < 60:
        print("   ⚠️  时间仍有小差异，但可能可以接受")
    else:
        print("   ❌ 时间仍有较大差异，需要进一步调试")
    print()
    
    # 4. 与真实时间对比
    print("4. 与真实时间对比:")
    real_uk_time = datetime.now(pytz.timezone("Europe/London"))
    real_uk_time_naive = real_uk_time.replace(tzinfo=None)
    
    real_diff = abs((uk_time_naive - real_uk_time_naive).total_seconds())
    print(f"   真实英国时间: {real_uk_time}")
    print(f"   我们的时间: {uk_time_naive}")
    print(f"   与真实时间差异: {real_diff} 秒")
    
    if real_diff < 5:
        print("   ✅ 与真实时间一致！")
    else:
        print("   ⚠️  与真实时间有差异，可能需要检查服务器时区设置")
    print()
    
    # 5. 建议
    print("5. 建议:")
    if time_diff < 5 and real_diff < 5:
        print("   ✅ 时间修复成功，可以部署使用")
    else:
        print("   ⚠️  时间仍有问题，建议：")
        print("   1. 检查服务器时区设置")
        print("   2. 验证pytz库的时区数据")
        print("   3. 考虑使用NTP同步服务器时间")

def main():
    """主函数"""
    print("开始测试时间修复效果...")
    print("=" * 50)
    
    try:
        test_time_fix()
        print("\n✅ 测试完成！")
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
