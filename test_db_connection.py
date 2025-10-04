#!/usr/bin/env python3
"""
测试数据库连接
"""

import sys
import os
sys.path.append('backend')

from app.database import SessionLocal
from app.models import User
from sqlalchemy import text

def test_db_connection():
    print("测试数据库连接...")
    
    try:
        db = SessionLocal()
        
        # 测试基本连接
        result = db.execute(text("SELECT 1"))
        print("数据库连接成功")
        
        # 检查users表是否存在
        result = db.execute(text("SELECT table_name FROM information_schema.tables WHERE table_name = 'users'"))
        tables = result.fetchall()
        print(f"找到表: {tables}")
        
        # 检查users表结构
        result = db.execute(text("SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'users'"))
        columns = result.fetchall()
        print("users表结构:")
        for col in columns:
            print(f"  - {col[0]} ({col[1]})")
        
        # 检查现有用户数量
        user_count = db.query(User).count()
        print(f"现有用户数量: {user_count}")
        
        # 测试插入一个简单用户
        test_user = User(
            id="12345678",
            name="test_db_user",
            email="test_db@example.com",
            hashed_password="test_hash",
            phone="1234567890"
        )
        
        db.add(test_user)
        db.commit()
        print("测试用户插入成功")
        
        # 清理测试数据
        db.delete(test_user)
        db.commit()
        print("测试数据清理完成")
        
        db.close()
        print("数据库测试完成")
        
    except Exception as e:
        print(f"数据库测试失败: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_db_connection()
