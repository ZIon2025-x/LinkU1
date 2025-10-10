#!/usr/bin/env python3
"""
简化时间修复方案
直接使用本地时间，确保时区正确
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from datetime import datetime
import pytz

def get_correct_uk_time():
    """获取正确的英国时间"""
    # 获取英国时区
    uk_tz = pytz.timezone("Europe/London")
    
    # 获取当前英国时间
    uk_time = datetime.now(uk_tz)
    
    print(f"当前英国时间: {uk_time}")
    print(f"时区: {uk_time.tzinfo}")
    print(f"是否夏令时: {uk_time.dst() != datetime.timedelta(0)}")
    print(f"时区偏移: {uk_time.strftime('%z')}")
    
    return uk_time

def get_correct_uk_time_naive():
    """获取正确的英国时间（用于数据库存储）"""
    uk_time = get_correct_uk_time()
    # 移除时区信息，用于数据库存储
    return uk_time.replace(tzinfo=None)

def test_time_accuracy():
    """测试时间准确性"""
    print("=== 时间准确性测试 ===")
    
    # 获取各种时间
    local_time = datetime.now()
    utc_time = datetime.utcnow()
    uk_time = get_correct_uk_time()
    uk_time_naive = get_correct_uk_time_naive()
    
    print(f"系统本地时间: {local_time}")
    print(f"系统UTC时间: {utc_time}")
    print(f"英国时间（带时区）: {uk_time}")
    print(f"英国时间（数据库用）: {uk_time_naive}")
    
    # 计算时间差异
    uk_utc_diff = (uk_time.replace(tzinfo=None) - utc_time).total_seconds()
    print(f"英国时间与UTC差异: {uk_utc_diff} 秒")
    
    if abs(uk_utc_diff - 3600) < 300:  # 差异接近1小时（夏令时）
        print("✅ 时间正确：当前是英国夏令时（UTC+1）")
    elif abs(uk_utc_diff) < 300:  # 差异接近0（冬令时）
        print("✅ 时间正确：当前是英国冬令时（UTC+0）")
    else:
        print(f"⚠️  时间可能有问题，差异: {uk_utc_diff} 秒")

def main():
    """主函数"""
    print("简化时间修复方案测试")
    print("=" * 50)
    
    try:
        test_time_accuracy()
        print("\n✅ 测试完成！")
    except Exception as e:
        print(f"\n❌ 测试失败: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
