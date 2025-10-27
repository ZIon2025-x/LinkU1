#!/usr/bin/env python3
"""
测试crud.create_user函数
"""

import sys
import os
sys.path.append('backend')

from app.database import SessionLocal
from app.crud import create_user
from app.schemas import UserCreate

def test_create_user():
    print("测试create_user函数...")
    
    try:
        db = SessionLocal()
        
        # 创建测试用户数据
        user_data = UserCreate(
            name="testuser999",
            email="testuser999@example.com",
            password="Password123",
            phone="1234567890"
        )
        
        print(f"用户数据: {user_data}")
        
        # 调用create_user函数
        new_user = create_user(db, user_data)
        
        print(f"创建成功: {new_user}")
        print(f"用户ID: {new_user.id}")
        print(f"用户名: {new_user.name}")
        print(f"邮箱: {new_user.email}")
        
        # 清理测试数据
        db.delete(new_user)
        db.commit()
        print("测试数据清理完成")
        
        db.close()
        print("测试完成")
        
    except Exception as e:
        print(f"测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_create_user()
