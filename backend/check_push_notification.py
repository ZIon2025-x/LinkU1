#!/usr/bin/env python3
"""
推送通知诊断脚本
检查推送通知配置和设备 token 状态
"""
import os
import sys
from pathlib import Path

# 添加项目路径
sys.path.insert(0, str(Path(__file__).parent))

from app.database import SessionLocal
from app import models
from app.push_notification_service import (
    APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID, 
    APNS_KEY_FILE, APNS_KEY_CONTENT, APNS_USE_SANDBOX,
    get_apns_key_file
)

def check_apns_config():
    """检查 APNs 配置"""
    print("=" * 60)
    print("APNs 配置检查")
    print("=" * 60)
    
    print(f"APNS_KEY_ID: {'✓ 已设置' if APNS_KEY_ID else '✗ 未设置'}")
    print(f"APNS_TEAM_ID: {'✓ 已设置' if APNS_TEAM_ID else '✗ 未设置'}")
    print(f"APNS_BUNDLE_ID: {APNS_BUNDLE_ID}")
    print(f"APNS_USE_SANDBOX: {APNS_USE_SANDBOX}")
    print(f"APNS_KEY_FILE: {APNS_KEY_FILE if APNS_KEY_FILE else '未设置'}")
    print(f"APNS_KEY_CONTENT: {'✓ 已设置（Base64）' if APNS_KEY_CONTENT else '✗ 未设置'}")
    
    key_file = get_apns_key_file()
    if key_file:
        print(f"APNs 密钥文件: ✓ {key_file}")
        if os.path.exists(key_file):
            print(f"  文件大小: {os.path.getsize(key_file)} 字节")
        else:
            print(f"  ✗ 文件不存在")
    else:
        print("APNs 密钥文件: ✗ 无法加载")
    
    # 检查 PyAPNs2
    try:
        from apns2 import APNsClient
        print("PyAPNs2: ✓ 已安装")
    except ImportError:
        print("PyAPNs2: ✗ 未安装（需要运行: pip install apns2）")
    
    print()

def check_device_tokens(user_id: str = None):
    """检查设备 token"""
    print("=" * 60)
    print("设备 Token 检查")
    print("=" * 60)
    
    db = SessionLocal()
    try:
        query = db.query(models.DeviceToken)
        
        if user_id:
            query = query.filter(models.DeviceToken.user_id == user_id)
            print(f"用户 ID: {user_id}")
        else:
            print("所有用户")
        
        # 统计
        total = query.count()
        active = query.filter(models.DeviceToken.is_active == True).count()
        ios = query.filter(models.DeviceToken.platform == "ios").count()
        android = query.filter(models.DeviceToken.platform == "android").count()
        
        print(f"总设备数: {total}")
        print(f"激活设备数: {active}")
        print(f"iOS 设备数: {ios}")
        print(f"Android 设备数: {android}")
        print()
        
        if user_id:
            # 显示该用户的所有设备
            tokens = query.all()
            if tokens:
                print("设备列表:")
                for i, token in enumerate(tokens, 1):
                    status = "✓ 激活" if token.is_active else "✗ 未激活"
                    print(f"  {i}. {status} | {token.platform} | {token.device_token[:20]}... | 创建时间: {token.created_at}")
            else:
                print("✗ 该用户没有注册的设备 token")
        else:
            # 显示最近注册的 10 个设备
            recent_tokens = query.order_by(models.DeviceToken.created_at.desc()).limit(10).all()
            if recent_tokens:
                print("最近注册的设备（前 10 个）:")
                for i, token in enumerate(recent_tokens, 1):
                    status = "✓ 激活" if token.is_active else "✗ 未激活"
                    print(f"  {i}. 用户 {token.user_id} | {status} | {token.platform} | {token.device_token[:20]}... | {token.created_at}")
            else:
                print("✗ 没有注册的设备 token")
        
    finally:
        db.close()
    
    print()

def check_user_notifications(user_id: str):
    """检查用户的通知记录"""
    print("=" * 60)
    print(f"用户 {user_id} 的通知记录")
    print("=" * 60)
    
    db = SessionLocal()
    try:
        notifications = db.query(models.Notification).filter(
            models.Notification.user_id == user_id
        ).order_by(models.Notification.created_at.desc()).limit(10).all()
        
        if notifications:
            print(f"最近 10 条通知:")
            for i, notif in enumerate(notifications, 1):
                read_status = "已读" if notif.is_read else "未读"
                print(f"  {i}. [{read_status}] {notif.type} | {notif.title} | {notif.created_at}")
        else:
            print("✗ 该用户没有通知记录")
    finally:
        db.close()
    
    print()

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description="推送通知诊断工具")
    parser.add_argument("--user-id", help="检查特定用户的设备 token")
    args = parser.parse_args()
    
    print("\n推送通知诊断工具\n")
    
    # 检查 APNs 配置
    check_apns_config()
    
    # 检查设备 token
    check_device_tokens(args.user_id)
    
    # 如果指定了用户 ID，检查通知记录
    if args.user_id:
        check_user_notifications(args.user_id)
    
    print("=" * 60)
    print("诊断完成")
    print("=" * 60)
    print("\n如果推送通知不工作，请检查：")
    print("1. APNs 配置是否完整（KEY_ID, TEAM_ID, KEY_CONTENT）")
    print("2. 设备 token 是否已注册到数据库")
    print("3. 设备 token 是否标记为激活（is_active=True）")
    print("4. 后端日志中是否有推送错误信息")
    print("5. iOS 设备是否已授予通知权限")

if __name__ == "__main__":
    main()
