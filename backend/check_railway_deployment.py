#!/usr/bin/env python3
"""
Railway部署检查脚本
检查在线时间获取功能在Railway环境中的状态
"""

import os
import sys
import requests
import json
from datetime import datetime
import pytz

def check_environment():
    """检查环境变量配置"""
    print("=== 环境变量检查 ===")
    
    env_vars = {
        'ENABLE_ONLINE_TIME': os.getenv('ENABLE_ONLINE_TIME', 'true'),
        'TIME_API_TIMEOUT': os.getenv('TIME_API_TIMEOUT', '3'),
        'TIME_API_MAX_RETRIES': os.getenv('TIME_API_MAX_RETRIES', '3'),
        'FALLBACK_TO_LOCAL_TIME': os.getenv('FALLBACK_TO_LOCAL_TIME', 'true'),
        'CUSTOM_TIME_APIS': os.getenv('CUSTOM_TIME_APIS', ''),
    }
    
    for key, value in env_vars.items():
        print(f"  {key}: {value}")
    
    print()

def check_network_connectivity():
    """检查网络连接"""
    print("=== 网络连接检查 ===")
    
    apis = [
        'http://worldtimeapi.org/api/timezone/Europe/London',
        'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
        'http://worldclockapi.com/api/json/utc/now'
    ]
    
    for api in apis:
        try:
            response = requests.get(api, timeout=5)
            if response.status_code == 200:
                print(f"  ✅ {api} - 连接成功")
            else:
                print(f"  ❌ {api} - HTTP {response.status_code}")
        except Exception as e:
            print(f"  ❌ {api} - 连接失败: {e}")
    
    print()

def test_time_apis():
    """测试时间API"""
    print("=== 时间API测试 ===")
    
    apis = [
        {
            'name': 'WorldTimeAPI',
            'url': 'http://worldtimeapi.org/api/timezone/Europe/London',
            'parser': lambda data: datetime.fromisoformat(data['utc_datetime'].replace('Z', '+00:00'))
        },
        {
            'name': 'TimeAPI',
            'url': 'http://timeapi.io/api/Time/current/zone?timeZone=Europe/London',
            'parser': lambda data: datetime.fromisoformat(data['dateTime'].replace('Z', '+00:00'))
        },
        {
            'name': 'WorldClockAPI',
            'url': 'http://worldclockapi.com/api/json/utc/now',
            'parser': lambda data: datetime.fromisoformat(data['currentDateTime'].replace('Z', '+00:00'))
        }
    ]
    
    for api in apis:
        try:
            print(f"测试 {api['name']}...")
            response = requests.get(api['url'], timeout=3)
            if response.status_code == 200:
                data = response.json()
                utc_time = api['parser'](data)
                uk_tz = pytz.timezone("Europe/London")
                uk_time = utc_time.astimezone(uk_tz)
                print(f"  ✅ 成功: {uk_time}")
            else:
                print(f"  ❌ 失败: HTTP {response.status_code}")
        except Exception as e:
            print(f"  ❌ 错误: {e}")
    
    print()

def test_online_time_function():
    """测试在线时间获取函数"""
    print("=== 在线时间函数测试 ===")
    
    try:
        # 导入时间函数
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from app.models import get_uk_time_online, get_uk_time, get_uk_time_naive
        
        # 测试本地时间
        print("本地英国时间:")
        local_time = get_uk_time()
        print(f"  {local_time}")
        
        # 测试在线时间
        print("在线英国时间:")
        online_time = get_uk_time_online()
        print(f"  {online_time}")
        
        # 测试数据库时间
        print("数据库存储时间:")
        naive_time = get_uk_time_naive()
        print(f"  {naive_time}")
        
        # 比较时间差异
        time_diff = abs((online_time - local_time).total_seconds())
        print(f"时间差异: {time_diff:.2f} 秒")
        
        if time_diff < 10:
            print("  ✅ 时间差异在可接受范围内")
        else:
            print("  ⚠️  时间差异较大，可能需要检查")
            
    except Exception as e:
        print(f"  ❌ 测试失败: {e}")
    
    print()

def check_railway_specific():
    """检查Railway特定配置"""
    print("=== Railway特定检查 ===")
    
    # 检查是否在Railway环境
    if os.getenv('RAILWAY_ENVIRONMENT'):
        print("  ✅ 检测到Railway环境")
        print(f"  环境: {os.getenv('RAILWAY_ENVIRONMENT')}")
        print(f"  项目ID: {os.getenv('RAILWAY_PROJECT_ID', 'N/A')}")
    else:
        print("  ⚠️  未检测到Railway环境")
    
    # 检查端口配置
    port = os.getenv('PORT')
    if port:
        print(f"  ✅ 端口配置: {port}")
    else:
        print("  ⚠️  未设置PORT环境变量")
    
    # 检查时区
    try:
        uk_tz = pytz.timezone("Europe/London")
        current_uk_time = datetime.now(uk_tz)
        print(f"  ✅ 当前英国时间: {current_uk_time}")
        print(f"  ✅ 是否夏令时: {current_uk_time.dst() != datetime.timedelta(0)}")
    except Exception as e:
        print(f"  ❌ 时区检查失败: {e}")
    
    print()

def main():
    """主函数"""
    print("Railway部署检查脚本")
    print("=" * 50)
    print()
    
    check_environment()
    check_network_connectivity()
    test_time_apis()
    test_online_time_function()
    check_railway_specific()
    
    print("检查完成！")
    print()
    print("如果发现问题，请参考 RAILWAY_ENV_VARS.md 进行配置。")

if __name__ == "__main__":
    main()