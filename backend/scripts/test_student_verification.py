"""
学生认证系统测试脚本
用于测试API接口功能
"""

import sys
import os
from pathlib import Path

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))

from app.database import SessionLocal
from app import models
from app.student_verification_utils import (
    calculate_expires_at,
    calculate_renewable_from,
    calculate_days_remaining,
    can_renew
)
from app.student_verification_validators import (
    validate_student_email,
    normalize_email,
    extract_domain
)
from datetime import datetime, timezone
from app.utils.time_utils import format_iso_utc

def test_calculate_expires_at():
    """测试过期时间计算函数"""
    print("=" * 60)
    print("测试 calculate_expires_at 函数")
    print("=" * 60)
    
    test_cases = [
        # (验证时间, 期望过期时间, 描述)
        (datetime(2024, 7, 15, tzinfo=timezone.utc), datetime(2024, 10, 1, tzinfo=timezone.utc), "7月验证 → 当年10月1日"),
        (datetime(2024, 8, 1, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "8月1日验证 → 次年10月1日"),
        (datetime(2024, 8, 15, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "8月15日验证 → 次年10月1日"),
        (datetime(2024, 9, 1, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "9月1日验证 → 次年10月1日"),
        (datetime(2024, 9, 30, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "9月30日验证 → 次年10月1日"),
        (datetime(2024, 10, 1, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "10月1日验证 → 次年10月1日"),
        (datetime(2024, 10, 2, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "10月2日验证 → 次年10月1日"),
        (datetime(2024, 11, 15, tzinfo=timezone.utc), datetime(2025, 10, 1, tzinfo=timezone.utc), "11月验证 → 次年10月1日"),
    ]
    
    all_passed = True
    for verified_at, expected, description in test_cases:
        result = calculate_expires_at(verified_at)
        passed = result == expected
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"{status} {description}")
        print(f"  验证时间: {format_iso_utc(verified_at)}")
        print(f"  期望过期: {format_iso_utc(expected)}")
        print(f"  实际过期: {format_iso_utc(result)}")
        if not passed:
            print(f"  ❌ 测试失败！")
        print()
    
    if all_passed:
        print("✅ 所有测试通过！")
    else:
        print("❌ 部分测试失败！")
    
    return all_passed


def test_renewable_from():
    """测试续期开始时间计算"""
    print("=" * 60)
    print("测试 calculate_renewable_from 函数")
    print("=" * 60)
    
    expires_at = datetime(2025, 10, 1, tzinfo=timezone.utc)
    renewable_from = calculate_renewable_from(expires_at)
    expected = datetime(2025, 9, 1, tzinfo=timezone.utc)
    
    passed = renewable_from == expected
    status = "✓" if passed else "✗"
    print(f"{status} 续期开始时间计算")
    print(f"  过期时间: {format_iso_utc(expires_at)}")
    print(f"  期望续期开始: {format_iso_utc(expected)}")
    print(f"  实际续期开始: {format_iso_utc(renewable_from)}")
    if not passed:
        print(f"  ❌ 测试失败！")
    print()
    
    return passed


def test_can_renew():
    """测试是否可以续期"""
    print("=" * 60)
    print("测试 can_renew 函数")
    print("=" * 60)
    
    now = datetime(2025, 9, 15, tzinfo=timezone.utc)
    expires_at = datetime(2025, 10, 1, tzinfo=timezone.utc)
    
    # 距离过期16天，应该可以续期
    result = can_renew(expires_at, now)
    expected = True
    passed = result == expected
    status = "✓" if passed else "✗"
    print(f"{status} 可以续期测试（距离过期16天）")
    print(f"  当前时间: {format_iso_utc(now)}")
    print(f"  过期时间: {format_iso_utc(expires_at)}")
    print(f"  期望结果: {expected}")
    print(f"  实际结果: {result}")
    if not passed:
        print(f"  ❌ 测试失败！")
    print()
    
    # 距离过期35天，不应该可以续期
    now2 = datetime(2025, 8, 27, tzinfo=timezone.utc)
    result2 = can_renew(expires_at, now2)
    expected2 = False
    passed2 = result2 == expected2
    status2 = "✓" if passed2 else "✗"
    print(f"{status2} 不能续期测试（距离过期35天）")
    print(f"  当前时间: {format_iso_utc(now2)}")
    print(f"  过期时间: {format_iso_utc(expires_at)}")
    print(f"  期望结果: {expected2}")
    print(f"  实际结果: {result2}")
    if not passed2:
        print(f"  ❌ 测试失败！")
    print()
    
    return passed and passed2


def test_database_models():
    """测试数据库模型"""
    print("=" * 60)
    print("测试数据库模型")
    print("=" * 60)
    
    db = SessionLocal()
    try:
        # 检查表是否存在
        from sqlalchemy import inspect
        inspector = inspect(db.bind)
        tables = inspector.get_table_names()
        
        required_tables = ['universities', 'student_verifications', 'verification_history']
        all_exist = True
        
        for table in required_tables:
            exists = table in tables
            status = "✓" if exists else "✗"
            print(f"{status} 表 {table}: {'存在' if exists else '不存在'}")
            if not exists:
                all_exist = False
        
        print()
        
        # 检查大学数据
        university_count = db.query(models.University).count()
        print(f"大学数据数量: {university_count}")
        if university_count > 0:
            print("✓ 大学数据已初始化")
        else:
            print("⚠ 大学数据未初始化，请运行 init_universities.py")
        
        return all_exist
        
    except Exception as e:
        print(f"❌ 测试失败: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        db.close()


def test_email_validators():
    """测试邮箱验证器"""
    print("=" * 60)
    print("测试邮箱验证器")
    print("=" * 60)
    
    all_passed = True
    
    # 测试 normalize_email
    print("\n测试 normalize_email:")
    test_cases = [
        ("  Test@Bristol.AC.UK  ", "test@bristol.ac.uk", "去除空格并转小写"),
        ("TEST@BRISTOL.AC.UK", "test@bristol.ac.uk", "转小写"),
        ("test@bristol.ac.uk", "test@bristol.ac.uk", "已标准化"),
    ]
    for input_email, expected, description in test_cases:
        result = normalize_email(input_email)
        passed = result == expected
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"{status} {description}: '{input_email}' -> '{result}'")
        if not passed:
            print(f"  期望: '{expected}'")
    
    # 测试 validate_student_email
    print("\n测试 validate_student_email:")
    valid_emails = [
        ("test@bristol.ac.uk", "有效邮箱"),
        ("student.name@oxford.ac.uk", "带点的邮箱"),
        ("user123@cambridge.ac.uk", "带数字的邮箱"),
    ]
    invalid_emails = [
        ("", "空邮箱"),
        ("test@bristol.com", "非.ac.uk后缀"),
        ("test@bristol", "不完整域名"),
        ("@bristol.ac.uk", "缺少本地部分"),
        ("test@.ac.uk", "缺少域名"),
        ("test..test@bristol.ac.uk", "连续的点"),
        ("test" + "a" * 100 + "@bristol.ac.uk", "本地部分过长"),
    ]
    
    for email, description in valid_emails:
        is_valid, error_message = validate_student_email(email)
        passed = is_valid
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"{status} {description}: '{email}' - {'有效' if is_valid else f'无效: {error_message}'}")
    
    for email, description in invalid_emails:
        is_valid, error_message = validate_student_email(email)
        passed = not is_valid
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"{status} {description}: '{email}' - {'正确拒绝' if not is_valid else '错误接受'}")
        if not passed:
            print(f"  错误信息: {error_message}")
    
    # 测试 extract_domain
    print("\n测试 extract_domain:")
    domain_test_cases = [
        ("test@bristol.ac.uk", "bristol.ac.uk", "提取域名"),
        ("user@ox.ac.uk", "ox.ac.uk", "短域名"),
        ("invalid", None, "无效邮箱"),
    ]
    for email, expected, description in domain_test_cases:
        result = extract_domain(email)
        passed = result == expected
        all_passed = all_passed and passed
        status = "✓" if passed else "✗"
        print(f"{status} {description}: '{email}' -> '{result}'")
        if not passed:
            print(f"  期望: '{expected}'")
    
    print()
    if all_passed:
        print("✅ 所有验证器测试通过！")
    else:
        print("❌ 部分验证器测试失败！")
    
    return all_passed


def main():
    """运行所有测试"""
    print("\n" + "=" * 60)
    print("学生认证系统测试")
    print("=" * 60 + "\n")
    
    results = []
    
    # 测试工具函数
    results.append(("过期时间计算", test_calculate_expires_at()))
    results.append(("续期开始时间计算", test_renewable_from()))
    results.append(("续期判断", test_can_renew()))
    
    # 测试数据库
    results.append(("数据库模型", test_database_models()))
    
    # 测试验证器
    results.append(("邮箱验证器", test_email_validators()))
    
    # 汇总结果
    print("\n" + "=" * 60)
    print("测试结果汇总")
    print("=" * 60)
    
    all_passed = True
    for name, passed in results:
        status = "✓ 通过" if passed else "✗ 失败"
        print(f"{status}: {name}")
        if not passed:
            all_passed = False
    
    print()
    if all_passed:
        print("✅ 所有测试通过！")
        return 0
    else:
        print("❌ 部分测试失败！")
        return 1


if __name__ == "__main__":
    sys.exit(main())

